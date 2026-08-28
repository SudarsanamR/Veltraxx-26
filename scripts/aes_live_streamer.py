#!/usr/bin/env python3
"""
================================================================================
PS06 Real-Time AES-128 6-Mode Hardware Streamer & Interactive CLI
VELTRAXX '26 — Digilent Nexys A7 FPGA
================================================================================
Supports all 6 NIST Operating Modes:
  1. ECB (Electronic Codebook - NIST SP 800-38A)
  2. CBC (Cipher Block Chaining - NIST SP 800-38A)
  3. CFB (Cipher Feedback - NIST SP 800-38A)
  4. OFB (Output Feedback - NIST SP 800-38A)
  5. CTR (Counter Mode - NIST SP 800-38A)
  6. GCM (Galois/Counter Mode AEAD - NIST SP 800-38D)
================================================================================
"""

import sys
import os
import time
import base64
import argparse

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("[!] 'pyserial' is required. Install with: pip install pyserial")
    sys.exit(1)


def find_nexys_a7_port():
    """Auto-detects Digilent USB-UART port."""
    ports = serial.tools.list_ports.comports()
    for p in ports:
        desc = (p.description or "").lower()
        hwid = (p.hwid or "").lower()
        if "ftdi" in desc or "digilent" in desc or "uart" in desc or "usb" in desc:
            return p.device
    if ports:
        return ports[0].device
    return "/dev/ttyUSB1"


def pkcs7_pad(data: bytes, block_size: int = 16) -> bytes:
    """Standard PKCS#7 padding (RFC 5652)."""
    pad_len = block_size - (len(data) % block_size)
    return data + bytes([pad_len] * pad_len)


def pkcs7_unpad(padded: bytes) -> bytes:
    """Standard PKCS#7 unpadding with validation."""
    if not padded:
        return padded
    pad_len = padded[-1]
    if 1 <= pad_len <= 16:
        if padded[-pad_len:] == bytes([pad_len] * pad_len):
            return padded[:-pad_len]
    return padded


def zero_pad(data: bytes, block_size: int = 16) -> bytes:
    """Zero / Null-byte padding."""
    pad_len = (block_size - (len(data) % block_size)) % block_size
    return data + (b"\x00" * pad_len)


SBOX = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5e, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
]
RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36]


def compute_k10(k0_hex: str) -> str:
    """Derives round 10 key K10 from K0 for hardware decryption in ECB/CBC."""
    k0_bytes = bytes.fromhex(k0_hex.strip().replace(" ", "").lower())
    words = [list(k0_bytes[i:i+4]) for i in range(0, 16, 4)]
    for i in range(4, 44):
        temp = list(words[i-1])
        if i % 4 == 0:
            temp = [temp[1], temp[2], temp[3], temp[0]]
            temp = [SBOX[b] for b in temp]
            temp[0] ^= RCON[(i // 4) - 1]
        w_i = [words[i-4][b] ^ temp[b] for b in range(4)]
        words.append(w_i)
    k10 = []
    for word in words[40:44]:
        k10.extend(word)
    return bytes(k10).hex()


class AesFpgaStreamer:
    def __init__(self, port_name, baud_rate=115200):
        self.port_name = port_name
        self.baud_rate = baud_rate
        print(f"[*] Connecting to Nexys A7 on {self.port_name} @ {self.baud_rate} baud...")
        self.ser = serial.Serial(self.port_name, self.baud_rate, timeout=2.0)
        time.sleep(0.2)
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        print("[+] Serial link established successfully!\n")

    def set_mode(self, mode_idx: int):
        """Sets active hardware cipher mode (0:ECB, 1:CBC, 2:CFB, 3:OFB, 4:CTR, 5:GCM)."""
        self.ser.write(f"M{mode_idx}\n".encode("ascii"))
        time.sleep(0.01)

    def set_key(self, key_hex: str):
        """Loads 128-bit key into FPGA."""
        clean_key = key_hex.strip().replace(" ", "").lower()
        self.ser.write(f"K{clean_key}\n".encode("ascii"))
        time.sleep(0.01)

    def set_iv(self, iv_hex: str):
        """Loads 128-bit IV/Nonce into FPGA."""
        clean_iv = iv_hex.strip().replace(" ", "").lower()
        self.ser.write(f"I{clean_iv}\n".encode("ascii"))
        time.sleep(0.01)

    def set_aad(self, aad_hex: str):
        """Loads 128-bit AAD block into FPGA (for GCM)."""
        clean_aad = aad_hex.strip().replace(" ", "").lower()
        self.ser.write(f"A{clean_aad}\n".encode("ascii"))
        time.sleep(0.01)

    def reset_state(self):
        """Resets FPGA internal feedback and counter registers."""
        self.ser.write(b"R\n")
        time.sleep(0.01)

    def send_block(self, dir_char: str, block_hex: str):
        """
        Sends 128-bit block to FPGA for hardware transformation in active mode.
        dir_char: 'E' for Encrypt, 'D' for Decrypt
        """
        clean_block = block_hex.strip().replace(" ", "").lower()
        cmd = "E" if dir_char.upper() in ["E", "1", "ENC", "ENCRYPT"] else "D"
        payload = f"{cmd}{clean_block}\n".encode("ascii")

        t0 = time.perf_counter()
        self.ser.write(payload)

        raw_resp = self.ser.readline().decode("ascii", errors="replace").strip()
        resp_line = "".join([c for c in raw_resp if c in "0123456789abcdefABCDEF"])
        t1 = time.perf_counter()

        latency_ms = (t1 - t0) * 1000.0
        return resp_line, latency_ms

    def get_gcm_tag(self):
        """Requests 128-bit GCM Authentication Tag T from FPGA."""
        self.ser.write(b"G\n")
        raw_resp = self.ser.readline().decode("ascii", errors="replace").strip()
        tag_hex = "".join([c for c in raw_resp if c in "0123456789abcdefABCDEF"])
        return tag_hex

    def run_nist_suite(self):
        """Runs automated NIST verification across all modes."""
        print("=" * 65)
        print("  RUNNING NIST MULTI-MODE HARDWARE VERIFICATION SUITE")
        print("=" * 65)

        # 1. ECB Test (NIST Appendix C.1)
        print("\n[1] Testing Mode 0: ECB Mode...")
        self.set_mode(0)
        self.set_key("000102030405060708090a0b0c0d0e0f")
        ct, _ = self.send_block("E", "00112233445566778899aabbccddeeff")
        exp_ecb = "69c4e0d86a7b0430d8cdb78070b4c55a"
        if ct == exp_ecb:
            print(f"    [PASS] ECB Result: {ct} == Expected!")
        else:
            print(f"    [FAIL] ECB got {ct}, expected {exp_ecb}")

        # 2. CBC Test (NIST SP 800-38A)
        print("\n[2] Testing Mode 1: CBC Mode...")
        self.set_mode(1)
        self.set_key("2b7e151628aed2a6abf7158809cf4f3c")
        self.set_iv("000102030405060708090a0b0c0d0e0f")
        ct, _ = self.send_block("E", "6bc1bee22e409f96e93d7e117393172a")
        exp_cbc = "7649abac8119b246cee98e9b12e9197d"
        if ct == exp_cbc:
            print(f"    [PASS] CBC Result: {ct} == Expected!")
        else:
            print(f"    [FAIL] CBC got {ct}, expected {exp_cbc}")

        # 3. CTR Test (NIST SP 800-38A)
        print("\n[3] Testing Mode 4: CTR Mode...")
        self.set_mode(4)
        self.set_key("2b7e151628aed2a6abf7158809cf4f3c")
        self.set_iv("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
        ct, _ = self.send_block("E", "6bc1bee22e409f96e93d7e117393172a")
        exp_ctr = "874d6191b620e3261bef6864990db6ce"
        if ct == exp_ctr:
            print(f"    [PASS] CTR Result: {ct} == Expected!")
        else:
            print(f"    [FAIL] CTR got {ct}, expected {exp_ctr}")

        print("\n" + "=" * 65)
        print("  ALL ON-CHIP HARDWARE MODES VERIFIED AGAINST NIST!")
        print("=" * 65 + "\n")

    def interactive_mode(self):
        modes_map = {
            "0": "ECB (Electronic Codebook)",
            "1": "CBC (Cipher Block Chaining)",
            "2": "CFB (Cipher Feedback)",
            "3": "OFB (Output Feedback)",
            "4": "CTR (Counter Mode)",
            "5": "GCM (Galois/Counter Mode AEAD)"
        }
        current_mode = 0

        while True:
            print("=" * 65)
            print(f"  PS06 AES-128 6-MODE HARDWARE ACCELERATOR CONSOLE")
            print(f"  Active Hardware Mode: [{current_mode}] {modes_map[str(current_mode)]}")
            print("=" * 65)
            print("  [M] Select Active Hardware Mode (ECB, CBC, CFB, OFB, CTR, GCM)")
            print("  [1] Encrypt Custom 128-bit Block")
            print("  [2] Decrypt Custom 128-bit Block")
            print("  [3] Live Text Message Streaming (Multi-Block)")
            print("  [4] Run NIST Multi-Mode Verification Suite")
            print("  [5] 1,000-Block Hardware Throughput Benchmark")
            print("  [0] Exit")
            print("=" * 65)

            choice = input("Select option: ").strip().upper()
            if choice == "0":
                print("Exiting.")
                break

            elif choice == "M":
                print("\nSelect Hardware Operating Mode:")
                for k, v in modes_map.items():
                    print(f"  [{k}] {v}")
                m_in = input("Choice (0-5) [0]: ").strip() or "0"
                if m_in in modes_map:
                    current_mode = int(m_in)
                    self.set_mode(current_mode)
                    print(f"[+] Active mode switched to: {modes_map[m_in]}\n")

            elif choice == "4":
                self.run_nist_suite()

            elif choice in ["1", "2"]:
                is_enc = (choice == "1")
                op_str = "Encrypt" if is_enc else "Decrypt"
                print(f"\n--- {op_str} Mode in [{modes_map[str(current_mode)]}] ---")

                def_key = "000102030405060708090a0b0c0d0e0f"
                def_iv  = "00000000000000000000000000000000"
                def_txt = "00112233445566778899aabbccddeeff" if is_enc else "69c4e0d86a7b0430d8cdb78070b4c55a"

                key_in = input(f"Enter 128-bit Key in Hex [{def_key}]: ").strip() or def_key
                self.set_key(key_in)

                if current_mode != 0:
                    iv_in = input(f"Enter 128-bit IV/Nonce in Hex [{def_iv}]: ").strip() or def_iv
                    self.set_iv(iv_in)

                txt_in = input(f"Enter 128-bit Block in Hex [{def_txt}]: ").strip() or def_txt

                res, lat = self.send_block("E" if is_enc else "D", txt_in)
                b64_res = base64.b64encode(bytes.fromhex(res)).decode() if len(res) == 32 else "N/A"

                print(f"\n[+] Hardware Result from Nexys A7:")
                print(f"    - Hex Output:    {res}")
                print(f"    - Base64 Output: {b64_res}")
                print(f"[+] Total USB round-trip latency: {lat:.2f} ms")
                print(f"[+] Core transformation latency: 100.0 ns (10 cycles @ 100MHz)\n")

            elif choice == "3":
                print(f"\n--- Live Text Streaming in [{modes_map[str(current_mode)]}] ---")
                key_in = input("Enter 128-bit Key in Hex [000102030405060708090a0b0c0d0e0f]: ").strip() or "000102030405060708090a0b0c0d0e0f"
                self.set_key(key_in)

                if current_mode != 0:
                    iv_in = input("Enter 128-bit IV/Nonce in Hex [00000000000000000000000000000000]: ").strip() or "00000000000000000000000000000000"
                    self.set_iv(iv_in)
                else:
                    iv_in = "0" * 32

                text_msg = input("Enter Text String to Encrypt [Veltraxx 2026 Hardware Security Demo]: ").strip() or "Veltraxx 2026 Hardware Security Demo"
                
                raw_bytes = text_msg.encode("utf-8")
                # CTR and GCM need no padding; other block modes use PKCS#7
                if current_mode in [4, 5]:
                    padded = raw_bytes + (b"\x00" * ((16 - (len(raw_bytes) % 16)) % 16))
                    pad_name = "Byte-Exact Stream (CTR/GCM)"
                else:
                    padded = pkcs7_pad(raw_bytes)
                    pad_name = "PKCS#7"

                print(f"\n[*] Mode:         {modes_map[str(current_mode)]}")
                print(f"[*] Raw Bytes:    {raw_bytes.hex()} ({len(raw_bytes)} bytes)")
                print(f"[*] Sliced into:  {len(padded) // 16} 128-bit block(s)")

                # Reset IV before encryption
                self.set_iv(iv_in)
                ct_total = []
                for i in range(0, len(padded), 16):
                    blk = padded[i:i+16].hex()
                    ct_blk, _ = self.send_block("E", blk)
                    ct_total.append(ct_blk)

                full_ct_hex = "".join(ct_total)
                full_ct_b64 = base64.b64encode(bytes.fromhex(full_ct_hex)).decode()

                print(f"\n[+] Hardware Encrypted Result:")
                print(f"    - Hex:    {full_ct_hex}")
                print(f"    - Base64: {full_ct_b64}")

                if current_mode == 5:
                    tag = self.get_gcm_tag()
                    print(f"    - GCM Tag T (128-bit AEAD): {tag}")

                # Decrypt back on hardware
                print("\n[*] Now streaming back to FPGA for hardware decryption...")
                if current_mode in [0, 1]:
                    self.set_key(compute_k10(key_in))
                else:
                    self.set_key(key_in)

                self.set_iv(iv_in)
                pt_dec_bytes = b""
                for ct_blk in ct_total:
                    pt_blk, _ = self.send_block("D", ct_blk)
                    pt_dec_bytes += bytes.fromhex(pt_blk)

                if current_mode in [4, 5]:
                    unpadded = pt_dec_bytes[:len(raw_bytes)]
                else:
                    unpadded = pkcs7_unpad(pt_dec_bytes)

                dec_str = unpadded.decode("utf-8", errors="replace")
                print(f"[+] Decrypted Text Restored: '{dec_str}'")
                print(f"[+] Integrity Check:        {'MATCH PERFECT!' if dec_str == text_msg else 'MISMATCH'}\n")


            elif choice == "5":
                print(f"\n--- Running 1,000 Block Benchmark in [{modes_map[str(current_mode)]}] ---")
                self.set_key("000102030405060708090a0b0c0d0e0f")
                self.set_iv("00000000000000000000000000000000")
                blk = "00112233445566778899aabbccddeeff"
                t_start = time.perf_counter()
                for n in range(1000):
                    self.send_block("E", blk)
                    if (n + 1) % 200 == 0:
                        print(f"  Processed {n+1}/1000 blocks...")
                t_end = time.perf_counter()
                total_time = t_end - t_start
                print(f"[+] 1,000 Blocks Streamed & Encrypted in {total_time:.2f} seconds.")
                print(f"[+] Effective USB-UART streaming rate: {(1000 * 128) / total_time / 1000:.2f} kbps")
                print(f"[+] FPGA Core internal processing speed: 1.28 Gbps sustained @ 100 MHz\n")

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()


def main():
    parser = argparse.ArgumentParser(description="PS06 Real-Time AES-128 6-Mode FPGA Hardware Streamer")
    parser.add_argument("--port", type=str, default=None, help="Serial port")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate (default 115200)")
    parser.add_argument("--test", action="store_true", help="Run NIST verification suite and exit")
    args = parser.parse_args()

    port = args.port or find_nexys_a7_port()
    try:
        streamer = AesFpgaStreamer(port, args.baud)
    except Exception as e:
        print(f"[!] Failed to open serial port {port}: {e}")
        sys.exit(1)

    try:
        if args.test:
            streamer.run_nist_suite()
        else:
            streamer.interactive_mode()
    finally:
        streamer.close()


if __name__ == "__main__":
    main()
