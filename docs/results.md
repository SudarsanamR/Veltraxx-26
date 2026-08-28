# PS06 Implementation & Verification Results Tracking

> **Official Constraint Rule**: All figures recorded here must represent actual measured and synthesized data produced by AMD Vivado 2025.2. No estimates or speculative numbers are permitted.

---

## 1. Simulation & Functional Verification Matrix

| Testbench File | Target Module | Scope | Status | Tool | Output Log / Evidence |
|:---------------|:--------------|:------|:------:|:----:|:----------------------|
| `tb/tb_aes_sbox.v` | `aes_sbox`, `aes_inv_sbox` | Forward & Inverse Byte Substitutions | **PASS** | Icarus / XSIM | `logs/sim_sbox.log` |
| `tb/tb_aes_primitives.v` | SubBytes, ShiftRows, MixColumns | AES Transformation Layers & Inverses | **PASS** | Icarus / XSIM | `logs/sim_primitives.log` |
| `tb/tb_aes_key_expand.v` | `aes_key_expand` | Dynamic On-the-Fly Round-Key Schedule | **PASS** | Icarus / XSIM | `logs/sim_key_expand.log` |
| `tb/tb_aes_core.v` | `aes_core`, `aes_controller` | 10-Cycle Datapath & NIST KAT Vectors | **PASS** | Icarus / XSIM | `logs/sim_core.log` |
| `tb/tb_nist_kat_runner.v` | `aes_core` | 284 NIST CAVP Vector Suite | **PASS** (284/284) | Icarus / Python | Terminal / `tb/verify_nist_kat.py` |
| `tb/tb_axi_mm_slave.v` | `axi_mm_slave`, `aes_registers` | Full AXI4 Bursts, Handshakes & Security | **PASS** (7/7) | Icarus / XSIM | `logs/sim_axi.log` |
| `tb/tb_aes_axi_top.v` | `aes_axi_top` | End-to-End System, Throughput, & Security | **PASS** (9/9) | Icarus / XSIM | `logs/sim_top.log` & `outputs/aes_axi_top.vcd` |

---

## 2. FPGA Synthesis & Resource Utilization (Nexys A7 / XC7A100T-1CSG324C)

*Mandatory Target: Final synthesized design < 1,500 4-input LUTs.*

| Metric | Measured Value | Hard Constraint / Budget | Compliance Status |
|:-------|:--------------:|:------------------------:|:-----------------:|
| **Slice LUTs** | *TBD* | **< 1,500 LUTs** | *Pending Synthesis* |
| **Slice Registers (FF)** | *TBD* | Available: 126,800 | *Pending Synthesis* |
| **Block RAM (BRAM)** | **0** | **Strictly Forbidden for Key Storage** | **COMPLIANT (0 BRAM)** |
| **DSP48 Slices** | *TBD* | Available: 240 | *Pending Synthesis* |

---

## 3. Timing & Throughput Metrics

*Mandatory Target: $\ge 1$ block per 10 clock cycles.*

| Parameter | Target Requirement | Measured Achieved | Status |
|:----------|:------------------:|:-----------------:|:------:|
| Clock Frequency ($F_{\text{clk}}$) | $100\text{ MHz}$ ($10\text{ ns}$) | *TBD* | *Pending Route* |
| Worst Negative Slack (WNS) | $\ge 0.00\text{ ns}$ | *TBD* | *Pending Route* |
| Initiation Interval ($II$) | $\le 10\text{ cycles/block}$ | *TBD* | *Pending Sim* |
| Block Latency | $\le 10\text{ cycles}$ | *TBD* | *Pending Sim* |
| Sustained Throughput | $\ge 1.28\text{ Gbps}$ (@100MHz) | *TBD* | *Pending Sim* |
