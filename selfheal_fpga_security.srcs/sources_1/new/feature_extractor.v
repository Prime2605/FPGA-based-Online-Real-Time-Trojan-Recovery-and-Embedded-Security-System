// ============================================================
// File     : feature_extractor.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Monitors circuit signals - extracts AI features
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module feature_extractor (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  expected_result,
    input  wire [7:0]  actual_result,
    input  wire [7:0]  operand_a,
    input  wire        trojan_active,
    input  wire        overflow,
    input  wire [7:0]  activation_count,
    output reg  [7:0]  mismatch_count,
    output reg  [7:0]  switch_activity,
    output reg  [7:0]  overflow_events,
    output reg  [7:0]  anomaly_score,
    output reg  [7:0]  peak_score,
    output reg         anomaly_flag
);

    reg [7:0]  prev_result;
    reg        prev_overflow;
    reg [7:0]  mismatch_acc;
    reg [7:0]  activity_acc;
    reg [7:0]  overflow_acc;
    reg [5:0]  window_counter;
    reg [7:0]  raw_score;

    localparam ANOMALY_THRESHOLD = 8'd12;
    localparam W_MISMATCH        = 4;
    localparam W_OVERFLOW        = 3;
    localparam W_SWITCH          = 1;
    localparam W_TROJAN          = 8;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_result     <= 8'b0;
            prev_overflow   <= 1'b0;
            mismatch_acc    <= 8'b0;
            activity_acc    <= 8'b0;
            overflow_acc    <= 8'b0;
            window_counter  <= 6'b0;
            mismatch_count  <= 8'b0;
            switch_activity <= 8'b0;
            overflow_events <= 8'b0;
            anomaly_score   <= 8'b0;
            peak_score      <= 8'b0;
            anomaly_flag    <= 1'b0;
            raw_score       <= 8'b0;
        end
        else begin

            // Feature 1 - output mismatch
            if (expected_result != actual_result) begin
                if (mismatch_acc < 8'd255)
                    mismatch_acc <= mismatch_acc + 1'b1;
            end

            // Feature 2 - switching activity
            if (actual_result != prev_result) begin
                if (activity_acc < 8'd255)
                    activity_acc <= activity_acc + 1'b1;
            end

            // Feature 3 - unexpected overflow
            if (overflow && !prev_overflow) begin
                if (overflow_acc < 8'd255)
                    overflow_acc <= overflow_acc + 1'b1;
            end

            // 32-cycle rolling window
            window_counter <= window_counter + 1'b1;
            if (window_counter == 6'd31) begin
                mismatch_count  <= mismatch_acc;
                switch_activity <= activity_acc;
                overflow_events <= overflow_acc;
                mismatch_acc    <= 8'b0;
                activity_acc    <= 8'b0;
                overflow_acc    <= 8'b0;
            end

            // Weighted anomaly score
            raw_score <= (mismatch_count  * W_MISMATCH)
                       + (overflow_events * W_OVERFLOW)
                       + (switch_activity * W_SWITCH)
                       + (trojan_active   ? W_TROJAN : 0)
                       + (activation_count > 0 ? 4 : 0);

            anomaly_score <= (raw_score > 8'd255)
                           ? 8'd255 : raw_score;

            // Peak score - never resets
            if (anomaly_score > peak_score)
                peak_score <= anomaly_score;

            // Anomaly flag
            if (anomaly_score   >= ANOMALY_THRESHOLD ||
                peak_score      >= ANOMALY_THRESHOLD ||
                mismatch_count  >= 8'd2              ||
                activation_count > 8'd0)
                anomaly_flag <= 1'b1;
            else
                anomaly_flag <= 1'b0;

            prev_result   <= actual_result;
            prev_overflow <= overflow;

        end
    end

endmodule