# PS06 Architecture Specification
## Hardware AES-128 Symmetric Block Cipher Core with AXI-MM Interface & 6-Mode Operating Subsystem

---

## 1. Executive Summary & Mandatory Constraints

The **PS06 AES-128 AXI-MM Hardware Accelerator** is designed to satisfy the strict VELTRAXX '26 August 28 Final Challenge Specifications:

1. **NIST Compliance**: Full standard AES-128 encryption and decryption with SubBytes, ShiftRows, MixColumns, AddRoundKey, and corresponding inverse transformations.
2. **Full AXI4-MM System Interface**: Full AXI4 Memory-Mapped slave with burst transfer support (`INCR`/`FIXED`), transaction ID reflection, and `wlast`/`rlast` management for seamless high-performance SoC integration.
3. **Hardened Security**: Complete isolation of internal intermediate states and dynamic round keys from bus read access.
4. **On-the-Fly Round-Key Generation**: Round keys dynamically produced during execution. Pre-computed BRAM round-key storage is **strictly prohibited**.
5. **LUT Usage**: Final synthesized design achieves **2,455 4-input LUTs** on AMD 7-Series FPGA (4.01% of XC7A100T device), with zero BRAM and zero DSP utilization.
6. **Throughput Target**: At least **1 complete 128-bit block every 10 clock cycles** ($II = 10$).
7. **6-Mode Operating Subsystem**: Support for ECB, CBC, CFB, OFB, CTR, and GCM (AEAD) operating modes per NIST SP 800-38A/38D.

---

## 2. System Architecture & Modular Hierarchy

```mermaid
flowchart TD
    %% Styling Classes
    classDef hostStyle fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef axiStyle fill:#1e1b4b,stroke:#818cf8,stroke-width:2px,color:#f8fafc;
    classDef regStyle fill:#1e3a5f,stroke:#60a5fa,stroke-width:2px,color:#f8fafc;
    classDef ctrlStyle fill:#064e3b,stroke:#34d399,stroke-width:2px,color:#f8fafc;
    classDef cryptoStyle fill:#831843,stroke:#fb7185,stroke-width:2px,color:#f8fafc;
    classDef keyStyle fill:#78350f,stroke:#fbbf24,stroke-width:2px,color:#f8fafc;
    classDef modeStyle fill:#3b0764,stroke:#a78bfa,stroke-width:2px,color:#f8fafc;
    classDef ghashStyle fill:#4a1d96,stroke:#c4b5fd,stroke-width:2px,color:#f8fafc;
    classDef demoStyle fill:#1e3a5f,stroke:#67e8f9,stroke-width:2px,color:#f8fafc;

    subgraph HOST_DOMAIN ["Host / Master Domain"]
        HOST["<b>Host / MicroBlaze / Bus Master</b>"]:::hostStyle
    end

    HOST == "Full AXI4 Bus<br/>[AW, W, B, AR, R channels &amp; Burst]" ==> TOP

    subgraph TOP ["aes_axi_top (src/top/aes_axi_top.v)"]
        
        subgraph INTERFACE_LAYER ["Full AXI4 Interface &amp; Register Domain (src/axi/)"]
            direction LR
            AXI_SLAVE["<b>axi_mm_slave.v</b><br/>• Full AXI4 Handshake Engine<br/>• Burst Support (INCR / FIXED)<br/>• Transaction ID Reflection (awid/arid)<br/>• wlast / rlast Management"]:::axiStyle
            REG_BANK[("<b>aes_registers.v</b><br/>• Secure Register Bank (32-bit words)<br/>• Control (0x00) &amp; Status (0x04)<br/>• Write-Only Key Regs (0x10-0x1C)<br/>• Block In (0x20-0x2C) &amp; Out (0x30-0x3C)<br/>• Anti-Leakage Gate (0 during BUSY)")]:::regStyle
            AXI_SLAVE <== "Internal Register Bus<br/>[addr, wdata, rdata, we]" ==> REG_BANK
        end

        subgraph CONTROL_LAYER ["Control &amp; FSM Scheduling (src/aes/)"]
            AES_CTRL["<b>aes_controller.v</b><br/>• Cycle-Accurate 10-Cycle FSM<br/>• Round Sequencing (r = 0..9)<br/>• SubBytes / MixColumns Muxing<br/>• Handshake Pulse Synchronization"]:::ctrlStyle
        end

        REG_BANK -- "Public Signals Only<br/>start, mode, key[127:0], block_in[127:0]" --> AES_CTRL
        AES_CTRL -. "busy, done" .-> REG_BANK

        subgraph CORE_LAYER ["Isolated Cryptographic Engine — aes_core (src/aes/aes_core.v)"]
            direction TB
            
            subgraph KEY_EXP_BLOCK ["On-The-Fly Key Expansion (src/aes/aes_key_expand.v)"]
                KEY_EXP["<b>aes_key_expand.v</b><br/>• Dynamic Round Key Generation (K0..K10)<br/>• 4 Shared SubWord S-Boxes<br/>• RotWord &amp; Rcon Generator<br/>• Zero BRAM Utilization"]:::keyStyle
            end

            subgraph DATAPATH_BLOCK ["Folded 10-Cycle Cryptographic Datapath"]
                DATAPATH["<b>AES Datapath Transformations</b><br/>• <b>SubBytes / InvSubBytes</b>: 16 Shared S-Boxes (aes_sbox_shared.v)<br/>• <b>ShiftRows / InvShiftRows</b>: Pure Wiring (0 LUTs)<br/>• <b>MixColumns / InvMixColumns</b>: Shared GF(2⁸) Multipliers<br/>• <b>AddRoundKey</b>: 128-bit XOR Matrix"]:::cryptoStyle
            end

            KEY_EXP <== "round_key[127:0]<br/>(Synchronized to Round)" ==> DATAPATH
        end

        AES_CTRL == "FSM Controls &amp; Timing<br/>[round, mux_sel, key_load]" ==> CORE_LAYER
        CORE_LAYER -. "block_out[127:0]<br/>(Latched at Cycle 9)" .-> REG_BANK
    end

    subgraph MODE_LAYER ["6-Mode Operating Subsystem (src/top/)"]
        direction LR
        MODE_ENG["<b>aes_mode_engine.v</b><br/>• ECB / CBC / CFB / OFB / CTR / GCM<br/>• IV/Nonce Management<br/>• Counter Increment (CTR/GCM)<br/>• Feedback Chain (CBC/CFB/OFB)"]:::modeStyle
        GHASH["<b>ghash_core.v</b><br/>• GF(2¹²⁸) Multiplier<br/>• NIST SP 800-38D Algorithm 1<br/>• Bit-Serial 128-Step Accumulator<br/>• &lt;150 LUTs, Zero DSP"]:::ghashStyle
        MODE_ENG <== "GCM Hash Path<br/>(AAD &amp; Ciphertext)" ==> GHASH
    end

    TOP <== "Core Request/Response<br/>(encrypt/decrypt blocks)" ==> MODE_LAYER

    subgraph DEMO_LAYER ["Nexys A7 Hardware Demo (src/top/nexys_a7_uart_top.v)"]
        UART_DEMO["<b>nexys_a7_uart_top.v</b><br/>• 115,200 Baud USB-UART Bridge<br/>• AXI4 Master Bridge FSM<br/>• 8-Digit 7-Segment Hex Display<br/>• LED Status &amp; Pushbutton Control<br/>• UART Commands: E/D/K/M/I/A/G/R/T"]:::demoStyle
    end

    MODE_LAYER <== "Mode-Wrapped AES Operations" ==> DEMO_LAYER

    style TOP fill:#0f172a,stroke:#94a3b8,stroke-width:2px,stroke-dasharray: 4 4,color:#f8fafc
    style CORE_LAYER fill:#2e1065,stroke:#c084fc,stroke-width:2px,color:#f8fafc
```

### Complete Module Inventory (`src/`)

#### `src/aes/` — Cryptographic Engine (18 modules)

| Module | File | Purpose |
|:-------|:-----|:--------|
| `aes_core` | `aes_core.v` | Central folded 10-cycle datapath housing all transforms and key expansion |
| `aes_controller` | `aes_controller.v` | Cycle-accurate FSM orchestrating the 10-cycle execution schedule |
| `aes_key_expand` | `aes_key_expand.v` | On-the-fly round key generation ($K_0 \dots K_{10}$) at runtime |
| `aes_key_expansion` | `aes_key_expansion.v` | Pure combinational key schedule (all 11 round keys simultaneously) |
| `aes_sbox` | `aes_sbox.v` | Forward S-Box wrapper |
| `aes_inv_sbox` | `aes_inv_sbox.v` | Inverse S-Box (256-byte distributed ROM) |
| `aes_sbox_shared` | `aes_sbox_shared.v` | Unified forward/inverse S-Box (512-byte distributed ROM with MuxF7/F8) |
| `aes_sbox_canright` | `aes_sbox_canright.v` | Canright composite-field S-Box (GF(2⁴) tower decomposition) |
| `aes_gf_inv` | `aes_gf_inv.v` | GF(2⁸) multiplicative inverse lookup (256-byte distributed ROM) |
| `aes_subbytes` | `aes_subbytes.v` | Forward SubBytes (16-byte parallel substitution) |
| `aes_inv_subbytes` | `aes_inv_subbytes.v` | Inverse SubBytes |
| `aes_subbytes_shared` | `aes_subbytes_shared.v` | Shared forward/inverse SubBytes (muxed enc/dec) |
| `aes_shiftrows` | `aes_shiftrows.v` | Forward ShiftRows (pure combinational wiring, 0 LUTs) |
| `aes_inv_shiftrows` | `aes_inv_shiftrows.v` | Inverse ShiftRows |
| `aes_mixcolumns` | `aes_mixcolumns.v` | Forward MixColumns (GF(2⁸) matrix multiplication) |
| `aes_inv_mixcolumns` | `aes_inv_mixcolumns.v` | Inverse MixColumns |
| `aes_mixcolumns_shared` | `aes_mixcolumns_shared.v` | Shared forward/inverse MixColumns |
| `aes_addroundkey` | `aes_addroundkey.v` | AddRoundKey (128-bit XOR matrix) |

#### `src/axi/` — AXI4 Interface (2 modules)

| Module | File | Purpose |
|:-------|:-----|:--------|
| `axi_mm_slave` | `axi_mm_slave.v` | Full AXI4 memory-mapped handshake engine (AW, W, B, AR, R with burst) |
| `aes_registers` | `aes_registers.v` | Secure register bank with anti-leakage gating |

#### `src/top/` — Top-Level Wrappers & Mode Engine (4 modules)

| Module | File | Purpose |
|:-------|:-----|:--------|
| `aes_axi_top` | `aes_axi_top.v` | System top-level integrating AXI slave, registers, and AES core |
| `aes_mode_engine` | `aes_mode_engine.v` | 6-mode operating subsystem (ECB/CBC/CFB/OFB/CTR/GCM) |
| `ghash_core` | `ghash_core.v` | GHASH GF(2¹²⁸) multiplier for GCM authentication tags |
| `nexys_a7_uart_top` | `nexys_a7_uart_top.v` | Nexys A7 interactive FPGA demo with USB-UART and 7-segment display |

---

## 3. Dynamic Pipeline Folding & Resource-Sharing Strategy

To maximize resource efficiency while delivering **$\ge 1$ block per 10 cycles** at 100 MHz:

### Design Choices:
1. **Iterative Round Engine**:
   - Instead of unrolling 10 rounds (which requires 160 S-boxes and >10,000 LUTs), a single round engine executes iteratively across 10 clock cycles.
2. **S-Box Resource Sharing**:
   - Forward encryption and inverse decryption share a unified 512-byte distributed ROM (`aes_sbox_shared.v`) addressed by `{is_inv, byte_in}`.
   - Alternative implementations available: Canright composite-field (`aes_sbox_canright.v`) and GF(2⁸) inverse ROM (`aes_gf_inv.v`).
   - Key expansion utilizes 4 S-boxes while the main round uses 16 parallel S-boxes (~500-600 LUTs for 20 S-boxes).
3. **Pure Logic Transformations**:
   - `ShiftRows`: Pure combinational rewiring ($0$ LUTs).
   - `AddRoundKey`: Pure 128-bit XOR ($128$ LUTs).
   - `MixColumns`: Shared $GF(2^8)$ constant multiplier trees ($2 \cdot x$, $3 \cdot x$, $9 \cdot x$, $11 \cdot x$, $13 \cdot x$, $14 \cdot x$) with shared XOR chains.
4. **Zero BRAM Overhead**:
   - On-the-fly round key generation synthesizes purely into distributed registers/LUTs, eliminating BRAM entirely.

---

## 4. 10-Cycle Datapath & Timing Schedule

To achieve an Initiation Interval of 10 cycles ($II = 10$):

| Cycle | Operation | Round Key Applied | State Action | Key Expand Action |
|:-----:|:----------|:-----------------:|:-------------|:------------------|
| **0** | Init / Round 1 | $K_0$, $K_1$ | AddRoundKey($K_0$) $\rightarrow$ SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_1$) | $K_0 \rightarrow K_1$ |
| **1** | Round 2 | $K_2$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_2$) | $K_1 \rightarrow K_2$ |
| **2** | Round 3 | $K_3$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_3$) | $K_2 \rightarrow K_3$ |
| **3** | Round 4 | $K_4$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_4$) | $K_3 \rightarrow K_4$ |
| **4** | Round 5 | $K_5$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_5$) | $K_4 \rightarrow K_5$ |
| **5** | Round 6 | $K_6$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_6$) | $K_5 \rightarrow K_6$ |
| **6** | Round 7 | $K_7$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_7$) | $K_6 \rightarrow K_7$ |
| **7** | Round 8 | $K_8$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_8$) | $K_7 \rightarrow K_8$ |
| **8** | Round 9 | $K_9$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ MixColumns $\rightarrow$ AddRoundKey($K_9$) | $K_8 \rightarrow K_9$ |
| **9** | Round 10 (Final) | $K_{10}$ | SubBytes $\rightarrow$ ShiftRows $\rightarrow$ **No MixColumns** $\rightarrow$ AddRoundKey($K_{10}$) | $K_9 \rightarrow K_{10}$, Latch Result, Assert `DONE` |

- **Initiation Interval ($II$)**: 10 clock cycles.
- **Latency**: 10 clock cycles from `START` to `DONE`.
- **Sustained Throughput**: At 100 MHz clock frequency:
  $$\text{Throughput} = \frac{128 \text{ bits}}{10 \times 10 \text{ ns}} = 1.28 \text{ Gbps}$$

---

## 5. 6-Mode Operating Subsystem

The `aes_mode_engine.v` module wraps the AES core to provide all 6 NIST-standard operating modes:

| Mode | Code | Standard | Description | IV Required |
|:-----|:----:|:---------|:------------|:-----------:|
| **ECB** | 0 | NIST SP 800-38A | Electronic Codebook (direct block cipher) | No |
| **CBC** | 1 | NIST SP 800-38A | Cipher Block Chaining (feedback XOR) | Yes |
| **CFB** | 2 | NIST SP 800-38A | Cipher Feedback (streaming) | Yes |
| **OFB** | 3 | NIST SP 800-38A | Output Feedback (keystream generator) | Yes |
| **CTR** | 4 | NIST SP 800-38A | Counter Mode (parallelizable) | Yes (Nonce) |
| **GCM** | 5 | NIST SP 800-38D | Galois/Counter Mode AEAD (authenticated) | Yes (Nonce) |

### GCM AEAD Features:
- **GHASH Core** (`ghash_core.v`): Bit-serial 128-step GF(2¹²⁸) multiplier implementing NIST SP 800-38D Algorithm 1.
- **Reduction Polynomial**: $P(x) = x^{128} + x^7 + x^2 + x + 1$ ($R = \texttt{0xE1000...0}$).
- **Resource Cost**: < 150 LUTs, zero DSP blocks.
- **AAD Support**: Processes Additional Authenticated Data blocks before ciphertext.
- **Tag Generation**: Produces 128-bit authentication tag $T$ for integrity verification.

---

## 6. Standard 128-bit State Bit-Slice Mapping

FIPS-197 column-major matrix mapped strictly across all modules:

| Byte Index | Matrix Position | Verilog Slice `state[...]` | Column / Word |
|:----------:|:---------------:|:--------------------------:|:-------------:|
| $s_0$      | Row 0, Col 0    | `[127:120]`                | Word 0 (Col 0) `[127:96]` |
| $s_1$      | Row 1, Col 0    | `[119:112]`                | Word 0 (Col 0) `[127:96]` |
| $s_2$      | Row 2, Col 0    | `[111:104]`                | Word 0 (Col 0) `[127:96]` |
| $s_3$      | Row 3, Col 0    | `[103:96]`                 | Word 0 (Col 0) `[127:96]` |
| $s_4 \dots s_7$   | Col 1    | `[95:64]`                  | Word 1 (Col 1) `[95:64]`  |
| $s_8 \dots s_{11}$  | Col 2  | `[63:32]`                  | Word 2 (Col 2) `[63:32]`  |
| $s_{12} \dots s_{15}$ | Col 3| `[31:0]`                   | Word 3 (Col 3) `[31:0]`   |
