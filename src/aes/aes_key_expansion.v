`timescale 1ns / 1ps
//==============================================================================
// AES-128 Key Expansion
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Generates all 11 round keys (round_key[0] through round_key[10]) from
// the 128-bit cipher key using the AES key schedule algorithm.
//
// This is PURE COMBINATIONAL LOGIC - all 11 round keys are generated
// simultaneously from the input key. No clock, no state.
//
// MODIFIED from reference: S-box lookup table removed from this module.
// SubWord now uses 4 instantiations of the shared aes_sbox module,
// eliminating the duplicated S-box function that existed in both
// aes_subbytes.v and aes_key_expansion.v.
//
// Algorithm (FIPS 197 Section 5.2):
//   - Input: 4 words (W[0], W[1], W[2], W[3]) = 128-bit cipher key
//   - Output: 44 words (W[0] through W[43]) = 11 round keys
//
//   For i = 4 to 43:
//     if (i % 4 == 0):
//       temp = SubWord(RotWord(W[i-1])) XOR Rcon[i/4]
//       W[i] = W[i-4] XOR temp
//     else:
//       W[i] = W[i-4] XOR W[i-1]
//
// NIST Test Vector (FIPS 197 Appendix A.1):
//   Cipher Key: 000102030405060708090a0b0c0d0e0f
//   Round Key  0: 000102030405060708090a0b0c0d0e0f
//   Round Key  1: d6aa74fdd2af72fadaa678f1d6ab76fe
//   Round Key 10: 13111d7fe3944a17f307a78b4d2b30c5
//==============================================================================

module aes_key_expansion (
    input  wire [127:0] cipher_key,    // Input: 128-bit cipher key
    output wire [127:0] round_key_0,   // Round key  0 (initial whitening)
    output wire [127:0] round_key_1,   // Round key  1
    output wire [127:0] round_key_2,   // Round key  2
    output wire [127:0] round_key_3,   // Round key  3
    output wire [127:0] round_key_4,   // Round key  4
    output wire [127:0] round_key_5,   // Round key  5
    output wire [127:0] round_key_6,   // Round key  6
    output wire [127:0] round_key_7,   // Round key  7
    output wire [127:0] round_key_8,   // Round key  8
    output wire [127:0] round_key_9,   // Round key  9
    output wire [127:0] round_key_10   // Round key 10 (final round)
);

    //==========================================================================
    // SubWord via shared aes_sbox instances
    //==========================================================================
    // SubWord applies the S-box to each of the 4 bytes of a 32-bit word.
    // We need SubWord(RotWord(w[i-1])) for each of the 10 rounds.
    // To keep synthesis simple and allow tool-driven sharing, we use
    // intermediate wires and 4 S-box instances per SubWord call.
    //
    // For a fully combinational key expansion, we instantiate S-boxes
    // for all 10 rounds = 40 aes_sbox instances. Synthesis will merge
    // and share LUTs as needed to meet the <1,500 LUT constraint.

    // RotWord: circular left shift by 1 byte
    // Input:  [a0, a1, a2, a3] (a0 at [31:24])
    // Output: [a1, a2, a3, a0]
    function [31:0] rotword;
        input [31:0] word;
        begin
            rotword = {word[23:0], word[31:24]};
        end
    endfunction

    //==========================================================================
    // Round Constants (Rcon)
    //==========================================================================
    function [31:0] rcon;
        input [3:0] round;
        begin
            case (round)
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
    // Key Expansion Word Array
    //==========================================================================
    wire [31:0] w[0:43];

    //==========================================================================
    // Initial 4 Words = Cipher Key
    //==========================================================================
    assign w[0] = cipher_key[127:96];
    assign w[1] = cipher_key[95:64];
    assign w[2] = cipher_key[63:32];
    assign w[3] = cipher_key[31:0];

    //==========================================================================
    // SubWord wires and S-box instances for rounds 1-10
    //==========================================================================
    // For each round r (1..10), we compute:
    //   rotated_r = RotWord(w[4*r - 1])
    //   subword_r = SubWord(rotated_r) via 4 S-box instances
    //   w[4*r]    = w[4*(r-1)] ^ subword_r ^ rcon(r)

    // Round 1
    wire [31:0] rot1 = rotword(w[3]);
    wire [31:0] sub1;
    aes_sbox sb1_0 (.byte_in(rot1[31:24]), .byte_out(sub1[31:24]));
    aes_sbox sb1_1 (.byte_in(rot1[23:16]), .byte_out(sub1[23:16]));
    aes_sbox sb1_2 (.byte_in(rot1[15:8]),  .byte_out(sub1[15:8]));
    aes_sbox sb1_3 (.byte_in(rot1[7:0]),   .byte_out(sub1[7:0]));
    assign w[4] = w[0] ^ sub1 ^ rcon(1);
    assign w[5] = w[1] ^ w[4];
    assign w[6] = w[2] ^ w[5];
    assign w[7] = w[3] ^ w[6];

    // Round 2
    wire [31:0] rot2 = rotword(w[7]);
    wire [31:0] sub2;
    aes_sbox sb2_0 (.byte_in(rot2[31:24]), .byte_out(sub2[31:24]));
    aes_sbox sb2_1 (.byte_in(rot2[23:16]), .byte_out(sub2[23:16]));
    aes_sbox sb2_2 (.byte_in(rot2[15:8]),  .byte_out(sub2[15:8]));
    aes_sbox sb2_3 (.byte_in(rot2[7:0]),   .byte_out(sub2[7:0]));
    assign w[8]  = w[4] ^ sub2 ^ rcon(2);
    assign w[9]  = w[5] ^ w[8];
    assign w[10] = w[6] ^ w[9];
    assign w[11] = w[7] ^ w[10];

    // Round 3
    wire [31:0] rot3 = rotword(w[11]);
    wire [31:0] sub3;
    aes_sbox sb3_0 (.byte_in(rot3[31:24]), .byte_out(sub3[31:24]));
    aes_sbox sb3_1 (.byte_in(rot3[23:16]), .byte_out(sub3[23:16]));
    aes_sbox sb3_2 (.byte_in(rot3[15:8]),  .byte_out(sub3[15:8]));
    aes_sbox sb3_3 (.byte_in(rot3[7:0]),   .byte_out(sub3[7:0]));
    assign w[12] = w[8]  ^ sub3 ^ rcon(3);
    assign w[13] = w[9]  ^ w[12];
    assign w[14] = w[10] ^ w[13];
    assign w[15] = w[11] ^ w[14];

    // Round 4
    wire [31:0] rot4 = rotword(w[15]);
    wire [31:0] sub4;
    aes_sbox sb4_0 (.byte_in(rot4[31:24]), .byte_out(sub4[31:24]));
    aes_sbox sb4_1 (.byte_in(rot4[23:16]), .byte_out(sub4[23:16]));
    aes_sbox sb4_2 (.byte_in(rot4[15:8]),  .byte_out(sub4[15:8]));
    aes_sbox sb4_3 (.byte_in(rot4[7:0]),   .byte_out(sub4[7:0]));
    assign w[16] = w[12] ^ sub4 ^ rcon(4);
    assign w[17] = w[13] ^ w[16];
    assign w[18] = w[14] ^ w[17];
    assign w[19] = w[15] ^ w[18];

    // Round 5
    wire [31:0] rot5 = rotword(w[19]);
    wire [31:0] sub5;
    aes_sbox sb5_0 (.byte_in(rot5[31:24]), .byte_out(sub5[31:24]));
    aes_sbox sb5_1 (.byte_in(rot5[23:16]), .byte_out(sub5[23:16]));
    aes_sbox sb5_2 (.byte_in(rot5[15:8]),  .byte_out(sub5[15:8]));
    aes_sbox sb5_3 (.byte_in(rot5[7:0]),   .byte_out(sub5[7:0]));
    assign w[20] = w[16] ^ sub5 ^ rcon(5);
    assign w[21] = w[17] ^ w[20];
    assign w[22] = w[18] ^ w[21];
    assign w[23] = w[19] ^ w[22];

    // Round 6
    wire [31:0] rot6 = rotword(w[23]);
    wire [31:0] sub6;
    aes_sbox sb6_0 (.byte_in(rot6[31:24]), .byte_out(sub6[31:24]));
    aes_sbox sb6_1 (.byte_in(rot6[23:16]), .byte_out(sub6[23:16]));
    aes_sbox sb6_2 (.byte_in(rot6[15:8]),  .byte_out(sub6[15:8]));
    aes_sbox sb6_3 (.byte_in(rot6[7:0]),   .byte_out(sub6[7:0]));
    assign w[24] = w[20] ^ sub6 ^ rcon(6);
    assign w[25] = w[21] ^ w[24];
    assign w[26] = w[22] ^ w[25];
    assign w[27] = w[23] ^ w[26];

    // Round 7
    wire [31:0] rot7 = rotword(w[27]);
    wire [31:0] sub7;
    aes_sbox sb7_0 (.byte_in(rot7[31:24]), .byte_out(sub7[31:24]));
    aes_sbox sb7_1 (.byte_in(rot7[23:16]), .byte_out(sub7[23:16]));
    aes_sbox sb7_2 (.byte_in(rot7[15:8]),  .byte_out(sub7[15:8]));
    aes_sbox sb7_3 (.byte_in(rot7[7:0]),   .byte_out(sub7[7:0]));
    assign w[28] = w[24] ^ sub7 ^ rcon(7);
    assign w[29] = w[25] ^ w[28];
    assign w[30] = w[26] ^ w[29];
    assign w[31] = w[27] ^ w[30];

    // Round 8
    wire [31:0] rot8 = rotword(w[31]);
    wire [31:0] sub8;
    aes_sbox sb8_0 (.byte_in(rot8[31:24]), .byte_out(sub8[31:24]));
    aes_sbox sb8_1 (.byte_in(rot8[23:16]), .byte_out(sub8[23:16]));
    aes_sbox sb8_2 (.byte_in(rot8[15:8]),  .byte_out(sub8[15:8]));
    aes_sbox sb8_3 (.byte_in(rot8[7:0]),   .byte_out(sub8[7:0]));
    assign w[32] = w[28] ^ sub8 ^ rcon(8);
    assign w[33] = w[29] ^ w[32];
    assign w[34] = w[30] ^ w[33];
    assign w[35] = w[31] ^ w[34];

    // Round 9
    wire [31:0] rot9 = rotword(w[35]);
    wire [31:0] sub9;
    aes_sbox sb9_0 (.byte_in(rot9[31:24]), .byte_out(sub9[31:24]));
    aes_sbox sb9_1 (.byte_in(rot9[23:16]), .byte_out(sub9[23:16]));
    aes_sbox sb9_2 (.byte_in(rot9[15:8]),  .byte_out(sub9[15:8]));
    aes_sbox sb9_3 (.byte_in(rot9[7:0]),   .byte_out(sub9[7:0]));
    assign w[36] = w[32] ^ sub9 ^ rcon(9);
    assign w[37] = w[33] ^ w[36];
    assign w[38] = w[34] ^ w[37];
    assign w[39] = w[35] ^ w[38];

    // Round 10
    wire [31:0] rot10 = rotword(w[39]);
    wire [31:0] sub10;
    aes_sbox sb10_0 (.byte_in(rot10[31:24]), .byte_out(sub10[31:24]));
    aes_sbox sb10_1 (.byte_in(rot10[23:16]), .byte_out(sub10[23:16]));
    aes_sbox sb10_2 (.byte_in(rot10[15:8]),  .byte_out(sub10[15:8]));
    aes_sbox sb10_3 (.byte_in(rot10[7:0]),   .byte_out(sub10[7:0]));
    assign w[40] = w[36] ^ sub10 ^ rcon(10);
    assign w[41] = w[37] ^ w[40];
    assign w[42] = w[38] ^ w[41];
    assign w[43] = w[39] ^ w[42];

    //==========================================================================
    // Output Round Keys
    //==========================================================================
    assign round_key_0  = {w[0],  w[1],  w[2],  w[3]};
    assign round_key_1  = {w[4],  w[5],  w[6],  w[7]};
    assign round_key_2  = {w[8],  w[9],  w[10], w[11]};
    assign round_key_3  = {w[12], w[13], w[14], w[15]};
    assign round_key_4  = {w[16], w[17], w[18], w[19]};
    assign round_key_5  = {w[20], w[21], w[22], w[23]};
    assign round_key_6  = {w[24], w[25], w[26], w[27]};
    assign round_key_7  = {w[28], w[29], w[30], w[31]};
    assign round_key_8  = {w[32], w[33], w[34], w[35]};
    assign round_key_9  = {w[36], w[37], w[38], w[39]};
    assign round_key_10 = {w[40], w[41], w[42], w[43]};

endmodule
