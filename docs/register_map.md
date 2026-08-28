# PS06 AXI-MM Register Map Specification
## Memory-Mapped Interface for AES-128 Hardware Accelerator

---

## 1. Interface Protocol & Security Principles

- **Protocol**: Full AXI4 Memory-Mapped Slave (32-bit data bus, 32-bit address space, with support for single-beat and multi-beat bursts).
- **Channels**: 5 standard AXI4 channels (AW, W, B, AR, R) with Transaction ID reflection (`awid` $\to$ `bid`, `arid` $\to$ `rid`).
- **Burst Modes**: Supports `INCR` (2'b01) and `FIXED` (2'b00) burst transfers up to 256 beats. Standard 4-beat burst transfers (`len = 3`, `INCR`) allow streaming 128-bit Keys, Plaintext, and Ciphertext in a single transaction.
- **Word Alignment**: Register offsets are 4-byte aligned (`ADDR[1:0] == 2'b00`).
- **Security Hardening**:
  - **No Leakage of Secrets**: Intermediate round states and dynamic round keys ($K_1 \dots K_{10}$) have no address mapping and cannot be read across the bus.
  - **Write-Only Key Protection**: The 128-bit key is configured as write-only (`KEY_0..3` reads strictly return `32'h0000_0000`) to prevent readback by co-resident software.
  - **Gated Result Availability**: Result registers (`BLOCK_OUT_0..3`) latch valid data only when the cryptographic operation has finished (`DONE == 1`). While `BUSY == 1`, reads strictly return `32'h0000_0000`.
  - **Mode Engine Isolation**: Internal IV/counter/feedback/GHASH state in the 6-mode operating subsystem has no register mapping.

---

## 2. Address Map

| Offset | Register Name | Access | Reset Value | Security / Functional Description |
|:------:|:-------------:|:------:|:-----------:|:----------------------------------|
| `0x00` | `CONTROL`     | R/W    | `0x0000_0000` | Bit 0: `START` (self-clearing), Bit 1: `MODE` (0=Enc, 1=Dec), Bit 2: `CORE_RESET` |
| `0x04` | `STATUS`      | RO     | `0x0000_0004` | Bit 0: `BUSY`, Bit 1: `DONE`, Bit 2: `READY` (No state leakage) |
| `0x08` | `CONFIG`      | R/W    | `0x0000_0000` | Bits [2:0]: Mode select (0:ECB, 1:CBC, 2:CFB, 3:OFB, 4:CTR, 5:GCM). Reserved bits for future enhancements. |
| `0x0C` | `RESERVED`    | RO     | `0x0000_0000` | Returns `0x0000_0000` |
| `0x10` | `KEY_0`       | WO/RW  | `0x0000_0000` | 128-bit Cipher Key Word 0 (`[127:96]`) |
| `0x14` | `KEY_1`       | WO/RW  | `0x0000_0000` | 128-bit Cipher Key Word 1 (`[95:64]`) |
| `0x18` | `KEY_2`       | WO/RW  | `0x0000_0000` | 128-bit Cipher Key Word 2 (`[63:32]`) |
| `0x1C` | `KEY_3`       | WO/RW  | `0x0000_0000` | 128-bit Cipher Key Word 3 (`[31:0]`) |
| `0x20` | `BLOCK_IN_0`  | R/W    | `0x0000_0000` | Input Block Word 0 (`[127:96]`) |
| `0x24` | `BLOCK_IN_1`  | R/W    | `0x0000_0000` | Input Block Word 1 (`[95:64]`) |
| `0x28` | `BLOCK_IN_2`  | R/W    | `0x0000_0000` | Input Block Word 2 (`[63:32]`) |
| `0x2C` | `BLOCK_IN_3`  | R/W    | `0x0000_0000` | Input Block Word 3 (`[31:0]`) |
| `0x30` | `BLOCK_OUT_0` | RO     | `0x0000_0000` | Output Result Word 0 (`[127:96]`) — Valid only when `DONE=1` |
| `0x34` | `BLOCK_OUT_1` | RO     | `0x0000_0000` | Output Result Word 1 (`[95:64]`) — Valid only when `DONE=1` |
| `0x38` | `BLOCK_OUT_2` | RO     | `0x0000_0000` | Output Result Word 2 (`[63:32]`) — Valid only when `DONE=1` |
| `0x3C` | `BLOCK_OUT_3` | RO     | `0x0000_0000` | Output Result Word 3 (`[31:0]`) — Valid only when `DONE=1` |
| `>0x3C`| `UNMAPPED`    | RO     | `0x0000_0000` | Returns `32'h0000_0000` (prevents probing attacks) |

---

## 3. Register Bitfield Definitions

### 3.1 CONTROL Register (`0x00`)
- `Bit 0` (`START`): Write `1` to initiate processing. Automatically cleared in hardware upon cycle 0 execution.
- `Bit 1` (`MODE`): `0` = Encryption, `1` = Decryption.
- `Bit 2` (`RESET_CORE`): Soft reset for AES FSM to recover from aborted operations without clearing configured keys.
- `Bits 31:3`: Reserved (read as 0).

### 3.2 STATUS Register (`0x04`)
- `Bit 0` (`BUSY`): Asserted `1` while 10-cycle transformation is executing.
- `Bit 1` (`DONE`): Asserted `1` when block transformation completes and output registers contain the result. Cleared on subsequent `START`.
- `Bit 2` (`READY`): Asserted `1` when core is idle and ready for the next block (`READY = ~BUSY`).
- `Bits 31:3`: Reserved (read as 0).

### 3.3 CONFIG Register (`0x08`)
- `Bits 2:0` (`MODE_SEL`): Operating mode selector for the 6-mode engine:
  - `3'b000` = ECB (Electronic Codebook)
  - `3'b001` = CBC (Cipher Block Chaining)
  - `3'b010` = CFB (Cipher Feedback)
  - `3'b011` = OFB (Output Feedback)
  - `3'b100` = CTR (Counter Mode)
  - `3'b101` = GCM (Galois/Counter Mode AEAD)
- `Bits 31:3`: Reserved for future enhancements (read as 0).

---

## 4. 128-Bit Word Alignment & Standard Hex Mapping

The 128-bit vector is assembled from the 4 32-bit registers in standard big-endian order:

$$\text{Data}[127:0] = \{\text{WORD\_0}[31:0], \text{WORD\_1}[31:0], \text{WORD\_2}[31:0], \text{WORD\_3}[31:0]\}$$

- Input string `00112233445566778899aabbccddeeff`:
  - `BLOCK_IN_0` (`0x20`): `0x00112233`
  - `BLOCK_IN_1` (`0x24`): `0x44556677`
  - `BLOCK_IN_2` (`0x28`): `0x8899aabb`
  - `BLOCK_IN_3` (`0x2C`): `0xccddeeff`

---

## 5. UART Command Protocol (Nexys A7 Hardware Demo)

The `nexys_a7_uart_top.v` module exposes an interactive UART command interface at 115,200 Baud:

| Command | Format | Description |
|:-------:|:-------|:------------|
| `M` | `M` + `<0..5>` + `\n` | Set active cipher mode (0:ECB, 1:CBC, 2:CFB, 3:OFB, 4:CTR, 5:GCM) |
| `I` | `I` + `<32-hex IV>` + `\n` | Load 128-bit IV / Nonce |
| `A` | `A` + `<32-hex AAD>` + `\n` | Load and hash 128-bit AAD block (GCM only) |
| `K` | `K` + `<32-hex Key>` + `\n` | Load 128-bit encryption/decryption key |
| `E` | `E` + `<32-hex PT>` + `\n` | Encrypt 128-bit plaintext block in active mode |
| `D` | `D` + `<32-hex CT>` + `\n` | Decrypt 128-bit ciphertext block in active mode |
| `G` | `G` + `\n` | Request 128-bit GCM Authentication Tag T |
| `R` | `R` + `\n` | Reset IV, feedback, and counter state |
| `T` | `T` + `\n` | Run NIST Appendix C.1 hardware self-test |
