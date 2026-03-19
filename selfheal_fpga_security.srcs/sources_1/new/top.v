// ============================================================
// File     : top.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Top-level wrapper - connects all modules
// Fixed    : All ports correct, threat_level wired properly
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module top #(
    parameter SIM_MODE = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        btn_trigger,
    input  wire [3:0]  sw,
    output wire        led_green,
    output wire        led_red,
    output wire        led_blue,
    output wire        led_white,
    output wire        led_yellow,
    output wire [3:0]  led_result,
    output wire        led_fault,
    output wire        led_watchdog
);

    // ── Slow clock ───────────────────────────────────────────
    wire clk_1hz;
    clk_divider #(
        .SIM_MODE (SIM_MODE)
    ) u_clk_div (
        .clk_100mhz (clk),
        .rst        (rst),
        .clk_1hz    (clk_1hz)
    );

    // ── Operand and opcode ───────────────────────────────────
    wire [7:0] operand_a;
    wire [7:0] operand_b;
    wire [1:0] op;

    assign operand_a = btn_trigger ? 8'hFF
                                   : {4'b0000, sw[1:0], 2'b00};
    assign operand_b = 8'h01;
    assign op        = sw[3:2];

    // ── ALU ──────────────────────────────────────────────────
    wire [7:0] alu_result;
    wire       alu_valid;
    wire       alu_overflow;

    alu_8bit u_alu (
        .clk      (clk),
        .rst      (rst),
        .a        (operand_a),
        .b        (operand_b),
        .op       (op),
        .result   (alu_result),
        .valid    (alu_valid),
        .overflow (alu_overflow)
    );

    // ── Trojan block ─────────────────────────────────────────
    wire [7:0] trojan_result;
    wire       trojan_active;
    wire [7:0] activation_count;

    trojan_block u_trojan (
        .clk              (clk),
        .rst              (rst),
        .a                (operand_a),
        .alu_result       (alu_result),
        .final_result     (trojan_result),
        .trojan_active    (trojan_active),
        .activation_count (activation_count)
    );

    // ── PUF ──────────────────────────────────────────────────
    wire [7:0] puf_response;
    wire       auth_pass;
    wire       auth_done;
    wire       puf_start;
    wire [1:0] puf_challenge;
    wire [2:0] puf_fail_count;

    puf_module #(
        .SIM_MODE (SIM_MODE)
    ) u_puf (
        .clk          (clk),
        .rst          (rst),
        .start        (puf_start),
        .challenge    (puf_challenge),
        .puf_response (puf_response),
        .auth_pass    (auth_pass),
        .auth_done    (auth_done),
        .fail_count   (puf_fail_count)
    );

    // ── Feature extractor ────────────────────────────────────
    wire [7:0] mismatch_count;
    wire [7:0] switch_activity;
    wire [7:0] overflow_events;
    wire [7:0] anomaly_score;
    wire [7:0] peak_score;
    wire       anomaly_flag;

    feature_extractor u_extractor (
        .clk              (clk),
        .rst              (rst),
        .expected_result  (alu_result),
        .actual_result    (trojan_result),
        .operand_a        (operand_a),
        .trojan_active    (trojan_active),
        .overflow         (alu_overflow),
        .activation_count (activation_count),
        .mismatch_count   (mismatch_count),
        .switch_activity  (switch_activity),
        .overflow_events  (overflow_events),
        .anomaly_score    (anomaly_score),
        .peak_score       (peak_score),
        .anomaly_flag     (anomaly_flag)
    );

    // ── AI detector ──────────────────────────────────────────
    wire       trojan_detected;
    wire       normal_op;
    wire [2:0] confidence;
    wire [1:0] threat_level;

    ai_detector u_ai (
        .clk             (clk),
        .rst             (rst),
        .mismatch_count  (mismatch_count),
        .switch_activity (switch_activity),
        .overflow_events (overflow_events),
        .anomaly_score   (anomaly_score),
        .peak_score      (peak_score),
        .anomaly_flag    (anomaly_flag),
        .trojan_detected (trojan_detected),
        .normal_op       (normal_op),
        .confidence      (confidence),
        .threat_level    (threat_level)
    );

    // ── Backup module ─────────────────────────────────────────
    wire [7:0] backup_result;
    wire       backup_active;
    wire       system_safe;
    wire       activate_backup;
    wire       self_test_pass;
    wire [7:0] op_count;

    backup_module #(
        .SIM_MODE (SIM_MODE)
    ) u_backup (
        .clk            (clk),
        .rst            (rst),
        .activate       (activate_backup),
        .threat_level   (threat_level),
        .a              (operand_a),
        .b              (operand_b),
        .op             (op),
        .backup_result  (backup_result),
        .backup_active  (backup_active),
        .system_safe    (system_safe),
        .self_test_pass (self_test_pass),
        .op_count       (op_count)
    );

    // ── Security FSM ─────────────────────────────────────────
    wire       use_backup;
    wire [2:0] sys_state;
    wire       fsm_led_green;
    wire       fsm_led_red;
    wire       fsm_led_blue;
    wire       fsm_led_white;
    wire       fsm_led_yellow;
    wire       critical_fault;
    wire       watchdog_alert;

    security_fsm #(
        .SIM_MODE (SIM_MODE)
    ) u_fsm (
        .clk             (clk),
        .rst             (rst),
        .auth_done       (auth_done),
        .auth_pass       (auth_pass),
        .fail_count      (puf_fail_count),
        .trojan_detected (trojan_detected),
        .threat_level    (threat_level),
        .system_safe     (system_safe),
        .self_test_pass  (self_test_pass),
        .puf_start       (puf_start),
        .puf_challenge   (puf_challenge),
        .activate_backup (activate_backup),
        .led_green       (fsm_led_green),
        .led_red         (fsm_led_red),
        .led_blue        (fsm_led_blue),
        .led_white       (fsm_led_white),
        .led_yellow      (fsm_led_yellow),
        .use_backup      (use_backup),
        .sys_state       (sys_state),
        .critical_fault  (critical_fault),
        .watchdog_alert  (watchdog_alert)
    );

    // ── Output mux ───────────────────────────────────────────
    wire [7:0] final_output;
    assign final_output = use_backup ? backup_result
                                     : trojan_result;

    // ── LED assignments ──────────────────────────────────────
    assign led_green    = fsm_led_green;
    assign led_red      = fsm_led_red;
    assign led_blue     = fsm_led_blue;
    assign led_white    = fsm_led_white;
    assign led_yellow   = fsm_led_yellow;
    assign led_result   = final_output[3:0];
    assign led_fault    = critical_fault;
    assign led_watchdog = watchdog_alert;

endmodule