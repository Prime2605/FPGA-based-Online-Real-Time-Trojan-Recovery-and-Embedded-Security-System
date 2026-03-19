## ============================================================
## constraints.xdc
## Project  : Self-Healing Trusted FPGA Architecture
## Board    : Digilent Arty S7-25 / S7-50 (Spartan-7)
## Vivado   : 2025.2
## ============================================================

## ============================================================
## SECTION 1 - CLOCK
## ============================================================

## 100MHz onboard oscillator
set_property PACKAGE_PIN F14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## ============================================================
## SECTION 2 - BUTTONS
## ============================================================

## BTN0 - System Reset
set_property PACKAGE_PIN G15 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## BTN1 - Manual Trojan Trigger (demo button)
set_property PACKAGE_PIN K16 [get_ports btn_trigger]
set_property IOSTANDARD LVCMOS33 [get_ports btn_trigger]

## BTN2 - Reserved for future use
## set_property PACKAGE_PIN J16 [get_ports btn2]
## set_property IOSTANDARD LVCMOS33 [get_ports btn2]

## BTN3 - Reserved for future use
## set_property PACKAGE_PIN H13 [get_ports btn3]
## set_property IOSTANDARD LVCMOS33 [get_ports btn3]

## ============================================================
## SECTION 3 - SLIDE SWITCHES
## ============================================================

## SW0 - Operand A bit 0
set_property PACKAGE_PIN H14 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]

## SW1 - Operand A bit 1
set_property PACKAGE_PIN H18 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]

## SW2 - Operation select bit 0 (op[0])
set_property PACKAGE_PIN G18 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]

## SW3 - Operation select bit 1 (op[1])
set_property PACKAGE_PIN M5 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

## ============================================================
## SECTION 4 - STATUS LEDs (LD0-LD3)
## ============================================================

## LD0 - GREEN - PUF authentication passed / Normal operation
set_property PACKAGE_PIN E18 [get_ports led_green]
set_property IOSTANDARD LVCMOS33 [get_ports led_green]

## LD1 - RED - Trojan detected / Authentication failed
set_property PACKAGE_PIN F13 [get_ports led_red]
set_property IOSTANDARD LVCMOS33 [get_ports led_red]

## LD2 - BLUE - Self-healing active
set_property PACKAGE_PIN E13 [get_ports led_blue]
set_property IOSTANDARD LVCMOS33 [get_ports led_blue]

## LD3 - WHITE - System fully recovered and safe
set_property PACKAGE_PIN H15 [get_ports led_white]
set_property IOSTANDARD LVCMOS33 [get_ports led_white]

## ============================================================
## SECTION 5 - RGB LED 0 (Result Display)
## Shows lower 4 bits of ALU or backup output
## ============================================================

## RGB0 Red   - led_result bit 0
set_property PACKAGE_PIN J15 [get_ports {led_result[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_result[0]}]

## RGB0 Green - led_result bit 1
set_property PACKAGE_PIN G17 [get_ports {led_result[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_result[1]}]

## RGB0 Blue  - led_result bit 2
set_property PACKAGE_PIN F15 [get_ports {led_result[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_result[2]}]

## ============================================================
## SECTION 6 - RGB LED 1 (Alert and Fault Display)
## ============================================================

## RGB1 Red   - led_result bit 3
set_property PACKAGE_PIN E15 [get_ports {led_result[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_result[3]}]

## RGB1 Green - led_yellow - Suspicious state warning
set_property PACKAGE_PIN F18 [get_ports led_yellow]
set_property IOSTANDARD LVCMOS33 [get_ports led_yellow]

## RGB1 Blue  - led_fault - Backup self-test failed
set_property PACKAGE_PIN E17 [get_ports led_fault]
set_property IOSTANDARD LVCMOS33 [get_ports led_fault]

## ============================================================
## SECTION 7 - PMOD JA (Watchdog and Debug)
## ============================================================

## JA[0] - led_watchdog - Healing timeout alert
set_property PACKAGE_PIN L17 [get_ports led_watchdog]
set_property IOSTANDARD LVCMOS33 [get_ports led_watchdog]

## JA[1] - Reserved debug pin
## set_property PACKAGE_PIN L18 [get_ports debug_1]
## set_property IOSTANDARD LVCMOS33 [get_ports debug_1]

## JA[2] - Reserved debug pin
## set_property PACKAGE_PIN M14 [get_ports debug_2]
## set_property IOSTANDARD LVCMOS33 [get_ports debug_2]

## JA[3] - Reserved debug pin
## set_property PACKAGE_PIN N14 [get_ports debug_3]
## set_property IOSTANDARD LVCMOS33 [get_ports debug_3]

## ============================================================
## SECTION 8 - TIMING CONSTRAINTS
## ============================================================

## Input delay - switches and buttons are human-operated
## No timing requirement needed on these paths
set_false_path -from [get_ports rst]
set_false_path -from [get_ports btn_trigger]
set_false_path -from [get_ports {sw[*]}]

## Output delay - LEDs have no timing requirement
set_false_path -to [get_ports led_green]
set_false_path -to [get_ports led_red]
set_false_path -to [get_ports led_blue]
set_false_path -to [get_ports led_white]
set_false_path -to [get_ports led_yellow]
set_false_path -to [get_ports led_fault]
set_false_path -to [get_ports led_watchdog]
set_false_path -to [get_ports {led_result[*]}]

## ============================================================
## SECTION 9 - CONFIGURATION
## ============================================================

## Required for Spartan-7 - prevents critical DRC warnings
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Bitstream compression - reduces programming time
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## ============================================================
## COMPLETE PIN REFERENCE TABLE
## ============================================================
##
##  Signal          Pin    Board Label    Function
##  ─────────────────────────────────────────────────────────
##  clk             F14    CLK100MHZ      100MHz system clock
##  rst             G15    BTN0           System reset
##  btn_trigger     K16    BTN1           Manual Trojan trigger
##  sw[0]           H14    SW0            Operand A bit 0
##  sw[1]           H18    SW1            Operand A bit 1
##  sw[2]           G18    SW2            Op select bit 0
##  sw[3]           M5     SW3            Op select bit 1
##  led_green       E18    LD0            Auth pass / Normal
##  led_red         F13    LD1            Trojan detected
##  led_blue        E13    LD2            Self-healing active
##  led_white       H15    LD3            System recovered
##  led_result[0]   J15    RGB0_R         Result bit 0
##  led_result[1]   G17    RGB0_G         Result bit 1
##  led_result[2]   F15    RGB0_B         Result bit 2
##  led_result[3]   E15    RGB1_R         Result bit 3
##  led_yellow      F18    RGB1_G         Suspicious warning
##  led_fault       E17    RGB1_B         Backup test failed
##  led_watchdog    L17    JA[0]          Healing timeout
##
## ============================================================