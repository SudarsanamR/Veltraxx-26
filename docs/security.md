# PS06 AXI-MM Interface Security & Anti-Leakage Specification

---

## 1. Threat Model & Security Objectives

In an SoC environment where the AES-128 core is attached to an AXI Memory-Mapped (AXI-MM) interconnect, untrusted or lower-privilege masters sharing the bus must be prevented from extracting cryptographic keys or intermediate cipher states.

### Mandatory Security Directives:
1. **Zero Intermediate State Exposure**:
   - The 128-bit internal state undergoing transformation rounds ($0 \dots 10$) must NEVER be routed to or readable via any AXI-MM address offset.
2. **Zero Dynamic Round-Key Exposure**:
   - Round keys generated on-the-fly ($K_1 \dots K_{10}$) and the key expansion internal registers must NEVER be mapped to the bus.
   - Large pre-computed BRAM key tables are strictly prohibited by problem rules, preventing memory dumping attacks.
3. **No "Debug" Read Backdoor**:
   - No diagnostic, test, or debug registers providing visibility into intermediate rounds are implemented in synthesizable RTL.
4. **Isolated Register Boundary**:
   - Only architecturally required registers exist: Control (write-only trigger / mode), Status (busy/done flags), Key Words (write-only), Input Words (read/write), and Output Words (read-only after done).
   - Reading `KEY_*` registers can optionally return `0x0000_0000` (write-only security) or latch only the user's initially supplied key without exposing internal expansion states.
   - Reading `BLOCK_OUT_*` returns valid data **only** when `DONE == 1`. During execution (`BUSY == 1`), `BLOCK_OUT_*` reads return zeroes or latched previous results, never transient round states.
5. **Unmapped Address Protection**:
   - Any read access to unmapped address space (e.g., offsets $> 0x3C$ or reserved gaps) returns `0x0000_0000` with `RRESP = 2'b00` (or `2'b10` SLVERR if strict protocol error response is configured), preventing address-probing side channels.

---

## 2. Cryptographic Isolation Boundary

```
          +----------------------------------------------------+
          |                 AXI-MM Public Domain               |
          |  (Bus Masters: MicroBlaze, Host, DMA, Peripheral)   |
          +-------------------------+--------------------------+
                                    |
                    AXI4-Lite Bus (AW, W, B, AR, R)
                                    |
          +-------------------------v--------------------------+
          |             axi_mm_slave & aes_registers           |
          |                                                    |
          |  [Public Registers]                                |
          |   - 0x00: CONTROL (Start, Mode)                    |
          |   - 0x04: STATUS (Busy, Done, Ready)               |
          |   - 0x10-0x1C: KEY_IN[3:0] (Write-only to engine)  |
          |   - 0x20-0x2C: BLOCK_IN[3:0] (Input Block)         |
          |   - 0x30-0x3C: BLOCK_OUT[3:0] (Result only on DONE)|
          +-------------------------+--------------------------+
                                    |
                             ISOLATION BARRIER
                    (No internal signals cross upward)
                                    |
          +-------------------------v--------------------------+
          |               aes_core (Private Enclave)           |
          |                                                    |
          |  - On-the-fly Key Generator (K0..K10)              |
          |  - Dynamic Folded State Registers                  |
          |  - SubBytes / ShiftRows / MixColumns / AddRoundKey |
          |  - Intermediate Round States (R0..R10)             |
          |                                                    |
          |  * COMPLETELY INACCESSIBLE FROM AXI INTERCONNECT *  |
          +----------------------------------------------------+
```

---

## 3. Waveform & Security Verification Checklist

To prove compliance to event judges:
- [ ] **Testcase 1**: Trigger encryption/decryption and issue continuous AXI read transactions across all address offsets (`0x00` through `0xFF`) while the core is `BUSY`. Verify that no intermediate cipher states appear on `s_axi_rdata`.
- [ ] **Testcase 2**: Attempt to read key generation internals. Verify that dynamically generated round keys ($K_1 \dots K_{10}$) never appear on `s_axi_rdata`.
- [ ] **Testcase 3**: Verify that `BLOCK_OUT` registers do not change dynamically during intermediate rounds and only latch the final result when `DONE` is asserted.
- [ ] **Testcase 4**: Capture and archive Vivado waveform screenshots in `outputs/` demonstrating that intermediate cryptographic states remain strictly internal.
