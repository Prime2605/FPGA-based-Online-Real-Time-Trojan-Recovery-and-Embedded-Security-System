// ============================================================
// File     : trojan_block.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Simulated Hardware Trojan - hidden attack module
// Improved : timescale, dual trigger, multiple payloads,
//            activation counter, stealth mode
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module trojan_block (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  a,
    input  wire [7:0]  alu_result,
    output reg  [7:0]  final_result,
    output reg         trojan_active,
    output reg  [7:0]  activation_count  // NEW - tracks firings
);

    // ── Trigger conditions ───────────────────────────────────
    // Primary   : all switches ON  = 11111111
    // Secondary : alternating bits = 10101010
    localparam TRIGGER_PRIMARY   = 8'hFF;
    localparam TRIGGER_SECONDARY = 8'hAA;

    // ── Internal state ───────────────────────────────────────
    reg [1:0] payload_select;  // rotates through payload types
    reg       stealth_toggle;  // fires only on alternate triggers

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            final_result     <= 8'b0;
            trojan_active    <= 1'b0;
            activation_count <= 8'b0;
            payload_select   <= 2'b0;
            stealth_toggle   <= 1'b0;
        end
        else begin

            // Default - pass through clean
            trojan_active <= 1'b0;
            final_result  <= alu_result;

            // ── Primary trigger check ────────────────────────
            if (a == TRIGGER_PRIMARY) begin
                stealth_toggle <= ~stealth_toggle;

                // Stealth - only fire on every other trigger
                if (stealth_toggle) begin
                    trojan_active <= 1'b1;

                    // Rotate through payload types
                    payload_select <= payload_select + 1'b1;

                    // Payload selection
                    case (payload_select)
                        2'b00: begin
                            // Payload 1 - flip bit 0 (subtle)
                            final_result <= alu_result ^ 8'b00000001;
                        end
                        2'b01: begin
                            // Payload 2 - flip bit 7 (MSB flip)
                            final_result <= alu_result ^ 8'b10000000;
                        end
                        2'b10: begin
                            // Payload 3 - zero output (disruptive)
                            final_result <= 8'b00000000;
                        end
                        2'b11: begin
                            // Payload 4 - invert all bits
                            final_result <= ~alu_result;
                        end
                    endcase

                    // Count activations
                    if (activation_count < 8'd255)
                        activation_count <= activation_count + 1'b1;
                end
            end

            // ── Secondary trigger check ──────────────────────
            else if (a == TRIGGER_SECONDARY) begin
                trojan_active <= 1'b1;
                // Secondary payload - subtle bit 3 flip
                final_result  <= alu_result ^ 8'b00001000;

                if (activation_count < 8'd255)
                    activation_count <= activation_count + 1'b1;
            end

        end
    end

endmodule