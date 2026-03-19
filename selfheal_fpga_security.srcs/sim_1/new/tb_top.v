// ============================================================
// File     : tb_top.v
// Project  : Self-Healing Trusted FPGA Architecture
// Purpose  : Full system testbench - all 6 steps complete
// Fixed    : All ports matched, SIM_MODE=1, no state refs
// Board    : Arty S7 (Spartan-7)
// ============================================================
`timescale 1ns / 1ps

module tb_top;

    // ── Inputs ───────────────────────────────────────────────
    reg        clk;
    reg        rst;
    reg        btn_trigger;
    reg  [3:0] sw;

    // ── Outputs ──────────────────────────────────────────────
    wire       led_green;
    wire       led_red;
    wire       led_blue;
    wire       led_white;
    wire       led_yellow;
    wire [3:0] led_result;
    wire       led_fault;
    wire       led_watchdog;

    // ── Instantiate top ──────────────────────────────────────
    top #(
        .SIM_MODE (1)
    ) uut (
        .clk          (clk),
        .rst          (rst),
        .btn_trigger  (btn_trigger),
        .sw           (sw),
        .led_green    (led_green),
        .led_red      (led_red),
        .led_blue     (led_blue),
        .led_white    (led_white),
        .led_yellow   (led_yellow),
        .led_result   (led_result),
        .led_fault    (led_fault),
        .led_watchdog (led_watchdog)
    );

    // ── Clock - 10ns period = 100MHz ─────────────────────────
    initial clk = 0;
    always  #5 clk = ~clk;

    // ── Separator task ────────────────────────────────────────
    task separator;
        begin
            $display("--------------------------------------------");
        end
    endtask

    // ── Print status task ─────────────────────────────────────
    task print_status;
        input [255:0] label;
        begin
            separator();
            $display(" %s", label);
            $display(" Time         : %0t ns", $time);
            $display(" led_green    : %b", led_green);
            $display(" led_yellow   : %b", led_yellow);
            $display(" led_red      : %b", led_red);
            $display(" led_blue     : %b", led_blue);
            $display(" led_white    : %b", led_white);
            $display(" led_fault    : %b", led_fault);
            $display(" led_watchdog : %b", led_watchdog);
            $display(" led_result   : %04b = %0d",
                      led_result, led_result);
            separator();
        end
    endtask

    // ── Wait N cycles task ────────────────────────────────────
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // ── Check task - prints PASS or FAIL ─────────────────────
    task check;
        input [255:0] signal_name;
        input         actual;
        input         expected;
        begin
            if (actual === expected)
                $display(" [PASS] %s = %b", signal_name, actual);
            else
                $display(" [FAIL] %s = %b (expected %b)",
                          signal_name, actual, expected);
        end
    endtask

    // ── Main simulation ───────────────────────────────────────
    initial begin

        rst         = 1;
        btn_trigger = 0;
        sw          = 4'b0000;

        $display(" ");
        $display("============================================");
        $display("  Self-Healing Trusted FPGA Architecture  ");
        $display("  Behavioural Simulation - 6 Steps        ");
        $display("  SIM_MODE = 1 (fast boot and PUF)        ");
        $display("============================================");
        $display(" ");

        // Hold reset 20 cycles
        wait_cycles(20);
        rst = 0;
        $display("[INFO] Reset released at %0t ns", $time);

        // =====================================================
        // STEP 1 - BOOT + PUF AUTHENTICATION
        // Boot delay = 100 cycles (SIM_MODE=1)
        // PUF samples = 8 cycles  (SIM_MODE=1)
        // FSM: BOOT → AUTHENTICATING → NORMAL
        // Expected: led_green = 1 after ~200 cycles
        // =====================================================
        $display(" ");
        $display(">>> STEP 1 - Boot and PUF Authentication");
        $display("[INFO] Waiting 300 cycles for boot + auth");
        wait_cycles(300);
        print_status("STEP 1 - AUTHENTICATION RESULT");
        check("led_green", led_green, 1'b1);
        check("led_red  ", led_red,   1'b0);

        // =====================================================
        // STEP 2 - NORMAL OPERATION
        // sw=0001 → operand_a = 0000_0100 = 4
        // operand_b = 1 (fixed)
        // op = SW3:SW2 = 00 = ADD
        // Expected: result = 5 = 0101
        // FSM stays in NORMAL - led_green solid
        // =====================================================
        $display(" ");
        $display(">>> STEP 2 - Normal Circuit Operation");
        $display("[INFO] A=4, B=1, op=ADD, expect result=5");
        sw = 4'b0001;
        wait_cycles(60);
        print_status("STEP 2 - NORMAL OPERATION");
        check("led_green ", led_green,      1'b1);
        check("led_red   ", led_red,        1'b0);
        check("result[2] ", led_result[2],  1'b1);
        check("result[0] ", led_result[0],  1'b1);

        // =====================================================
        // STEP 3 - TROJAN ACTIVATION
        // btn_trigger=1 → operand_a forced to 0xFF
        // trojan_block detects 0xFF → fires payload
        // Bit 0 of result flipped silently
        // feature_extractor captures mismatch
        // =====================================================
        $display(" ");
        $display(">>> STEP 3 - Trojan Trigger Activated");
        $display("[INFO] BTN1 pressed - forcing A=0xFF");
        btn_trigger = 1;
        wait_cycles(20);
        print_status("STEP 3 - TROJAN FIRED");
        $display("[INFO] Output bit 0 is now corrupted");
        $display("[INFO] Feature extractor capturing anomaly");

        // =====================================================
        // STEP 4 - AI DETECTION
        // anomaly_score builds up over feature window
        // ai_detector classifies as TROJAN
        // threat_level rises to 2 or 3
        // FSM enters SUSPICIOUS then TROJAN_FOUND
        // Expected: led_red = 1
        // =====================================================
        $display(" ");
        $display(">>> STEP 4 - AI Classifier Running");
        $display("[INFO] Waiting for anomaly score to build");
        wait_cycles(150);
        print_status("STEP 4 - AI DETECTION RESULT");
        check("led_red   ", led_red,   1'b1);
        check("led_green ", led_green, 1'b0);

        // =====================================================
        // STEP 5 - SECURITY CONTROLLER RESPONSE
        // FSM: TROJAN_FOUND → HEALING
        // activate_backup fires
        // backup_module starts self-test
        // use_backup switches output path
        // Expected: led_red=1, led_blue=1
        // =====================================================
        $display(" ");
        $display(">>> STEP 5 - Security Controller Response");
        btn_trigger = 0;
        wait_cycles(30);
        print_status("STEP 5 - HEALING STATE");
        check("led_red  ", led_red,  1'b1);
        check("led_blue ", led_blue, 1'b1);

        // =====================================================
        // STEP 6 - SELF-HEALING RECOVERY
        // backup_module passes self-test (2 vectors)
        // warmup counter completes (4 cycles in SIM_MODE)
        // system_safe = 1, self_test_pass = 1
        // FSM: HEALING → SAFE
        // Expected: led_blue=1, led_white=1, led_red=0
        // =====================================================
        $display(" ");
        $display(">>> STEP 6 - Self-Healing Recovery");
        wait_cycles(100);
        print_status("STEP 6 - RECOVERY RESULT");
        check("led_blue  ", led_blue,  1'b1);
        check("led_white ", led_white, 1'b1);
        check("led_red   ", led_red,   1'b0);
        check("led_fault ", led_fault, 1'b0);

        // =====================================================
        // FINAL VERIFICATION
        // Backup module now serving output
        // sw=0001 → A=4, B=1, op=ADD
        // Backup result should be clean = 5 = 0101
        // =====================================================
        $display(" ");
        $display(">>> FINAL - Backup Output Verification");
        sw = 4'b0001;
        wait_cycles(20);
        print_status("FINAL - BACKUP OUTPUT");
        check("led_white  ", led_white,     1'b1);
        check("led_blue   ", led_blue,      1'b1);
        check("result[2]  ", led_result[2], 1'b1);
        check("result[0]  ", led_result[0], 1'b1);

        // =====================================================
        // RESET VERIFICATION
        // Full hardware reset
        // System reboots cleanly from BOOT state
        // =====================================================
        $display(" ");
        $display(">>> RESET - Full System Reset Test");
        rst = 1;
        wait_cycles(20);
        rst = 0;
        wait_cycles(30);
        print_status("AFTER RESET - BOOT STATE");
        check("led_green ", led_green, 1'b0);
        check("led_red   ", led_red,   1'b0);
        check("led_blue  ", led_blue,  1'b0);
        check("led_white ", led_white, 1'b0);

        wait_cycles(50);

        $display(" ");
        $display("============================================");
        $display("  SIMULATION COMPLETE                      ");
        $display("  Review PASS/FAIL above for each step     ");
        $display("  Open waveform for full signal detail     ");
        $display("============================================");
        $display(" ");

        $finish;
    end

    // ── Waveform dump ─────────────────────────────────────────
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

    // ── Watchdog ──────────────────────────────────────────────
    initial begin
        #2_000_000;
        $display("[WATCHDOG] Timeout - FSM may be stuck");
        $finish;
    end

endmodule