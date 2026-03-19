// ============================================================
// File     : puf_module.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Ring Oscillator PUF - hardware identity & auth
// Improved : timescale, SIM_MODE, challenge-response table,
//            Hamming distance tolerance, failure counter
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module puf_module #(
    parameter SIM_MODE = 0  // set 1 in testbench for fast auth
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [1:0]  challenge,    // NEW - which CRP to check
    output reg  [7:0]  puf_response,
    output reg         auth_pass,
    output reg         auth_done,
    output reg  [2:0]  fail_count    // NEW - consecutive failures
);

    // ── Simulation vs hardware sample count ─────────────────
    localparam SAMPLE_COUNT = (SIM_MODE) ? 8'd8 : 8'd64;

    // ── Challenge Response Pairs (CRP table) ─────────────────
    // Four challenges with pre-enrolled expected responses
    // In real deployment these are burned in at manufacture
    // Responses derived from FPGA routing delay fingerprint
    reg [7:0] crp_table [0:3];

    // ── Internal registers ───────────────────────────────────
    reg [3:0]  state;
    reg [7:0]  sample_counter;
    reg [25:0] delay_counter;
    reg [7:0]  ro_sample;
    reg [7:0]  expected_response;
    reg [2:0]  hamming_dist;    // bit difference count

    // ── FSM states ───────────────────────────────────────────
    localparam IDLE      = 4'd0;
    localparam LOAD_CRP  = 4'd1;
    localparam SAMPLE    = 4'd2;
    localparam COMPARE   = 4'd3;
    localparam AUTH_OK   = 4'd4;
    localparam AUTH_FAIL = 4'd5;
    localparam LOCKED    = 4'd6;

    // ── Simulated ring oscillator output ─────────────────────
    wire ro_bit;
    assign ro_bit = delay_counter[2] ^ delay_counter[5]
                  ^ delay_counter[9] ^ delay_counter[14];

    // ── Hamming distance function ─────────────────────────────
    // Counts number of bits that differ between two bytes
    function [2:0] hamming;
        input [7:0] a, b;
        reg   [7:0] diff;
        integer     i;
        begin
            diff = a ^ b;
            hamming = 3'd0;
            for (i = 0; i < 8; i = i + 1)
                hamming = hamming + diff[i];
        end
    endfunction

    // ── Main FSM ─────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            puf_response   <= 8'b0;
            auth_pass      <= 1'b0;
            auth_done      <= 1'b0;
            fail_count     <= 3'b0;
            sample_counter <= 8'b0;
            delay_counter  <= 26'b0;
            ro_sample      <= 8'b0;
            hamming_dist   <= 3'b0;

            // Pre-load CRP table
            // These represent enrolled fingerprints
            // from this specific Arty S7 board
            crp_table[0]   <= 8'b10110101;
            crp_table[1]   <= 8'b01101001;
            crp_table[2]   <= 8'b11010010;
            crp_table[3]   <= 8'b00111100;
        end
        else begin
            delay_counter <= delay_counter + 1'b1;

            case (state)

                IDLE: begin
                    auth_pass <= 1'b0;
                    auth_done <= 1'b0;
                    if (start)
                        state <= LOAD_CRP;
                end

                LOAD_CRP: begin
                    // Load expected response for given challenge
                    expected_response <= crp_table[challenge];
                    sample_counter    <= 8'b0;
                    state             <= SAMPLE;
                end

                SAMPLE: begin
                    // Build fingerprint from delay counter bits
                    // Each bit comes from different timing path
                    ro_sample <= {
                        delay_counter[1]  ^ ro_bit,
                        delay_counter[4]  ^ ro_bit,
                        delay_counter[7]  ^ ro_bit,
                        delay_counter[10] ^ ro_bit,
                        delay_counter[13] ^ ro_bit,
                        delay_counter[16] ^ ro_bit,
                        delay_counter[19] ^ ro_bit,
                        delay_counter[22] ^ ro_bit
                    };

                    sample_counter <= sample_counter + 1'b1;

                    if (sample_counter >= SAMPLE_COUNT - 1)
                        state <= COMPARE;
                end

                COMPARE: begin
                    puf_response <= ro_sample;
                    // Calculate Hamming distance
                    hamming_dist <= hamming(ro_sample,
                                           expected_response);

                    // Allow up to 2 bits difference
                    // Tolerates PUF noise from temp/voltage
                    if (hamming(ro_sample,
                                expected_response) <= 3'd2)
                        state <= AUTH_OK;
                    else
                        state <= AUTH_FAIL;
                end

                AUTH_OK: begin
                    auth_pass  <= 1'b1;
                    auth_done  <= 1'b1;
                    fail_count <= 3'b0;  // reset failure count
                    state      <= IDLE;
                end

                AUTH_FAIL: begin
                    auth_pass <= 1'b0;
                    auth_done <= 1'b1;

                    // Lock after 3 consecutive failures
                    if (fail_count >= 3'd2)
                        state <= LOCKED;
                    else begin
                        fail_count <= fail_count + 1'b1;
                        state      <= IDLE;
                    end
                end

                LOCKED: begin
                    // Permanent lock - hardware reset required
                    auth_pass <= 1'b0;
                    auth_done <= 1'b1;
                    state     <= LOCKED;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule