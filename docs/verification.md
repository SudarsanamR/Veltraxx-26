# PS06 Verification Strategy & Test Plan

---

## 1. Hierarchical Verification Levels

Verification proceeds strictly bottom-up to guarantee module-level isolation:

```
[Level 1]  Atomic S-box & Inverses
           └── tb_aes_subbytes.v (SubBytes forward/inverse byte substitution)
               |
[Level 2]  Transformation Primitives (SubBytes, ShiftRows, MixColumns, AddRoundKey)
           ├── tb_aes_shiftrows.v
           ├── tb_aes_mixcolumns.v
           ├── tb_aes_addroundkey.v
           └── tb_aes_primitives.v (combined multi-transform test)
               |
[Level 3]  Dynamic Key Expansion (On-the-fly round key schedule)
           └── tb_aes_key_expand.v
               |
[Level 4]  AES Core 10-Cycle Datapath & FSM
           └── tb_aes_core.v
               |
[Level 5]  Full AXI4 Slave Handshake & Secure Register Bank
           └── tb_axi_mm_slave.v
               |
[Level 6]  Full System Top-Level Integration
           └── tb_aes_axi_top.v
               |
[Level 7]  Security Verification: No bus leakage of intermediate states/keys
           └── (integrated into tb_aes_axi_top.v test suites)
               |
[Level 8]  NIST FIPS-197 Known-Answer Test (KAT) Regression (284 CAVP Vectors)
           ├── tb_nist_kat_runner.v
           └── verify_nist_kat.py
               |
[Level 9]  6-Mode Operating Subsystem & GCM AEAD
           └── tb_nexys_a7_mode_top.v (ECB/CBC/CFB/OFB/CTR/GCM functional tests)
               |
[Level 10] Nexys A7 Hardware Demo (UART integration & board-level simulation)
           └── tb_nexys_a7_uart_top.v
```

---

## 2. Complete Testbench Inventory

| Testbench File | Target Module(s) | Scope | Vectors |
|:---------------|:-----------------|:------|:--------|
| `tb/tb_aes_subbytes.v` | `aes_subbytes`, `aes_inv_subbytes` | Forward & inverse byte substitution arrays | NIST S-box |
| `tb/tb_aes_shiftrows.v` | `aes_shiftrows`, `aes_inv_shiftrows` | Row shift permutation correctness | Known patterns |
| `tb/tb_aes_mixcolumns.v` | `aes_mixcolumns`, `aes_inv_mixcolumns` | GF(2⁸) column mixing verification | NIST vectors |
| `tb/tb_aes_addroundkey.v` | `aes_addroundkey` | 128-bit XOR round key addition | Known patterns |
| `tb/tb_aes_primitives.v` | SubBytes, ShiftRows, MixColumns, AddRoundKey | Combined AES transformation layers & inverses | Multi-vector |
| `tb/tb_aes_key_expand.v` | `aes_key_expand` | Dynamic on-the-fly round-key schedule | FIPS 197 A.1 |
| `tb/tb_aes_core.v` | `aes_core`, `aes_controller` | 10-cycle datapath & NIST KAT vectors | FIPS 197 C.1 |
| `tb/tb_axi_mm_slave.v` | `axi_mm_slave`, `aes_registers` | Full AXI4 bursts, handshakes & security | 7 test cases |
| `tb/tb_aes_axi_top.v` | `aes_axi_top` | End-to-end system, throughput & security | 9 test suites |
| `tb/tb_nist_kat_runner.v` | `aes_core` | Full NIST CAVP 284-vector regression suite | 284 KAT vectors |
| `tb/verify_nist_kat.py` | `aes_core` (via Icarus) | Python-driven NIST KAT verification | 284 vectors |
| `tb/tb_nexys_a7_mode_top.v` | `aes_mode_engine`, `nexys_a7_uart_top` | 6-mode engine simulation (ECB/CBC/CFB/OFB/CTR/GCM) | Mode-specific |
| `tb/tb_nexys_a7_uart_top.v` | `nexys_a7_uart_top` | Nexys A7 UART demo integration (serial commands) | UART protocol |

---

## 3. NIST Test Vectors & CAVP Suites

Standard KAT Baseline:
- **Plaintext**: `00112233445566778899aabbccddeeff`
- **Key**: `000102030405060708090a0b0c0d0e0f`
- **Expected Ciphertext**: `69c4e0d86a7b0430d8cdb78070b4c55a`

Extended NIST CAVP Vectors (located in project root `TestVectors/`):
- `KAT_AES/`: Variable Key and Variable Plaintext Known Answer Tests
- `aesmct/`: Monte Carlo 1,000-iteration multi-block tests
- `aesmmt/`: Multiblock message test vectors
- `aesmct_intermediate/`: Intermediate state Monte Carlo reference data

---

## 4. 10-Cycle Throughput Verification

Testbenches must log clock cycles from `START` to `DONE` and prove:
- Latency = 10 clock cycles.
- Continuous back-to-back blocks maintain Initiation Interval $II = 10$.
- Waveform artifacts demonstrating cycle timing will be dumped to `outputs/`.

---

## 5. Security Anti-Leakage Verification

Self-checking security test in `tb_aes_axi_top.v`:
1. Start encryption with secret key and known plaintext.
2. During each clock cycle ($1 \dots 9$), execute AXI read cycles on all readable addresses.
3. Assert that `s_axi_rdata` never matches:
   - Current intermediate state matrix
   - Current round key $K_r$
   - Internal key expansion registers
4. Assert that unmapped address reads return `32'h0000_0000`.

---

## 6. 6-Mode Operating Subsystem Verification

The `tb_nexys_a7_mode_top.v` testbench validates all cipher operating modes:

| Mode | Test Coverage |
|:-----|:-------------|
| **ECB** | Direct block encrypt/decrypt matches NIST vectors |
| **CBC** | IV-chained multi-block encrypt/decrypt with feedback verification |
| **CFB** | Cipher feedback streaming with IV initialization |
| **OFB** | Output feedback keystream generation and XOR |
| **CTR** | Counter-mode encryption with nonce and incrementing counter |
| **GCM** | Authenticated encryption with AAD, ciphertext authentication, and 128-bit tag generation/verification |

---

## 7. Build & Simulation Commands

```bash
# Level 1-4: Unit-level simulation (Icarus Verilog)
iverilog -g2012 -o sim_core.out src/aes/*.v tb/tb_aes_core.v && vvp sim_core.out

# Level 5-7: Full system simulation with AXI and security
iverilog -g2012 -o sim_top.out src/aes/*.v src/axi/*.v src/top/*.v tb/tb_aes_axi_top.v && vvp sim_top.out

# Level 8: NIST CAVP regression (284 vectors)
python3 tb/verify_nist_kat.py

# Level 9-10: Nexys A7 demo simulation
iverilog -g2012 -o sim_nexys.out src/aes/*.v src/axi/*.v src/top/*.v tb/tb_nexys_a7_uart_top.v && vvp sim_nexys.out
```
