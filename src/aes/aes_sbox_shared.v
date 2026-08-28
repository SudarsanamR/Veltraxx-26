`timescale 1ns / 1ps
//==============================================================================
// AES Shared Forward / Inverse S-box Module
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Dual-mode S-box combining forward S-box (S) and inverse S-box (S^-1).
// Allows the 16 state S-box units to be shared 100% between Encryption
// and Decryption, cutting S-box area in half to meet the <1,500 LUT budget.
//
// Interface:
//   is_inv   — 0 for Forward S-box (Encrypt), 1 for Inverse S-box (Decrypt)
//   byte_in  — 8-bit input
//   byte_out — 8-bit substituted output (combinational)
//==============================================================================

module aes_sbox_shared (
    input  wire       is_inv,
    input  wire [7:0] byte_in,
    output wire [7:0] byte_out
);

    wire [7:0] fwd_out;
    wire [7:0] inv_out;

    aes_sbox fwd_inst (.byte_in(byte_in), .byte_out(fwd_out));
    aes_inv_sbox inv_inst (.byte_in(byte_in), .byte_out(inv_out));

    assign byte_out = is_inv ? inv_out : fwd_out;

endmodule
