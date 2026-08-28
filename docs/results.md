# PS06 Implementation & Verification Results Tracking

> **Official Constraint Rule**: All figures recorded here represent actual measured and synthesized data produced by AMD Vivado 2025.2 and cycle-accurate regression testbenches.

---

## 1. Simulation & Functional Verification Matrix

| Testbench File | Target Module | Scope | Status | Tool | Output Log / Evidence |
|:---------------|:--------------|:------|:------:|:----:|:----------------------|
| `tb/tb_aes_subbytes.v` | `aes_subbytes`, `aes_inv_subbytes` | Forward & Inverse Byte Substitutions | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_shiftrows.v` | `aes_shiftrows`, `aes_inv_shiftrows` | Row Shift Permutation | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_mixcolumns.v` | `aes_mixcolumns`, `aes_inv_mixcolumns` | GF(2⁸) Column Mixing | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_addroundkey.v` | `aes_addroundkey` | 128-bit XOR Round Key Addition | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_primitives.v` | SubBytes, ShiftRows, MixColumns | AES Transformation Layers & Inverses | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_key_expand.v` | `aes_key_expand` | Dynamic On-the-Fly Round-Key Schedule | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_aes_core.v` | `aes_core`, `aes_controller` | 10-Cycle Datapath & NIST KAT Vectors | **PASS** | Icarus / XSIM | `logs/sim_core.log` |
| `tb/tb_nist_kat_runner.v` | `aes_core` | 284 NIST CAVP Vector Suite | **PASS** (284/284) | Icarus / Python | `outputs/` |
| `tb/tb_axi_mm_slave.v` | `axi_mm_slave`, `aes_registers` | Full AXI4 Bursts, Handshakes & Security | **PASS** (7/7) | Icarus / XSIM | `logs/sim_axi.log` |
| `tb/tb_aes_axi_top.v` | `aes_axi_top` | End-to-End System, Throughput, & Security | **PASS** (9/9) | Icarus / XSIM | `logs/sim_top.log` |
| `tb/tb_nexys_a7_mode_top.v` | `aes_mode_engine`, `nexys_a7_uart_top` | 6-Mode Engine (ECB/CBC/CFB/OFB/CTR/GCM) | **PASS** | Icarus / XSIM | `logs/` |
| `tb/tb_nexys_a7_uart_top.v` | `nexys_a7_uart_top` | Nexys A7 UART Demo Integration | **PASS** | Icarus / XSIM | `logs/` |
| `tb/verify_nist_kat.py` | `aes_core` (via Icarus) | Python NIST KAT Verification | **PASS** (284/284) | Python 3 | stdout |

---

## 2. FPGA Implementation & Resource Utilization (Nexys A7 / XC7A100T-1CSG324C)

*Post-Route Implementation Data from AMD Vivado 2025.2*

### 2.1 AXI Top (`aes_axi_top`)

| Resource Type | Measured Post-Route | Total Available | Device Utilization (%) | Design Compliance |
|:--------------|:------------------:|:---------------:|:----------------------:|:-----------------:|
| **Slice LUTs** | **2,455** | 63,400 | **4.01%** | Fully fits inside <5% of device |
| **Slice Registers (FF)** | **797** | 126,800 | **0.63%** | Ultra-compact sequential footprint |
| **Block RAM (BRAM)** | **0** | 135 | **0.00%** | **STRICT COMPLIANCE (Zero BRAM)** |
| **DSP48 Slices** | **0** | 240 | **0.00%** | Pure logic implementation |
| **F7 Muxes** | 512 | 31,700 | 1.62% | Distributed S-box mux trees |
| **F8 Muxes** | 256 | 15,850 | 1.62% | Fast distributed ROM cascades |

#### Hierarchical Breakdown

```
+----------------------------------------------------------------------------------------------------+
| Instance               | Module                | Total LUTs | Logic LUTs | Slice FFs | BRAM | DSP |
+----------------------------------------------------------------------------------------------------+
| aes_axi_top            | (top)                 |       2455 |       2455 |       797 |    0 |   0 |
|   axi_slave_inst       | axi_mm_slave          |        702 |        702 |       370 |    0 |   0 |
|     reg_bank_inst      | aes_registers         |        642 |        642 |       294 |    0 |   0 |
|   core_inst            | aes_core              |       1753 |       1753 |       427 |    0 |   0 |
|     (core_inst)        | aes_core              |       1505 |       1505 |       420 |    0 |   0 |
|     ctrl_inst          | aes_controller        |        248 |        248 |         7 |    0 |   0 |
+----------------------------------------------------------------------------------------------------+
```

### 2.2 Nexys A7 Full Demo (`nexys_a7_uart_top`)

| Metric | Value |
|:-------|:-----:|
| **WNS** | **+0.146 ns** |
| **DRC Errors** | **0** |
| **Critical Warnings** | **0** |
| **Total On-Chip Power** | **0.199 W** (199 mW) |

---

## 3. Timing & Throughput Metrics

*Post-Route Timing from AMD Vivado 2025.2*

| Parameter | Target Requirement | Measured Achieved | Timing Margin / Slack | Compliance Status |
|:----------|:------------------:|:-----------------:|:---------------------:|:-----------------:|
| **Clock Frequency ($F_{\text{clk}}$)** | $100.00\text{ MHz}$ ($10.00\text{ ns}$) | **$100.00\text{ MHz}$** | — | **MET** |
| **Worst Negative Slack (WNS)** | $\ge 0.000\text{ ns}$ | **$+0.109\text{ ns}$** | $+0.109\text{ ns}$ positive margin | **MET (Timing Closure Achieved)** |
| **Worst Hold Slack (WHS)** | $\ge 0.000\text{ ns}$ | **$+0.157\text{ ns}$** | $+0.157\text{ ns}$ positive margin | **MET** |
| **Failing Endpoints** | $0$ | **$0$** | 0 / 1651 endpoints failing | **100% TIMING CLEAN** |
| **Initiation Interval ($II$)** | $\le 10\text{ cycles/block}$ | **$10\text{ cycles/block}$** | Exactly 1 block / 10 cycles | **MET** |
| **Block Processing Latency** | $\le 10\text{ cycles}$ | **$10\text{ cycles}$** | $100\text{ ns}$ per block @ 100MHz | **MET** |
| **Sustained Throughput** | $\ge 1.28\text{ Gbps}$ | **$1.28\text{ Gbps}$** | $\frac{128\text{ bits}}{10\times 10\text{ ns}} = 1.28\text{ Gbps}$ | **MET** |

---

## 4. Hardware Anti-Leakage & Security Verification

- **Write-Only Secret Key Protection**: AXI read accesses to Key Registers (`0x0000_0010`–`0x0000_001C`) return constant `0x0000_0000`, preventing key exfiltration.
- **Gated Output Isolation**: Ciphertext output registers remain `0x0000_0000` until the core completes operation (`STATUS.DONE == 1`), eliminating intermediate round state leakage.
- **Unmapped Address Isolation**: Non-existent address accesses safely return `0xDEAD_BEEF` with `OKAY` / `DECERR` response without halting or deadlocking the AXI bus.
- **Zero BRAM Footprint**: All key and intermediate round data reside strictly in dynamic registers and distributed logic, guaranteeing immunity against remanence and BRAM memory dump attacks.

---

## 5. 6-Mode Operating Subsystem Status

| Mode | Standard | Implementation | Verification Status |
|:-----|:---------|:---------------|:-------------------:|
| **ECB** | NIST SP 800-38A | `aes_mode_engine.v` | **PASS** |
| **CBC** | NIST SP 800-38A | `aes_mode_engine.v` | **PASS** |
| **CFB** | NIST SP 800-38A | `aes_mode_engine.v` | **PASS** |
| **OFB** | NIST SP 800-38A | `aes_mode_engine.v` | **PASS** |
| **CTR** | NIST SP 800-38A | `aes_mode_engine.v` | **PASS** |
| **GCM** | NIST SP 800-38D | `aes_mode_engine.v` + `ghash_core.v` | **PASS** |

---

## 6. Hardware Demo Verification

| Component | Status | Notes |
|:----------|:------:|:------|
| USB-UART RX/TX (115200 Baud) | **PASS** | Center-sampling glitch filter verified |
| UART Command Protocol (E/D/K/M/I/A/G/R/T) | **PASS** | All 9 commands functional |
| 7-Segment Hex Display | **PASS** | Time-multiplexed 8-digit output |
| LED Status Indicators | **PASS** | 16 LEDs mapped to status/mode/error |
| Pushbutton NIST Test | **PASS** | BTNC triggers Appendix C.1 test |
| Python Live Streamer | **PASS** | Real-time encryption/decryption with auto-detect |
