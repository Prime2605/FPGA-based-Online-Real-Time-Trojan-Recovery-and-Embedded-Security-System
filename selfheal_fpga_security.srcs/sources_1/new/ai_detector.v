// ============================================================
// File     : ai_detector.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : AI decision tree classifier - Trojan detection
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module ai_detector (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  mismatch_count,
    input  wire [7:0]  switch_activity,
    input  wire [7:0]  overflow_events,
    input  wire [7:0]  anomaly_score,
    input  wire [7:0]  peak_score,
    input  wire        anomaly_flag,
    output reg         trojan_detected,
    output reg         normal_op,
    output reg  [2:0]  confidence,
    output reg  [1:0]  threat_level
);

    localparam SCORE_CRITICAL  = 8'd20;
    localparam SCORE_HIGH      = 8'd14;
    localparam SCORE_MED       = 8'd8;
    localparam SCORE_LOW       = 8'd4;
    localparam MISMATCH_HIGH   = 8'd3;
    localparam MISMATCH_MED    = 8'd1;
    localparam ACTIVITY_HIGH   = 8'd10;
    localparam ACTIVITY_MED    = 8'd5;
    localparam OVERFLOW_HIGH   = 8'd2;

    reg        trojan_latch;
    reg [6:0]  clean_counter;
    reg [2:0]  fast_confidence;
    reg [2:0]  deep_confidence;
    reg [5:0]  deep_timer;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            trojan_detected <= 1'b0;
            normal_op       <= 1'b1;
            confidence      <= 3'd0;
            threat_level    <= 2'b00;
            trojan_latch    <= 1'b0;
            clean_counter   <= 7'b0;
            fast_confidence <= 3'd0;
            deep_confidence <= 3'd0;
            deep_timer      <= 6'b0;
        end
        else begin

            if (trojan_latch) begin
                trojan_detected <= 1'b1;
                normal_op       <= 1'b0;
                threat_level    <= 2'b11;
                confidence      <= 3'd7;
            end
            else begin

                // ── Fast detection pass ───────────────────────
                if (anomaly_score >= SCORE_CRITICAL ||
                    peak_score    >= SCORE_CRITICAL) begin
                    fast_confidence <= 3'd7;
                    trojan_latch    <= 1'b1;
                    threat_level    <= 2'b11;
                end
                else if ((anomaly_score >= SCORE_HIGH ||
                          peak_score    >= SCORE_HIGH) &&
                          mismatch_count >= MISMATCH_MED) begin
                    fast_confidence <= 3'd6;
                    trojan_latch    <= 1'b1;
                    threat_level    <= 2'b11;
                end
                else if (mismatch_count >= MISMATCH_HIGH) begin
                    fast_confidence <= 3'd6;
                    trojan_latch    <= 1'b1;
                    threat_level    <= 2'b11;
                end
                else if (overflow_events >= OVERFLOW_HIGH &&
                         anomaly_score   >= SCORE_MED) begin
                    fast_confidence <= 3'd5;
                    trojan_latch    <= 1'b1;
                    threat_level    <= 2'b10;
                end
                else if (anomaly_score   >= SCORE_MED &&
                         switch_activity >= ACTIVITY_HIGH) begin
                    fast_confidence <= 3'd4;
                    trojan_latch    <= 1'b1;
                    threat_level    <= 2'b10;
                end
                else if (anomaly_flag &&
                         switch_activity >= ACTIVITY_MED) begin
                    fast_confidence <= 3'd2;
                    threat_level    <= 2'b01;
                end
                else begin
                    fast_confidence <= 3'd0;
                    if (clean_counter < 7'd127)
                        clean_counter <= clean_counter + 1'b1;
                    if (clean_counter >= 7'd64) begin
                        threat_level <= 2'b00;
                        if (confidence > 3'd0)
                            confidence <= confidence - 1'b1;
                    end
                end

                // ── Deep verification pass (every 32 cycles) ──
                deep_timer <= deep_timer + 1'b1;
                if (deep_timer == 6'd31) begin
                    if (mismatch_count  >= MISMATCH_MED  &&
                        overflow_events >= 8'd1          &&
                        switch_activity >= ACTIVITY_MED) begin
                        deep_confidence <= 3'd6;
                        trojan_latch    <= 1'b1;
                        threat_level    <= 2'b11;
                    end
                    else if (anomaly_flag              &&
                             anomaly_score >= SCORE_LOW &&
                             mismatch_count >= MISMATCH_MED) begin
                        deep_confidence <= 3'd5;
                        trojan_latch    <= 1'b1;
                        threat_level    <= 2'b11;
                    end
                    else if (peak_score >= SCORE_HIGH) begin
                        deep_confidence <= 3'd5;
                        trojan_latch    <= 1'b1;
                        threat_level    <= 2'b11;
                    end
                    else begin
                        deep_confidence <= 3'd0;
                        clean_counter   <= 7'b0;
                    end
                end

                // Merge confidence
                if (!trojan_latch) begin
                    confidence <= (fast_confidence > deep_confidence)
                                ? fast_confidence : deep_confidence;
                    trojan_detected <= 1'b0;
                    normal_op       <= (threat_level == 2'b00)
                                     ? 1'b1 : 1'b0;
                end

            end
        end
    end

endmodule