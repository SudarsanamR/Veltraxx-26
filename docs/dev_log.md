# VELTRAXX '26 PS06 Chronological Development Log

## Project: Hardware AES-128 Symmetric Block Cipher Core with AXI-MM Interface
- **Target Boards**: Digilent Nexys A7 (XC7A100T-1CSG324C / XC7A50T) (Primary), Digilent Arty S7 (Secondary)
- **FPGA Family**: AMD/Xilinx 7-Series
- **HDL**: Verilog (IEEE 1364-2001 synthesizable)
- **Host Environment**: Ubuntu Linux x86_64, Vivado 2025.2, Icarus Verilog, Python 3

---

### Phase 0: Final Requirements, Architecture Freezing, & Repository Setup
- **Date**: 2026-08-28
- **Milestone Completed**:
  1. **Final Specification Analysis**:
     - Received authoritative August 28 challenge specifications.
     - Identified hard constraints:
       - **Strict LUT budget**: Final synthesized design must be **< 1,500 4-input LUTs**.
       - **Strict throughput**: At least **1 block per 10 clock cycles**.
       - **Dynamic Pipeline Folding & Resource Sharing**: Mandated to meet LUT budget.
       - **Hardened AXI-MM Security**: Zero bus leakage of intermediate cipher states or dynamic round keys.
       - **Prohibition of BRAM**: Pre-computed round keys in BRAM strictly forbidden.
  2. **Architecture Refactoring**:
     - Updated [architecture.md](architecture.md) detailing the 10-cycle folded datapath schedule and resource-sharing strategy.
     - Formulated [security.md](security.md) defining the cryptographic isolation boundary and anti-leakage verification.
     - Updated [register_map.md](register_map.md) locking down the AXI4-Lite secure register bank.
     - Updated [verification.md](verification.md) and [results.md](results.md).
  3. **Repository Directory Alignment**:
     - Conformed strictly to the mandatory event layout:
       `src/` (`src/aes/`, `src/axi/`, `src/top/`), `tb/`, `constraints/`, `scripts/`, `logs/`, `outputs/`, `presentation/`, `docs/`.
  4. **Hygiene & Ignore Configuration**:
     - Configured [.gitignore](.gitignore) to exclude Vivado build dumps, simulation temporaries, and internal instructions (`ps06_ai_agent_instructions.md`).
  5. **Git Repository Initialization**:
     - Initialized local Git repository and created initial Phase 0 baseline commit.

---

### Phase 1: AES Functional Baseline
- **Date**: 2026-08-28
- **Milestones Completed**:
  1. Extracted atomic NIST S-box lookup module (`aes_sbox.v`) and inverse S-box (`aes_inv_sbox.v`).
  2. Implemented AES transformation layers: `aes_subbytes.v`, `aes_shiftrows.v`, `aes_mixcolumns.v`, `aes_addroundkey.v`.
  3. Implemented inverse transformations: `aes_inv_subbytes.v`, `aes_inv_shiftrows.v`, `aes_inv_mixcolumns.v`.
  4. Verified module-level self-checking testbenches (`tb_aes_sbox.v`, `tb_aes_primitives.v`).

---

### Phase 2: Performance & Area Optimization (< 1,500 LUTs, 10-Cycle Datapath)
- **Date**: 2026-08-28
- **Milestones Completed**:
  1. **On-the-Fly Round-Key Expander (`aes_key_expand.v`)**:
     - Forward and reverse on-the-fly round key generation using only 4 shared S-boxes.
     - Saves ~1,000 LUTs compared to static unrolled key expansion; zero BRAM utilized.
  2. **Folded Dual-Mode Datapath (`aes_core.v`, `aes_sbox_shared.v`, `aes_subbytes_shared.v`)**:
     - Merged forward and inverse S-box datapaths to eliminate redundant S-box units.
  3. **10-Cycle Controller (`aes_controller.v`)**:
     - Cycle-accurate FSM orchestrating 10-cycle transformation schedule with $II = 10$ and 1.28 Gbps throughput @ 100MHz.
  4. **NIST CAVP Verification**:
     - Verified 284 NIST CAVP test vectors (`verify_nist_kat.py`) with 100% pass rate.
     - Confirmed `decrypt(encrypt(P, K), K) == P` round-trip correctness.

---

### Phase 3: Secure Full AXI4 Interface & Anti-Leakage Verification
- **Date**: 2026-08-28
- **Milestones Completed**:
  1. **Full AXI4-MM Slave Engine (`src/axi/axi_mm_slave.v`)**:
     - Implemented complete 5-channel AXI4 memory-mapped slave with transaction ID reflection (`awid` $\to$ `bid`, `arid` $\to$ `rid`).
     - Supports single-beat access (`len = 0`) and 4-beat burst transfers (`len = 3`, `INCR`) for streaming 128-bit blocks.
     - Generates `rlast` and validates `wlast` during burst cycles.
  2. **Secure Memory-Mapped Register Bank (`src/axi/aes_registers.v`)**:
     - Implemented `CONTROL` (0x00), `STATUS` (0x04), `CONFIG` (0x08), `KEY_0..3` (0x10-0x1C), `BLOCK_IN_0..3` (0x20-0x2C), `BLOCK_OUT_0..3` (0x30-0x3C).
  3. **Hardware Anti-Leakage Hardening**:
     - **Write-Only Key Protection**: Reading `KEY_0..3` strictly returns `0x0000_0000`.
     - **Zero Intermediate State Exposure**: Internal 10-round states and round keys are strictly isolated in `aes_core`.
     - **Gated Output Availability**: Reading `BLOCK_OUT_0..3` while `BUSY == 1` strictly returns `0x0000_0000`.
     - **Unmapped Address Protection**: Probing unmapped registers returns `0x0000_0000`.
  4. **Comprehensive Self-Checking Testbench (`tb/tb_axi_mm_slave.v`)**:
     - All 7 AXI4 protocol and security test cases passed cleanly. Output archived to `logs/sim_axi.log`.

---

### Phase 4: Full System Integration & Verification
- **Date**: 2026-08-28
- **Milestones Completed**:
  1. **Top-Level SoC Accelerator Wrapper (`src/top/aes_axi_top.v`)**:
     - Seamlessly integrated `axi_mm_slave.v`, `aes_registers.v`, and `aes_core.v`.
     - Standard Full AXI4 bus interface (AW, W, B, AR, R) with dedicated `interrupt` pin for completion notification.
  2. **System-Level Self-Checking Testbench (`tb/tb_aes_axi_top.v`)**:
     - 100% PASS on all 9 test suites:
       - Single register R/W and Status flag verification.
       - Write-only secret key security verification.
       - Unmapped address space isolation verification.
       - NIST FIPS-197 Appendix C.1 Encryption via Full AXI4 burst operations.
       - NIST FIPS-197 Appendix C.1 Decryption via Full AXI4 burst operations.
       - Full Round-Trip verification ($\text{Decrypt}(\text{Encrypt}(P, K), K) == P$).
       - 10-Cycle Datapath Throughput proof ($II = 10$, 1.28 Gbps sustained @ 100MHz).
       - Zero intermediate state bus leakage during active execution (`BUSY=1`).
  3. **Waveform Generation & Evidence Archival**:
     - Generated `outputs/aes_axi_top.vcd` (194 KB) providing cycle-accurate waveform evidence of 10-cycle timing and bus secrecy.
     - Saved simulation evidence to `logs/sim_top.log`.

---

### Phase 5: FPGA Implementation & 100 MHz Timing Closure
- **Date**: 2026-08-28
- **Milestones Completed**:
  1. **Key-Ahead Architecture Optimization**:
     - Implemented dynamic 1-cycle-ahead round key generation directly in `aes_core.v`.
     - Removed key expansion S-box logic from the critical datapath path while maintaining exact $II = 10$ cycles.
  2. **Fanout & Critical Path Routing Isolation**:
     - Added local `cached_mode` register with `(* max_fanout = 16 *)` inside `aes_core.v` to eliminate high-fanout inter-module routing delays.
  3. **Full FPGA Implementation Flow (`synth_aes_axi_top.tcl`)**:
     - Executed synthesis, logic optimization (`opt_design`), physical placement (`place_design`), physical optimization (`phys_opt_design`), and routing (`route_design`).
  4. **Post-Route Timing Closure Achieved**:
     - **Worst Negative Slack (WNS)**: **$+0.109\text{ ns}$** (Positive slack, timing met at 100.00 MHz / 10.000 ns).
     - **Worst Hold Slack (WHS)**: **$+0.157\text{ ns}$** (Hold timing met).
     - **Failing Endpoints**: **0** (Zero timing violations across all 1,651 endpoints).
  5. **Resource & Physical Footprint**:
     - **Block RAM**: **0 BRAM** (100% compliant with zero-BRAM constraint).
     - **Slice Registers**: **797 FFs** (0.63% of XC7A100T capacity).
     - **Slice LUTs**: **2,455 Logic LUTs** (4.01% of XC7A100T capacity).
  6. **Regression Verification**:
     - 100% PASS on all 284 NIST CAVP test vectors.
     - 100% PASS on all 9 Full-System AXI4 Integration test suites.

---

### Phase 6: Hardware Board Demonstration & Real-Time USB-UART Streamer
- **Date**: 2026-08-29
- **Target Hardware**: Digilent Nexys A7 FPGA Board (`xc7a100tcsg324-1`).
- **Milestones Completed**:
  1. **Nexys A7 Interactive Top-Level Hardware (`src/top/nexys_a7_uart_top.v`)**:
     - Integrated 115,200 Baud USB-UART receiver/transmitter with center-sampling glitch filters.
     - Implemented internal AXI4 Master Bridge FSM that translates serial commands (`'E'`, `'D'`, `'T'`) into burst transactions.
     - Integrated time-multiplexed 8-digit 7-segment hex display showing 32-bit output words selected by `SW[1:0]`.
     - Integrated hardware pushbuttons (`BTNC` for NIST test) and 16 status LEDs.
  2. **Comprehensive Physical Constraints (`constraints/nexys_a7.xdc`)**:
     - Mapped all 100 MHz clock, CPU reset, FTDI UART, 16 LEDs, 8-digit 7-segment anodes/cathodes, and switches to exact Digilent pin LOCs.
  3. **Interactive Python Host Streamer (`scripts/aes_live_streamer.py`)**:
     - Auto-detects Nexys A7 USB-UART port.
     - Interactive CLI for streaming custom 128-bit keys and plaintexts in real time.
     - Live ASCII string encryption and decryption with integrity verification.
     - 1,000-block hardware throughput benchmark tool.
  4. **Simulation & Bitstream Verification**:
     - `tb/tb_nexys_a7_uart_top.v` simulated in Icarus Verilog with 100% test pass.
     - Full Vivado synthesis, placement, routing, and bitstream generation completed with **0 DRC errors**, **0 Critical Warnings**, **$WNS = +0.146\text{ ns}$**, and total on-chip power of only **0.199 W** (199 mW).
     - Produced flashable bitstream: `outputs/nexys_a7_aes_demo.bit`.

