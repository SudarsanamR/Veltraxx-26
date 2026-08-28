`timescale 1ns / 1ps
//==============================================================================
// AES Shared SubBytes / InvSubBytes Transformation
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Dual-mode byte substitution unit instantiating 16 shared S-box modules.
// Selects between forward SubBytes and inverse InvSubBytes via is_inv control.
//==============================================================================

module aes_subbytes_shared (
    input  wire         is_inv,
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    aes_sbox_shared sb0  (.is_inv(is_inv), .byte_in(state_in[127:120]), .byte_out(state_out[127:120]));
    aes_sbox_shared sb1  (.is_inv(is_inv), .byte_in(state_in[119:112]), .byte_out(state_out[119:112]));
    aes_sbox_shared sb2  (.is_inv(is_inv), .byte_in(state_in[111:104]), .byte_out(state_out[111:104]));
    aes_sbox_shared sb3  (.is_inv(is_inv), .byte_in(state_in[103:96]),  .byte_out(state_out[103:96]));
    aes_sbox_shared sb4  (.is_inv(is_inv), .byte_in(state_in[95:88]),   .byte_out(state_out[95:88]));
    aes_sbox_shared sb5  (.is_inv(is_inv), .byte_in(state_in[87:80]),   .byte_out(state_out[87:80]));
    aes_sbox_shared sb6  (.is_inv(is_inv), .byte_in(state_in[79:72]),   .byte_out(state_out[79:72]));
    aes_sbox_shared sb7  (.is_inv(is_inv), .byte_in(state_in[71:64]),   .byte_out(state_out[71:64]));
    aes_sbox_shared sb8  (.is_inv(is_inv), .byte_in(state_in[63:56]),   .byte_out(state_out[63:56]));
    aes_sbox_shared sb9  (.is_inv(is_inv), .byte_in(state_in[55:48]),   .byte_out(state_out[55:48]));
    aes_sbox_shared sb10 (.is_inv(is_inv), .byte_in(state_in[47:40]),   .byte_out(state_out[47:40]));
    aes_sbox_shared sb11 (.is_inv(is_inv), .byte_in(state_in[39:32]),   .byte_out(state_out[39:32]));
    aes_sbox_shared sb12 (.is_inv(is_inv), .byte_in(state_in[31:24]),   .byte_out(state_out[31:24]));
    aes_sbox_shared sb13 (.is_inv(is_inv), .byte_in(state_in[23:16]),   .byte_out(state_out[23:16]));
    aes_sbox_shared sb14 (.is_inv(is_inv), .byte_in(state_in[15:8]),    .byte_out(state_out[15:8]));
    aes_sbox_shared sb15 (.is_inv(is_inv), .byte_in(state_in[7:0]),     .byte_out(state_out[7:0]));

endmodule
