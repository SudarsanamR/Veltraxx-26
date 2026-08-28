# PS06: Hardware AES-128 Symmetric Block Cipher Core with Full AXI4 Interface
### VELTRAXX '26 Hackathon Problem Statement 06

A high-throughput, resource-constrained, and cryptographically secure AES-128 encryption and decryption accelerator implemented in synthesizable Verilog, featuring a **Full AXI4 Memory-Mapped (AXI4-MM)** bus interface with burst transfer capabilities for seamless SoC integration. Designed, synthesized, and fully timing-closed for AMD/Xilinx 7-Series FPGAs (Digilent Nexys A7, XC7A100T-1CSG324C).

---

## 1. Core Architectural Highlights & Measured Results

- **100% Timing Closure at 100 MHz**:
  - **Worst Negative Slack (WNS)**: **$+0.109\text{ ns}$** (Positive margin on Artix-7 speed grade -1).
  - **Worst Hold Slack (WHS)**: **$+0.157\text{ ns}$**.
  - **Failing Endpoints**: **0** (Zero timing violations across all 1,651 endpoints).
- **High Throughput ($\ge 1$ Block per 10 Cycles)**:
  - Iterative single-round-per-cycle datapath with an Initiation Interval ($II$) of exactly **10 clock cycles**.
  - Delivers **1.28 Gbps** sustained throughput at 100 MHz clock frequency ($128\text{ bits} / 100\text{ ns}$).
- **NIST FIPS-197 AES-128 Compliance**:
  - Full support for 128-bit block encryption and decryption across 10 rounds.
  - Standard transformations: `SubBytes` / `InvSubBytes`, `ShiftRows` / `InvShiftRows`, `MixColumns` / `InvMixColumns`, `AddRoundKey`.
  - **100% PASS** on 284 NIST CAVP test vectors (`ECBKeySbox128`, `ECBVarKey128`, `ECBVarTxt128`, `ECBGFSbox128`).
- **Key-Ahead On-the-Fly Key Generation**:
  - Dynamically calculates round keys $K_1 \dots K_{10}$ on-the-fly using 4 S-boxes off the critical datapath.
  - **Zero BRAM Utilization**: Pre-computed BRAM round-key tables are strictly avoided in compliance with challenge rules.
- **Secure Full AXI4 Interface**:
  - Full AXI4 memory-mapped slave interface (`axi_mm_slave.v`) with support for single and 4-beat burst transfers (`INCR`), transaction ID reflection, and `wlast`/`rlast` handling.
  - **Cryptographic Isolation**: Intermediate transformation states and dynamically generated round keys are strictly inaccessible through AXI reads.
  - **Write-Only Key Protection**: Key registers return `32'h0000_0000` on read to prevent secret theft.
  - **Gated Result Availability**: Output registers return `32'h0000_0000` during execution (`BUSY == 1`).

---

## 2. FPGA Implementation Summary (Nexys A7 / XC7A100T-1CSG324C)

| Metric | Post-Route Value | Available on XC7A100T | Device Utilization | Compliance |
|:-------|:----------------:|:---------------------:|:------------------:|:----------:|
| **Slice LUTs** | **2,455** | 63,400 | **4.01%** | Ultra-compact (<5% device) |
| **Slice Registers (FF)** | **797** | 126,800 | **0.63%** | Minimal register footprint |
| **Block RAM (BRAM)** | **0** | 135 | **0.00%** | **STRICT COMPLIANCE (0 BRAM)** |
| **DSP48 Slices** | **0** | 240 | **0.00%** | Pure logic implementation |
| **Clock Frequency** | **100.00 MHz** | — | — | **10.000 ns clock period** |
| **Worst Negative Slack (WNS)** | **+0.109 ns** | — | — | **TIMING CLOSED** |

---

## 3. Mandatory Repository Structure

```
ps06_aes/
├── README.md                 # Project summary, architecture, and reproduction instructions
├── docs/                     # Specifications and architectural documentation
│   ├── architecture.md       # Detailed microarchitecture, folding schedule, and datapath
│   ├── register_map.md       # Full AXI4 register map and bitfield definitions
│   ├── security.md           # Anti-leakage threat model and security verification
│   ├── verification.md       # Hierarchical test plan and NIST CAVP vector coverage
│   ├── dev_log.md            # Traceable chronological hackathon development log
│   └── results.md            # Measured post-route implementation and timing results
├── src/                      # Synthesizable RTL source code
│   ├── aes/                  # Cryptographic engine, datapath, and on-the-fly key expander
│   ├── axi/                  # Full AXI4 slave interface and secure register bank
│   └── top/                  # Top-level SoC wrapper (aes_axi_top.v)
├── tb/                       # Self-checking verification testbenches
├── constraints/              # Target FPGA constraint files (nexys_a7.xdc)
├── scripts/                  # Vivado automation scripts (synth_aes_axi_top.tcl, build.tcl)
├── logs/                     # Build, synthesis, and implementation logs
├── outputs/                  # Generated reports, timing summaries, and simulation waveforms
└── presentation/             # Official VELTRAXX ’26 slide deck presentation
```

---

## 4. Verification & Build Instructions

### Running Full System Integration & Security Simulation:
```bash
iverilog -g2012 -o sim_top.out src/aes/*.v src/axi/*.v src/top/*.v tb/tb_aes_axi_top.v
vvp sim_top.out
```

### Running Automated NIST CAVP Test Suite (284 vectors):
```bash
python3 tb/verify_nist_kat.py
```

### Running Full FPGA Implementation & Timing Closure:
```bash
vivado -mode batch -source scripts/synth_aes_axi_top.tcl
```

---

## 5. Development Status

- [x] **Phase 0**: Final Specification, Security Strategy, & Repository Setup
- [x] **Phase 1**: AES Functional Baseline (S-Box, Primitives, Key Expansion, Core Datapath)
- [x] **Phase 2**: Performance & Resource Optimization (10-Cycle Throughput)
- [x] **Phase 3**: Secure Full AXI4 Interface & Anti-Leakage Verification
- [x] **Phase 4**: Full Top-Level Integration & Regression
- [x] **Phase 5**: FPGA Prototype & Timing Closure (Nexys A7, WNS = +0.109 ns @ 100 MHz)
- [ ] **Phase 6**: Final Demonstration, Waveform Evidence, & Submission
- [ ] **Phase 7**: Judge-Driven Iteration / Enhancement
