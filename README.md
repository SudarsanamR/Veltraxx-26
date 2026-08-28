# PS06: Hardware AES-128 Symmetric Block Cipher Core with Full AXI4 Interface
### VELTRAXX '26 Hackathon Problem Statement 06

A high-throughput, resource-constrained, and cryptographically secure AES-128 encryption and decryption accelerator implemented in synthesizable Verilog, featuring a **Full AXI4 Memory-Mapped (AXI4-MM)** bus interface with burst transfer capabilities for seamless SoC integration. Designed and validated for AMD/Xilinx 7-Series FPGAs (Digilent Nexys A7).

---

## 1. Core Architectural Constraints & Highlights

- **NIST FIPS-197 AES-128 Compliance**:
  - Full support for 128-bit block encryption and decryption across 10 rounds.
  - Standard transformations: `SubBytes` / `InvSubBytes`, `ShiftRows` / `InvShiftRows`, `MixColumns` / `InvMixColumns`, `AddRoundKey`.
  - 100% PASS on 284 NIST CAVP test vectors (`ECBKeySbox128`, `ECBVarKey128`, `ECBVarTxt128`, `ECBGFSbox128`).
- **Strict LUT Budget (< 1,500 4-Input LUTs)**:
  - Employs **dynamic pipeline folding** and **temporal resource sharing** across forward and inverse transformations to fit comfortably within the 1,500 LUT limit.
- **High Throughput ($\ge 1$ Block per 10 Cycles)**:
  - Iterative single-round-per-cycle architecture achieving an Initiation Interval ($II$) of 10 clock cycles.
  - Delivers **1.28 Gbps** sustained throughput at 100 MHz clock frequency.
- **On-the-Fly Round-Key Generation**:
  - Dynamically calculates round keys $K_1 \dots K_{10}$ on-the-fly using only 4 S-boxes total.
  - **Zero BRAM Utilization**: Pre-computed BRAM round-key tables are strictly avoided in compliance with challenge rules.
- **Secure Full AXI4 Interface**:
  - Full AXI4 memory-mapped slave interface (`axi_mm_slave.v`) with support for single and 4-beat burst transfers (`INCR`), ID reflection, and `wlast`/`rlast` handling.
  - **Cryptographic Isolation**: Intermediate transformation states and dynamically generated round keys are strictly inaccessible through AXI reads, eliminating bus-probing attack vectors.
  - **Write-Only Key Protection**: Key registers return `32'h0000_0000` on read to prevent secret theft.
  - **Gated Result Availability**: Output registers return `32'h0000_0000` during execution (`BUSY == 1`).

---

## 2. Mandatory Repository Structure

```
ps06_aes/
├── README.md                 # Project summary, architecture, and reproduction instructions
├── docs/                     # Specifications and architectural documentation
│   ├── architecture.md       # Detailed microarchitecture, folding schedule, and datapath
│   ├── register_map.md       # Full AXI4 register map and bitfield definitions
│   ├── security.md           # Anti-leakage threat model and security verification
│   ├── verification.md       # Hierarchical test plan and NIST CAVP vector coverage
│   ├── dev_log.md            # Traceable chronological hackathon development log
│   └── results.md            # Measured synthesis, timing, and benchmark results
├── src/                      # Synthesizable RTL source code
│   ├── aes/                  # Cryptographic engine, datapath, and on-the-fly key expander
│   ├── axi/                  # Full AXI4 slave interface and secure register bank
│   └── top/                  # Top-level SoC wrapper (aes_axi_top.v)
├── tb/                       # Self-checking verification testbenches
├── constraints/              # Target FPGA constraint files (nexys_a7.xdc)
├── scripts/                  # Vivado automation scripts (sim.tcl, build.tcl, report.tcl)
├── logs/                     # Build, synthesis, and implementation logs
├── outputs/                  # Generated reports, timing summaries, and simulation waveforms
└── presentation/             # Official VELTRAXX ’26 slide deck presentation
```

---

## 3. Toolchain & Dependencies

- **FPGA Synthesis & Implementation**: AMD Vivado 2025.2
- **RTL Simulation**: Icarus Verilog (`iverilog` / `vvp`) and Vivado XSIM
- **Host Testing**: Python 3.8+ (`pycryptodome` for NIST vector verification)

---

## 4. Simulation & Build Instructions

### Running Full AXI4 Slave & Security Anti-Leakage Simulation:
```bash
iverilog -g2012 -o sim_axi.out src/aes/*.v src/axi/*.v tb/tb_axi_mm_slave.v
vvp sim_axi.out
```

### Running Unified 10-Cycle AES Core Testbench:
```bash
iverilog -g2012 -o sim_core.out src/aes/*.v tb/tb_aes_core.v
vvp sim_core.out
```

### Running Automated NIST CAVP Test Suite (284 vectors):
```bash
python3 tb/verify_nist_kat.py
```

---

## 5. Development Status

- [x] **Phase 0**: Final Specification, Security Strategy, & Repository Setup
- [x] **Phase 1**: AES Functional Baseline (S-Box, Primitives, Key Expansion, Core Datapath)
- [x] **Phase 2**: Performance & Resource Optimization (< 1,500 LUTs, 10-Cycle Throughput)
- [x] **Phase 3**: Secure Full AXI4 Interface & Anti-Leakage Verification
- [ ] **Phase 4**: Full Top-Level Integration & Regression
- [ ] **Phase 5**: FPGA Prototype & Timing Closure (Nexys A7)
- [ ] **Phase 6**: Final Demonstration, Waveform Evidence, & Submission
- [ ] **Phase 7**: Judge-Driven Iteration / Enhancement
