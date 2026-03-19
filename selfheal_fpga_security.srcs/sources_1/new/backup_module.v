// ============================================================
// File     : backup_module.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Verified safe backup circuit - Layer 3 recovery
// Improved : timescale, SIM_MODE, self-test on activation,
//            integrity counter, threat level input
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module backup_module #(
    parameter SIM_MODE = 0  // 1 = fast warmup for simulation
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        activate,       // FSM triggers switchover
    input  wire [1:0]  threat_level,   // NEW - from AI detector
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [1:0]  op,
    output reg  [7:0]  backup_result,
    output reg         backup_active,
    output reg         system_safe,
    output reg         self_test_pass, // NEW - internal test ok
    output reg  [7:0]  op_count        // NEW - operations done
);

    // ── Warmup cycles ────────────────────────────────────────
    // Real hardware: 8 cycles
    // Simulation   : 4 cycles for visible but fast transition
    localparam WARMUP_MAX = (SIM_MODE) ? 4'd4 : 4'd8;

    // ── Self-test vectors ─────────────────────────────────────
    // Two known computations verified on activation
    // Test 1: ADD  0x05 + 0x03 = 0x08
    // Test 2: AND  0xFF & 0x0F = 0x0F
    localparam TEST1_A   = 8'h05;
    localparam TEST1_B   = 8'h03;
    localparam TEST1_OP  = 2'b00;   // ADD
    localparam TEST1_EXP = 8'h08;   // expected 8

    localparam TEST2_A   = 8'hFF;
    localparam TEST2_B   = 8'h0F;
    localparam TEST2_OP  = 2'b10;   // AND
    localparam TEST2_EXP = 8'h0F;   // expected 15

    // ── Internal state ───────────────────────────────────────
    reg        enabled;
    reg [3:0]  warmup_counter;
    reg        warmed_up;
    reg [2:0]  self_test_state;
    reg        self_test_done;
    reg [7:0]  test_result;
    reg        pre_armed;  // pre-warm on threat level 2

    // ── Self-test FSM states ──────────────────────────────────
    localparam ST_IDLE    = 3'd0;
    localparam ST_TEST1   = 3'd1;
    localparam ST_CHECK1  = 3'd2;
    localparam ST_TEST2   = 3'd3;
    localparam ST_CHECK2  = 3'd4;
    localparam ST_PASS    = 3'd5;
    localparam ST_FAIL    = 3'd6;

    // ── ALU function (internal to backup) ────────────────────
    // Completely isolated from primary ALU and Trojan path
    function [7:0] alu_op;
        input [7:0] fa, fb;
        input [1:0] fop;
        begin
            case (fop)
                2'b00: alu_op = fa + fb;
                2'b01: alu_op = fa - fb;
                2'b10: alu_op = fa & fb;
                2'b11: alu_op = fa | fb;
                default: alu_op = 8'b0;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enabled         <= 1'b0;
            backup_active   <= 1'b0;
            system_safe     <= 1'b0;
            self_test_pass  <= 1'b0;
            self_test_done  <= 1'b0;
            self_test_state <= ST_IDLE;
            warmup_counter  <= 4'b0;
            warmed_up       <= 1'b0;
            backup_result   <= 8'b0;
            op_count        <= 8'b0;
            pre_armed       <= 1'b0;
            test_result     <= 8'b0;
        end
        else begin

            // ── Pre-arm on threat level 2 ─────────────────────
            // Start warming up before full activation
            // Reduces recovery time when Trojan confirmed
            if (threat_level >= 2'b10 && !enabled)
                pre_armed <= 1'b1;

            // ── Full activation on threat level 3 ────────────
            if (activate || threat_level == 2'b11) begin
                enabled       <= 1'b1;
                backup_active <= 1'b1;
            end

            // ── Self-test sequence ────────────────────────────
            // Runs immediately on activation before output used
            if ((enabled || pre_armed) && !self_test_done) begin

                case (self_test_state)

                    ST_IDLE: begin
                        self_test_state <= ST_TEST1;
                    end

                    ST_TEST1: begin
                        // Compute Test 1: 5 + 3
                        test_result     <= alu_op(TEST1_A,
                                                  TEST1_B,
                                                  TEST1_OP);
                        self_test_state <= ST_CHECK1;
                    end

                    ST_CHECK1: begin
                        if (test_result == TEST1_EXP)
                            self_test_state <= ST_TEST2;
                        else
                            self_test_state <= ST_FAIL;
                    end

                    ST_TEST2: begin
                        // Compute Test 2: 0xFF & 0x0F
                        test_result     <= alu_op(TEST2_A,
                                                  TEST2_B,
                                                  TEST2_OP);
                        self_test_state <= ST_CHECK2;
                    end

                    ST_CHECK2: begin
                        if (test_result == TEST2_EXP)
                            self_test_state <= ST_PASS;
                        else
                            self_test_state <= ST_FAIL;
                    end

                    ST_PASS: begin
                        self_test_pass  <= 1'b1;
                        self_test_done  <= 1'b1;
                    end

                    ST_FAIL: begin
                        // Self-test failed - backup not safe
                        self_test_pass  <= 1'b0;
                        self_test_done  <= 1'b1;
                        backup_active   <= 1'b0;
                        system_safe     <= 1'b0;
                    end

                    default: self_test_state <= ST_IDLE;

                endcase
            end

            // ── Warmup after self-test passes ─────────────────
            if (enabled && self_test_done
                        && self_test_pass && !warmed_up) begin
                warmup_counter <= warmup_counter + 1'b1;

                if (warmup_counter >= WARMUP_MAX - 1) begin
                    warmed_up   <= 1'b1;
                    system_safe <= 1'b1;
                end
            end

            // ── Normal backup computation ─────────────────────
            // Only runs after self-test passes
            // Completely isolated from Trojan signal path
            if (enabled && self_test_pass) begin
                backup_result <= alu_op(a, b, op);

                // Count operations performed
                if (op_count < 8'd255)
                    op_count <= op_count + 1'b1;
            end

        end
    end

endmodule