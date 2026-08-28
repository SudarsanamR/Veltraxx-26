`timescale 1ns / 1ps
//==============================================================================
// AES Inverse SubBytes Transformation
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Applies the AES Inverse S-box substitution to all 16 bytes of the 128-bit state.
// Instantiates 16 aes_inv_sbox modules — one per byte position.
//
// This is pure combinational logic — no clock, no state.
//
// State Format (column-major, 128 bits):
//   [127:120] = state[0][0]  (row 0, col 0)
//   [119:112] = state[1][0]  (row 1, col 0)
//   [111:104] = state[2][0]  (row 2, col 0)
//   [103:96]  = state[3][0]  (row 3, col 0)
//   [95:88]   = state[0][1]  (row 0, col 1)
//   ... and so on for all 16 bytes
//==============================================================================

module aes_inv_subbytes (
    input  wire [127:0] state_in,   // Input state (16 bytes)
    output wire [127:0] state_out   // Output state after Inverse S-box substitution
);

    //==========================================================================
    // Instantiate 16 Inverse S-box Modules — One per Byte
    //==========================================================================
    aes_inv_sbox inv_sbox_b0  (.byte_in(state_in[127:120]), .byte_out(state_out[127:120]));
    aes_inv_sbox inv_sbox_b1  (.byte_in(state_in[119:112]), .byte_out(state_out[119:112]));
    aes_inv_sbox inv_sbox_b2  (.byte_in(state_in[111:104]), .byte_out(state_out[111:104]));
    aes_inv_sbox inv_sbox_b3  (.byte_in(state_in[103:96]),  .byte_out(state_out[103:96]));
    aes_inv_sbox inv_sbox_b4  (.byte_in(state_in[95:88]),   .byte_out(state_out[95:88]));
    aes_inv_sbox inv_sbox_b5  (.byte_in(state_in[87:80]),   .byte_out(state_out[87:80]));
    aes_inv_sbox inv_sbox_b6  (.byte_in(state_in[79:72]),   .byte_out(state_out[79:72]));
    aes_inv_sbox inv_sbox_b7  (.byte_in(state_in[71:64]),   .byte_out(state_out[71:64]));
    aes_inv_sbox inv_sbox_b8  (.byte_in(state_in[63:56]),   .byte_out(state_out[63:56]));
    aes_inv_sbox inv_sbox_b9  (.byte_in(state_in[55:48]),   .byte_out(state_out[55:48]));
    aes_inv_sbox inv_sbox_b10 (.byte_in(state_in[47:40]),   .byte_out(state_out[47:40]));
    aes_inv_sbox inv_sbox_b11 (.byte_in(state_in[39:32]),   .byte_out(state_out[39:32]));
    aes_inv_sbox inv_sbox_b12 (.byte_in(state_in[31:24]),   .byte_out(state_out[31:24]));
    aes_inv_sbox inv_sbox_b13 (.byte_in(state_in[23:16]),   .byte_out(state_out[23:16]));
    aes_inv_sbox inv_sbox_b14 (.byte_in(state_in[15:8]),    .byte_out(state_out[15:8]));
    aes_inv_sbox inv_sbox_b15 (.byte_in(state_in[7:0]),     .byte_out(state_out[7:0]));

endmodule
