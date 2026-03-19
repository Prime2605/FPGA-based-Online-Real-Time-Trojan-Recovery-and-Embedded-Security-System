// ============================================================
// File     : clk_divider.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Divides 100MHz clock to 1Hz for LED demo
// Improved : Added timescale, simulation parameter
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module clk_divider #(
    parameter SIM_MODE = 0  // set to 1 in testbench for fast sim
)(
    input  wire clk_100mhz,
    input  wire rst,
    output reg  clk_1hz
);

    // Real hardware: 50,000,000 cycles = 1Hz
    // Simulation:    50 cycles = instant visible transitions
    localparam MAX_COUNT = (SIM_MODE) ? 26'd50 : 26'd50_000_000;

    reg [25:0] counter;

    always @(posedge clk_100mhz or posedge rst) begin
        if (rst) begin
            counter <= 26'd0;
            clk_1hz <= 1'b0;
        end
        else begin
            if (counter >= MAX_COUNT - 1) begin
                counter <= 26'd0;
                clk_1hz <= ~clk_1hz;
            end
            else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule