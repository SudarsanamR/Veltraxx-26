`timescale 1ns / 1ps
//==============================================================================
// AES-128 On-The-Fly Key Expander (Forward & Reverse)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Computes AES-128 round keys on-the-fly, one round per clock cycle,
// in both forward direction (for encryption) and reverse direction (for decryption).
//
// Key Feature:
//   - Uses ONLY 4 S-boxes in total (shared between forward and reverse stepping).
//   - Saves ~1,000 LUTs compared to static 40-Sbox unrolled key expansion.
//   - Zero BRAM utilization.
//
// Forward Step (r = 1..10):
//   Input:  K_{r-1} = {W0, W1, W2, W3}, Rcon[r]
//   Output: K_r     = {W0', W1', W2', W3'}
//     W0' = W0 ^ SubWord(RotWord(W3)) ^ Rcon[r]
//     W1' = W1 ^ W0'
//     W2' = W2 ^ W1'
//     W3' = W3 ^ W2'
//
// Reverse Step (r = 10..1):
//   Input:  K_r     = {W0', W1', W2', W3'}, Rcon[r]
//   Output: K_{r-1} = {W0, W1, W2, W3}
//     W3  = W3' ^ W2'
//     W2  = W2' ^ W1'
//     W1  = W1' ^ W0'
//     W0  = W0' ^ SubWord(RotWord(W3)) ^ Rcon[r]
//==============================================================================

module aes_key_expand (
    input  wire         dir_inv,      // 0 = Forward (K_{r-1} -> K_r), 1 = Reverse (K_r -> K_{r-1})
    input  wire [3:0]   round_idx,    // Round index (1..10)
    input  wire [127:0] key_in,       // Current 128-bit key
    output wire [127:0] key_out       // Stepped 128-bit key
);

    //==========================================================================
    // Unpack 32-bit Words
    //==========================================================================
    wire [31:0] w0_in = key_in[127:96];
    wire [31:0] w1_in = key_in[95:64];
    wire [31:0] w2_in = key_in[63:32];
    wire [31:0] w3_in = key_in[31:0];

    //==========================================================================
    // RotWord helper
    //==========================================================================
    function [31:0] rotword;
        input [31:0] w;
        begin
            rotword = {w[23:0], w[31:24]};
        end
    endfunction

    //==========================================================================
    // Round Constants (Rcon)
    //==========================================================================
    function [31:0] rcon;
        input [3:0] r;
        begin
            case (r)
                4'd1:  rcon = 32'h01000000;
                4'd2:  rcon = 32'h02000000;
                4'd3:  rcon = 32'h04000000;
                4'd4:  rcon = 32'h08000000;
                4'd5:  rcon = 32'h10000000;
                4'd6:  rcon = 32'h20000000;
                4'd7:  rcon = 32'h40000000;
                4'd8:  rcon = 32'h80000000;
                4'd9:  rcon = 32'h1b000000;
                4'd10: rcon = 32'h36000000;
                default: rcon = 32'h00000000;
            endcase
        end
    endfunction

    //==========================================================================
    // Word to pass through SubWord(RotWord(...))
    //==========================================================================
    // For forward: we pass w3_in.
    // For reverse: we pass w3_recovered = w3_in ^ w2_in.
    wire [31:0] w3_rev_calc = w3_in ^ w2_in;
    wire [31:0] sbox_word_in = dir_inv ? w3_rev_calc : w3_in;
    wire [31:0] rotated_word = rotword(sbox_word_in);

    //==========================================================================
    // 4 S-boxes for SubWord
    //==========================================================================
    wire [31:0] subword_out;
    aes_sbox sb0 (.byte_in(rotated_word[31:24]), .byte_out(subword_out[31:24]));
    aes_sbox sb1 (.byte_in(rotated_word[23:16]), .byte_out(subword_out[23:16]));
    aes_sbox sb2 (.byte_in(rotated_word[15:8]),  .byte_out(subword_out[15:8]));
    aes_sbox sb3 (.byte_in(rotated_word[7:0]),   .byte_out(subword_out[7:0]));

    //==========================================================================
    // Forward Step Calculation
    //==========================================================================
    wire [31:0] w0_fwd = w0_in ^ subword_out ^ rcon(round_idx);
    wire [31:0] w1_fwd = w1_in ^ w0_fwd;
    wire [31:0] w2_fwd = w2_in ^ w1_fwd;
    wire [31:0] w3_fwd = w3_in ^ w2_fwd;

    //==========================================================================
    // Reverse Step Calculation
    //==========================================================================
    wire [31:0] w2_rev = w2_in ^ w1_in;
    wire [31:0] w1_rev = w1_in ^ w0_in;
    wire [31:0] w0_rev = w0_in ^ subword_out ^ rcon(round_idx);

    //==========================================================================
    // Mux Key Outputs
    //==========================================================================
    assign key_out[127:96] = dir_inv ? w0_rev      : w0_fwd;
    assign key_out[95:64]  = dir_inv ? w1_rev      : w1_fwd;
    assign key_out[63:32]  = dir_inv ? w2_rev      : w2_fwd;
    assign key_out[31:0]   = dir_inv ? w3_rev_calc : w3_fwd;

endmodule
