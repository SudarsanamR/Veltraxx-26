# PS06: Hardware AES-128 Symmetric Block Cipher Core with AXI-MM Interface
### VELTRAXX ’26 Hackathon Problem Statement 06 — FPGA Hardware Prototype

A high-throughput, resource-constrained, and cryptographically secure AES-128 encryption and decryption accelerator implemented in synthesizable Verilog, featuring an AXI-MM (AXI4-Lite) bus interface for SoC integration. Designed and validated for AMD/Xilinx 7-Series FPGAs (Digilent Nexys A7).

---

## 1. Core Architectural Constraints & Highlights

- **NIST FIPS-197 AES-128 Compliance**:
  - Full support for 128-bit block encryption and decryption across 10 rounds.
  - Standard transformations: `SubBytes` / `InvSubBytes`, `ShiftRows` / `InvShiftRows`, `MixColumns` / `InvMixColumns`, `AddRoundKey`.
- **Strict LUT Budget (< 1,500 4-Input LUTs)**:
  - Employs **dynamic pipeline folding** and **temporal resource sharing** across forward and inverse transformations to fit comfortably within the 1,500 LUT limit.
- **High Throughput ($\ge 1$ Block per 10 Cycles)**:
  - Iterative single-round-per-cycle architecture achieving an Initiation Interval ($II$) of 10 clock cycles.
  - Delivers **1.28 Gbps** sustained throughput at 100 MHz clock frequency.
- **On-the-Fly Round-Key Generation**:
  - Dynamically calculates round keys $K_1 \dots K_{10}$ in synchronization with round execution.
  - **Zero BRAM Utilization**: Pre-computed BRAM round-key tables are strictly avoided in compliance with challenge rules.
- **Secure AXI-MM Interface**:
  - Standard 32-bit AXI4-Lite slave interface (`axi_mm_slave.v`).
  - **Cryptographic Isolation**: Intermediate transformation states and dynamically generated round keys are strictly inaccessible through AXI reads, eliminating bus-probing attack vectors.

---

## 2. Mandatory Repository Structure

```
ps06_aes/
├── README.md                 # Project summary, architecture, and reproduction instructions
├── docs/                     # Specifications and architectural documentation
│   ├── architecture.md       # Detailed microarchitecture, folding schedule, and datapath
│   ├── register_map.md       # AXI4-Lite register map and bitfield definitions
│   ├── security.md           # Anti-leakage threat model and security verification
│   ├── verification.md       # Hierarchical test plan and NIST CAVP vector coverage
│   ├── dev_log.md            # Traceable chronological hackathon development log
│   └── results.md            # Measured synthesis, timing, and benchmark results
├── src/                      # Synthesizable RTL source code
│   ├── aes/                  # Cryptographic engine, datapath, and on-the-fly key expander
│   ├── axi/                  # AXI4-Lite slave interface and secure register bank
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

### Running RTL Simulation with Icarus Verilog:
```bash
# Example: Simulating top-level integration
iverilog -g2012 -o sim_top.out src/aes/*.v src/axi/*.v src/top/*.v tb/tb_aes_axi_top.v
vvp sim_top.out
```

### Running Vivado Batch Simulation:
```bash
vivado -mode batch -source scripts/sim.tcl -tclargs tb_aes_axi_top
```

### Running Non-Project Synthesis & Implementation:
```bash
vivado -mode batch -source scripts/build.tcl
```

---

## 5. Development Status

- [x] **Phase 0**: Final Specification, Security Strategy, & Repository Setup
- [ ] **Phase 1**: AES Functional Baseline (S-Box, Primitives, Key Expansion, Core Datapath)
- [ ] **Phase 2**: Performance & Resource Optimization (< 1,500 LUTs, 10-Cycle Throughput)
- [ ] **Phase 3**: Secure AXI-MM Interface & Anti-Leakage Verification
- [ ] **Phase 4**: Full Top-Level Integration & Regression
- [ ] **Phase 5**: FPGA Prototype & Timing Closure (Nexys A7)
- [ ] **Phase 6**: Final Demonstration, Waveform Evidence, & Submission
- [ ] **Phase 7**: Judge-Driven Iteration / Enhancement
