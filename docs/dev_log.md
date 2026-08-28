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
