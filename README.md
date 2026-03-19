# SENTINEL-X
### Self-Healing Trusted FPGA Architecture with PUF Authentication 
### and AI-Based Hardware Trojan Detection

![Vivado](https://img.shields.io/badge/Vivado-2025.2-blue)
![FPGA](https://img.shields.io/badge/FPGA-Spartan--7-orange)
![Language](https://img.shields.io/badge/HDL-Verilog-green)
![Status](https://img.shields.io/badge/Status-Simulation%20Complete-brightgreen)
![College](https://www.gcee.ac.in/)

---

## Overview

SENTINEL-X is a multi-layer hardware security framework 
implemented on an FPGA that addresses one of the most critical 
unsolved problems in semiconductor security — Hardware Trojans.

Unlike conventional systems that only detect threats, SENTINEL-X 
authenticates the hardware before operation begins, detects 
malicious activity in real time using AI, and autonomously 
recovers without human intervention — all on a single FPGA chip.

---

## The Problem

Modern integrated circuits are designed and manufactured across 
global supply chains involving multiple third-party vendors and 
foundries. This creates a critical window for adversaries to 
insert Hardware Trojans — malicious circuits that:

- Remain completely hidden during standard testing
- Activate only under specific trigger conditions
- Leak sensitive data, corrupt outputs, or disable systems
- Cannot be fixed by any software patch

---

## The Solution — Three Security Layers
```
Layer 1 — PUF Authentication
  Generates a unique hardware fingerprint from manufacturing
  variations. Verifies device identity on every boot using
  challenge-response pairs with Hamming distance tolerance.

Layer 2 — AI-Based Trojan Detection  
  Feature extraction monitors output mismatches, switching
  activity, and overflow anomalies every clock cycle.
  A two-stage decision tree classifier detects Trojans
  with confidence levels 0–7.

Layer 3 — Self-Healing Recovery
  On Trojan confirmation, an FSM controller isolates the
  compromised module and switches to a verified backup ALU.
  Backup runs self-test before declaring system safe.
```

---

## System Architecture
```
switches / buttons
        │
        ▼
   operand_a ──────────────────────────────┐
        │                                  │
        ▼                                  ▼
   alu_8bit ──→ trojan_block          backup_module
        │            │                     │
        │       trojan_result              │
        │            │                     │
        ▼            ▼                     │
   feature_extractor                       │
        │                                  │
        ▼                                  │
   ai_detector                             │
        │                                  │
        ▼                                  │
   security_fsm ────────────────────────── ┘
        │
        ▼
   output mux → led_result[3:0]
```

---

## Six-Step Demo Flow

| Step | Action | Expected |
|------|---------|----------|
| 1 | Power on | PUF authenticates — green LED blinks then solid |
| 2 | Normal switches | ALU computes correctly — green LED solid |
| 3 | Press BTN1 | Trojan fires — output bit flipped silently |
| 4 | Wait | AI detects anomaly — red LED fires |
| 5 | Automatic | FSM isolates module — red and blue LED |
| 6 | Automatic | Backup takes over — blue and white LED |

---

## Project Structure
```
selfheal_fpga_security/
│
├── sources_1/
│   ├── top.v                 ← Master wrapper
│   ├── clk_divider.v         ← 100MHz to 1Hz clock
│   ├── alu_8bit.v            ← Normal functional circuit
│   ├── trojan_block.v        ← Simulated Hardware Trojan
│   ├── puf_module.v          ← PUF authentication
│   ├── feature_extractor.v   ← Signal monitoring
│   ├── ai_detector.v         ← Decision tree classifier
│   ├── backup_module.v       ← Self-healing recovery
│   └── security_fsm.v        ← Master FSM controller
│
├── constrs_1/
│   └── constraints.xdc       ← Arty S7 pin mapping
│
└── sim_1/
    └── tb_top.v              ← Full system testbench
```

---

## Hardware Requirements

| Component | Specification |
|-----------|--------------|
| FPGA Board | Digilent Arty S7-25 or S7-50 |
| FPGA Chip | Xilinx Spartan-7 xc7s25csga324-1 |
| EDA Tool | Xilinx Vivado 2025.2 |
| HDL | Verilog-2001 / SystemVerilog |
| Clock | 100 MHz onboard oscillator |
| Inputs | 4x DIP switches + 2x push buttons |
| Outputs | 4x LEDs + 2x RGB LEDs + PMOD |

---

## Board Pin Mapping

| Signal | Pin | Label | Function |
|--------|-----|-------|----------|
| clk | F14 | CLK100MHZ | System clock |
| rst | G15 | BTN0 | System reset |
| btn_trigger | K16 | BTN1 | Trojan trigger |
| sw[0:3] | H14, H18, G18, M5 | SW0-SW3 | Inputs |
| led_green | E18 | LD0 | Auth passed |
| led_red | F13 | LD1 | Trojan detected |
| led_blue | E13 | LD2 | Healing active |
| led_white | H15 | LD3 | System safe |
| led_yellow | F18 | RGB1_G | Suspicious |
| led_fault | E17 | RGB1_B | Backup failed |
| led_watchdog | L17 | JA[0] | Timeout alert |

---

## Running the Simulation

**1. Clone the repository**
```bash
git clone https://github.com/yourusername/sentinel-x.git
```

**2. Open Vivado and load project**
```
File → Open Project → selfheal_fpga_security.xpr
```

**3. Run simulation**
```
Flow Navigator → Run Simulation → Run Behavioural Simulation
```

**4. Expected console output**
```
STEP 1 — Boot and PUF Authentication   [PASS]
STEP 2 — Normal Circuit Operation      [PASS]
STEP 3 — Trojan Trigger Activated      [PASS]
STEP 4 — AI Classifier Running         [PASS]
STEP 5 — Security Controller Response  [PASS]
STEP 6 — Self-Healing Recovery         [PASS]
FINAL — Backup Output Verification     [PASS]
RESET — Full System Reset Test         [PASS]
```

**5. Generate bitstream (when board available)**
```
Flow Navigator → Generate Bitstream → Program Device
```

---

## FSM State Machine

| State | LED | Description |
|-------|-----|-------------|
| BOOT | All OFF | System initialising |
| AUTHENTICATING | Green blink | PUF sampling |
| AUTH_FAILED | Red blink | Device rejected |
| NORMAL | Green solid | Clean operation |
| SUSPICIOUS | Yellow + Green blink | Anomaly detected |
| TROJAN_FOUND | Red solid | Attack confirmed |
| HEALING | Red + Blue blink | Switching to backup |
| SAFE | Blue + White solid | System recovered |

---

## Key Features

- Real-time Hardware Trojan detection in a single clock cycle
- PUF with Hamming distance tolerance for noise robustness
- Challenge-response authentication with 4-entry CRP table
- Two-stage AI classifier — fast pass + deep verification
- Self-test on backup activation before declaring safe
- Watchdog protection against stuck healing states
- Full simulation testbench with PASS/FAIL verification
- SIM_MODE parameter for fast simulation without code changes

---

## Research Context

Hardware Trojan detection is an active research priority at:

- DARPA — TRUST and SHIELD programs
- Intel — Hardware Security Research
- IBM — Trusted Computing Group
- TSMC — Supply Chain Security

This project implements and demonstrates the core concepts
studied in:

> Tehranipoor and Koushanfar, "A Survey of Hardware Trojan 
> Taxonomy and Detection", IEEE Design & Test, 2010.

> Karri et al., "Trustworthy Hardware: Identifying and 
> Classifying Hardware Trojans", IEEE Computer, 2010.

---

## License

MIT License — free to use, modify, and distribute with 
attribution.

---

## Author

**[Prime R S]**  
Government College of Engineering  
Erode, India  
