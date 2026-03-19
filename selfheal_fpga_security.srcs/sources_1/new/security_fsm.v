// ============================================================
// File     : security_fsm.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Master security controller - all state management
// Fixed    : SIM_MODE parameter, blink wires, all ports clean
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module security_fsm #(
    parameter SIM_MODE = 0
)(
    input  wire        clk,
    input  wire        rst,

    // PUF interface
    input  wire        auth_done,
    input  wire        auth_pass,
    input  wire [2:0]  fail_count,

    // AI detector interface
    input  wire        trojan_detected,
    input  wire [1:0]  threat_level,

    // Backup module interface
    input  wire        system_safe,
    input  wire        self_test_pass,

    // Outputs to modules
    output reg         puf_start,
    output reg  [1:0]  puf_challenge,
    output reg         activate_backup,

    // LED outputs
    output reg         led_green,
    output reg         led_red,
    output reg         led_blue,
    output reg         led_white,
    output reg         led_yellow,

    // System control
    output reg         use_backup,
    output reg  [2:0]  sys_state,
    output reg         critical_fault,
    output reg         watchdog_alert
);

    // ── Boot delay ───────────────────────────────────────────
    // SIM_MODE=1 → 100 cycles, real → 50 million cycles
    localparam BOOT_DELAY = (SIM_MODE) ? 26'd100
                                       : 26'd50_000_000;

    // ── FSM State Encoding ───────────────────────────────────
    localparam BOOT           = 3'd0;
    localparam AUTHENTICATING = 3'd1;
    localparam AUTH_FAILED    = 3'd2;
    localparam NORMAL         = 3'd3;
    localparam SUSPICIOUS     = 3'd4;
    localparam TROJAN_FOUND   = 3'd5;
    localparam HEALING        = 3'd6;
    localparam SAFE           = 3'd7;

    // ── Internal registers ───────────────────────────────────
    reg [2:0]  state;
    reg [2:0]  next_state;
    reg [25:0] boot_counter;
    reg        boot_done;
    reg [7:0]  healing_timeout;
    reg [1:0]  challenge_reg;

    // ── Blink signals from boot counter ──────────────────────
    wire blink_slow = boot_counter[22]; // ~2Hz
    wire blink_med  = boot_counter[21]; // ~4Hz
    wire blink_fast = boot_counter[20]; // ~8Hz

    // ── State register ───────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= BOOT;
            boot_counter    <= 26'b0;
            boot_done       <= 1'b0;
            healing_timeout <= 8'b0;
            challenge_reg   <= 2'b0;
        end
        else begin
            state <= next_state;

            if (!boot_done) begin
                boot_counter <= boot_counter + 1'b1;
                if (boot_counter >= BOOT_DELAY)
                    boot_done <= 1'b1;
            end

            if (state == BOOT && boot_done)
                challenge_reg <= challenge_reg + 1'b1;

            if (state == HEALING) begin
                if (healing_timeout < 8'd255)
                    healing_timeout <= healing_timeout + 1'b1;
            end
            else begin
                healing_timeout <= 8'b0;
            end
        end
    end

    // ── Next state logic ─────────────────────────────────────
    always @(*) begin
        next_state = state;

        case (state)

            BOOT: begin
                if (boot_done)
                    next_state = AUTHENTICATING;
            end

            AUTHENTICATING: begin
                if (auth_done && auth_pass)
                    next_state = NORMAL;
                else if (auth_done && !auth_pass)
                    next_state = AUTH_FAILED;
            end

            AUTH_FAILED: begin
                next_state = AUTH_FAILED;
            end

            NORMAL: begin
                if (trojan_detected || threat_level == 2'b11)
                    next_state = TROJAN_FOUND;
                else if (threat_level == 2'b10 ||
                         threat_level == 2'b01)
                    next_state = SUSPICIOUS;
            end

            SUSPICIOUS: begin
                if (trojan_detected || threat_level == 2'b11)
                    next_state = TROJAN_FOUND;
                else if (threat_level == 2'b00)
                    next_state = NORMAL;
            end

            TROJAN_FOUND: begin
                next_state = HEALING;
            end

            HEALING: begin
                if (system_safe && self_test_pass)
                    next_state = SAFE;
            end

            SAFE: begin
                next_state = SAFE;
            end

            default: next_state = BOOT;

        endcase
    end

    // ── Output logic ─────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            puf_start       <= 1'b0;
            puf_challenge   <= 2'b0;
            activate_backup <= 1'b0;
            led_green       <= 1'b0;
            led_red         <= 1'b0;
            led_blue        <= 1'b0;
            led_white       <= 1'b0;
            led_yellow      <= 1'b0;
            use_backup      <= 1'b0;
            sys_state       <= 3'b0;
            critical_fault  <= 1'b0;
            watchdog_alert  <= 1'b0;
        end
        else begin
            sys_state     <= state;
            puf_challenge <= challenge_reg;

            // Default all LEDs off each cycle
            led_green  <= 1'b0;
            led_red    <= 1'b0;
            led_blue   <= 1'b0;
            led_white  <= 1'b0;
            led_yellow <= 1'b0;

            case (state)

                BOOT: begin
                    puf_start       <= 1'b0;
                    activate_backup <= 1'b0;
                    use_backup      <= 1'b0;
                    critical_fault  <= 1'b0;
                    watchdog_alert  <= 1'b0;
                end

                AUTHENTICATING: begin
                    puf_start <= 1'b1;
                    led_green <= blink_slow;
                end

                AUTH_FAILED: begin
                    puf_start  <= 1'b0;
                    led_red    <= blink_fast;
                    use_backup <= 1'b0;
                end

                NORMAL: begin
                    puf_start  <= 1'b0;
                    led_green  <= 1'b1;
                    use_backup <= 1'b0;
                end

                SUSPICIOUS: begin
                    led_yellow      <= 1'b1;
                    led_green       <= blink_med;
                    activate_backup <= 1'b1;
                    use_backup      <= 1'b0;
                end

                TROJAN_FOUND: begin
                    led_red         <= 1'b1;
                    activate_backup <= 1'b1;
                    use_backup      <= 1'b1;
                end

                HEALING: begin
                    led_red    <= 1'b1;
                    led_blue   <= blink_med;
                    use_backup <= 1'b1;

                    if (healing_timeout >= 8'd200) begin
                        watchdog_alert <= 1'b1;
                        led_red        <= blink_fast;
                    end

                    if (system_safe && !self_test_pass) begin
                        critical_fault <= 1'b1;
                        led_red        <= 1'b1;
                        led_blue       <= 1'b0;
                    end
                end

                SAFE: begin
                    led_blue       <= 1'b1;
                    led_white      <= 1'b1;
                    use_backup     <= 1'b1;
                    watchdog_alert <= 1'b0;
                end

            endcase
        end
    end

endmodule