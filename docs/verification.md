# PS06 Verification Strategy & Test Plan (August 28 Final Release)

---

## 1. Hierarchical Verification Levels

Verification proceeds strictly bottom-up to guarantee module-level isolation:

```
[Level 1] Atomic S-box & Inverses (tb_aes_sbox.v)
    |
[Level 2] Transformation Primitives (SubBytes, ShiftRows, MixColumns, AddRoundKey) (tb_aes_primitives.v)
    |
[Level 3] Dynamic Key Expansion (On-the-fly round key schedule) (tb_aes_key_expand.v)
    |
[Level 4] AES Core 10-Cycle Datapath & FSM (tb_aes_core.v)
    |
[Level 5] AXI4-Lite Slave Handshake & Secure Register Bank (tb_axi_mm_slave.v)
    |
[Level 6] Full System Top-Level Integration (tb_aes_axi_top.v)
    |
[Level 7] Security Verification: No bus leakage of intermediate states/keys
    |
[Level 8] NIST FIPS-197 Known-Answer Test (KAT) Regression (NIST CAVP Vectors)
```

---

## 2. NIST Test Vectors & CAVP Suites

Standard KAT Baseline:
- **Plaintext**: `00112233445566778899aabbccddeeff`
- **Key**: `000102030405060708090a0b0c0d0e0f`
- **Expected Ciphertext**: `69c4e0d86a7b0430d8cdb78070b4c55a`

Extended NIST CAVP Vectors (located in project root `TestVectors/`):
- `KAT_AES/`: Variable Key and Variable Plaintext Known Answer Tests
- `aesmct/`: Monte Carlo 1,000-iteration multi-block tests
- `aesmmt/`: Multiblock message test vectors

---

## 3. 10-Cycle Throughput Verification

Testbenches must log clock cycles from `START` to `DONE` and prove:
- Latency = 10 clock cycles.
- Continuous back-to-back blocks maintain Initiation Interval $II = 10$.
- Waveform artifacts demonstrating cycle timing will be dumped to `outputs/`.

---

## 4. Security Anti-Leakage Verification

Self-checking security test in `tb_aes_axi_top.v`:
1. Start encryption with secret key and known plaintext.
2. During each clock cycle ($1 \dots 9$), execute AXI read cycles on all readable addresses.
3. Assert that `s_axi_rdata` never matches:
   - Current intermediate state matrix
   - Current round key $K_r$
   - Internal key expansion registers
4. Assert that unmapped address reads return `32'h0000_0000`.
