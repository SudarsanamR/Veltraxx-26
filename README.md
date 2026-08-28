# PS06: Hardware AES-128 Symmetric Block Cipher Core with Full AXI4 Interface
### VELTRAXX '26 Hackathon Problem Statement 06

A high-throughput, resource-constrained, and cryptographically secure AES-128 encryption and decryption accelerator implemented in synthesizable Verilog, featuring a **Full AXI4 Memory-Mapped (AXI4-MM)** bus interface with burst transfer capabilities, a **6-mode operating subsystem** (ECB, CBC, CFB, OFB, CTR, GCM/AEAD), and an interactive **FPGA hardware demo** with USB-UART streaming. Designed, synthesized, and fully timing-closed for AMD/Xilinx 7-Series FPGAs (Digilent Nexys A7, XC7A100T-1CSG324C).

---

## 1. Core Architectural Highlights & Measured Results

- **100% Timing Closure at 100 MHz**:
  - **Worst Negative Slack (WNS)**: **$+0.109\text{ ns}$** (AXI top) / **$+0.146\text{ ns}$** (Nexys A7 demo).
  - **Worst Hold Slack (WHS)**: **$+0.157\text{ ns}$**.
  - **Failing Endpoints**: **0** (Zero timing violations across all endpoints).
- **High Throughput ($\ge 1$ Block per 10 Cycles)**:
  - Iterative single-round-per-cycle datapath with an Initiation Interval ($II$) of exactly **10 clock cycles**.
  - Delivers **1.28 Gbps** sustained throughput at 100 MHz clock frequency ($128\text{ bits} / 100\text{ ns}$).
- **6-Mode NIST Operating Subsystem**:
  - **ECB** (Electronic Codebook — NIST SP 800-38A)
  - **CBC** (Cipher Block Chaining — NIST SP 800-38A)
  - **CFB** (Cipher Feedback — NIST SP 800-38A)
  - **OFB** (Output Feedback — NIST SP 800-38A)
  - **CTR** (Counter Mode — NIST SP 800-38A)
  - **GCM** (Galois/Counter Mode AEAD — NIST SP 800-38D) with dedicated GHASH core
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
- **Interactive FPGA Hardware Demo**:
  - Nexys A7 UART-based interactive demo with USB-UART streaming, 7-segment display, pushbuttons, and LEDs.
  - Python host streamer (`aes_live_streamer.py`) for real-time encryption/decryption from PC.
  - Total on-chip power: **0.199 W** (199 mW).

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

## 3. Repository Structure

```
ps06_aes/
├── README.md                     # Project summary and reproduction instructions
├── docs/                         # Specifications and architectural documentation
│   ├── architecture.md           # Detailed microarchitecture and datapath
│   ├── register_map.md           # Full AXI4 register map and bitfield definitions
│   ├── security.md               # Anti-leakage threat model and security verification
│   ├── verification.md           # Hierarchical test plan and NIST CAVP coverage
│   ├── dev_log.md                # Chronological hackathon development log
│   └── results.md                # Post-route implementation and timing results
├── src/                          # Synthesizable RTL source code
│   ├── aes/                      # Cryptographic engine (18 modules)
│   │   ├── aes_core.v            # Central folded 10-cycle datapath
│   │   ├── aes_controller.v      # Cycle-accurate FSM controller
│   │   ├── aes_key_expand.v      # On-the-fly round key generation (runtime)
│   │   ├── aes_key_expansion.v   # Full combinational key schedule (all 11 keys)
│   │   ├── aes_sbox.v            # Forward S-Box wrapper
│   │   ├── aes_inv_sbox.v        # Inverse S-Box (256-byte distributed ROM)
│   │   ├── aes_sbox_shared.v     # Unified forward/inverse S-Box (512-byte ROM)
│   │   ├── aes_sbox_canright.v   # Canright composite-field S-Box (GF(2^4) tower)
│   │   ├── aes_gf_inv.v          # GF(2^8) multiplicative inverse ROM
│   │   ├── aes_subbytes.v        # Forward SubBytes (16-byte parallel)
│   │   ├── aes_inv_subbytes.v    # Inverse SubBytes
│   │   ├── aes_subbytes_shared.v # Shared enc/dec SubBytes
│   │   ├── aes_shiftrows.v       # Forward ShiftRows (pure wiring)
│   │   ├── aes_inv_shiftrows.v   # Inverse ShiftRows
│   │   ├── aes_mixcolumns.v      # Forward MixColumns (GF(2^8) multiply)
│   │   ├── aes_inv_mixcolumns.v  # Inverse MixColumns
│   │   ├── aes_mixcolumns_shared.v # Shared enc/dec MixColumns
│   │   └── aes_addroundkey.v     # AddRoundKey (128-bit XOR)
│   ├── axi/                      # AXI4 interface and register bank
│   │   ├── axi_mm_slave.v        # Full AXI4 memory-mapped slave engine
│   │   └── aes_registers.v       # Secure register bank (control/status/key/data)
│   └── top/                      # Top-level wrappers and mode engine
│       ├── aes_axi_top.v         # AXI-wrapped AES accelerator top
│       ├── aes_mode_engine.v     # 6-mode subsystem (ECB/CBC/CFB/OFB/CTR/GCM)
│       ├── ghash_core.v          # GHASH GF(2^128) multiplier for GCM AEAD
│       └── nexys_a7_uart_top.v   # Nexys A7 interactive UART demo top
├── tb/                           # Self-checking verification testbenches
│   ├── tb_aes_subbytes.v         # SubBytes unit test
│   ├── tb_aes_shiftrows.v        # ShiftRows unit test
│   ├── tb_aes_mixcolumns.v       # MixColumns unit test
│   ├── tb_aes_addroundkey.v      # AddRoundKey unit test
│   ├── tb_aes_primitives.v       # Combined transformation primitives test
│   ├── tb_aes_key_expand.v       # Key expansion unit test
│   ├── tb_aes_core.v             # AES core 10-cycle datapath test
│   ├── tb_axi_mm_slave.v         # AXI4 slave protocol and security test
│   ├── tb_aes_axi_top.v          # Full system integration test
│   ├── tb_nist_kat_runner.v      # NIST CAVP 284-vector regression
│   ├── tb_nexys_a7_mode_top.v    # Nexys A7 mode engine simulation
│   ├── tb_nexys_a7_uart_top.v    # Nexys A7 UART demo simulation
│   └── verify_nist_kat.py        # Python NIST KAT verification script
├── constraints/                  # Target FPGA constraint files
│   ├── nexys_a7.xdc              # Nexys A7 pin and timing constraints
│   └── README.md                 # Constraint topology documentation
├── scripts/                      # Build, synthesis, and tool scripts
│   ├── build.tcl                 # Main Vivado build script
│   ├── build_nexys_a7.tcl        # Nexys A7 full implementation flow
│   ├── program_nexys_a7.tcl      # FPGA bitstream programming
│   ├── sim.tcl                   # Vivado simulation runner
│   ├── synth_aes_axi_top.tcl     # AXI top synthesis script
│   ├── synth_core.tcl            # Core-only synthesis
│   ├── synth_core_opt.tcl        # Optimized core synthesis
│   ├── report.tcl                # Report generation utilities
│   ├── report_core_hier.tcl      # Hierarchical utilization report
│   ├── report_hier.tcl           # Design hierarchy report
│   ├── test_area.tcl             # Area analysis script
│   ├── aes_live_streamer.py      # Interactive Python USB-UART host streamer
│   ├── synth_canright_test.tcl   # Canright S-Box synthesis experiment
│   ├── synth_dual_direct.tcl     # Dual-port synthesis experiment
│   ├── synth_rom_test.tcl        # ROM synthesis experiment
│   ├── test_rom_dist.v           # ROM distribution test module
│   └── test_sbox_dual_direct.v   # Dual S-Box comparison test module
├── logs/                         # Simulation and build logs (gitignored)
├── outputs/                      # Generated reports and bitstreams (gitignored)
└── presentation/                 # VELTRAXX '26 slide deck presentation
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

### Running Nexys A7 UART Demo Simulation:
```bash
iverilog -g2012 -o sim_nexys.out src/aes/*.v src/axi/*.v src/top/*.v tb/tb_nexys_a7_uart_top.v
vvp sim_nexys.out
```

### Running Full FPGA Implementation & Timing Closure:
```bash
# AXI top synthesis
vivado -mode batch -source scripts/synth_aes_axi_top.tcl

# Full Nexys A7 build (synthesis → place → route → bitstream)
vivado -mode batch -source scripts/build_nexys_a7.tcl
```

### Programming the FPGA:
```bash
vivado -mode batch -source scripts/program_nexys_a7.tcl
```

### Running the Interactive Live Streamer:
```bash
python3 scripts/aes_live_streamer.py
```

---

## 5. Development Status

- [x] **Phase 0**: Final Specification, Security Strategy, & Repository Setup
- [x] **Phase 1**: AES Functional Baseline (S-Box, Primitives, Key Expansion, Core Datapath)
- [x] **Phase 2**: Performance & Resource Optimization (10-Cycle Throughput)
- [x] **Phase 3**: Secure Full AXI4 Interface & Anti-Leakage Verification
- [x] **Phase 4**: Full Top-Level Integration & Regression
- [x] **Phase 5**: FPGA Prototype & Timing Closure (Nexys A7, WNS = +0.109 ns @ 100 MHz)
- [x] **Phase 6**: Hardware Board Demo, 6-Mode Engine, GCM/AEAD, & Live USB-UART Streamer
- [ ] **Phase 7**: Final Demonstration, Waveform Evidence, & Submission
- [ ] **Phase 8**: Judge-Driven Iteration / Enhancement
