// ============================================================
// File     : alu_8bit.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Normal 8-bit ALU - protected functional core
// Improved : timescale, overflow flag, hardened default case
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module alu_8bit (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [1:0]  op,
    output reg  [7:0]  result,
    output reg         valid,
    output reg         overflow  // NEW - detects result wraparound
);

    // Operation codes
    // 00 = ADD  01 = SUB  10 = AND  11 = OR
    reg [8:0] temp; // 9-bit to catch overflow

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result   <= 8'b0;
            valid    <= 1'b0;
            overflow <= 1'b0;
            temp     <= 9'b0;
        end
        else begin
            overflow <= 1'b0; // default clear each cycle
            valid    <= 1'b1;

            case (op)
                2'b00: begin
                    // ADD - detect overflow
                    temp     <= {1'b0, a} + {1'b0, b};
                    result   <= temp[7:0];
                    overflow <= temp[8]; // bit 8 = overflow
                end
                2'b01: begin
                    // SUB - detect underflow
                    temp     <= {1'b0, a} - {1'b0, b};
                    result   <= temp[7:0];
                    overflow <= temp[8]; // bit 8 = borrow
                end
                2'b10: begin
                    // AND - no overflow possible
                    result   <= a & b;
                    overflow <= 1'b0;
                end
                2'b11: begin
                    // OR - no overflow possible
                    result   <= a | b;
                    overflow <= 1'b0;
                end
                default: begin
                    result   <= 8'b0;
                    valid    <= 1'b0;
                    overflow <= 1'b0;
                end
            endcase
        end
    end

endmodule