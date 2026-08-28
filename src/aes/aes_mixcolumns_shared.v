`timescale 1ns / 1ps
//==============================================================================
// Shared AES MixColumns / InvMixColumns Transformation Module
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Unifies forward MixColumns and inverse MixColumns into a single shared unit
// using the mathematical identity:
//   InvMixColumns(s) = MixColumns(s) ^ diff(s)
// where for each column:
//   a = s0 ^ s2
//   b = s1 ^ s3
//   diff0 = xtime(xtime(xtime(a) ^ a ^ xtime(b)))
//   diff1 = xtime(xtime(xtime(b) ^ b ^ xtime(a)))
//   diff2 = diff0
//   diff3 = diff1
//
// When is_inv == 0: diff is 0, yielding exact forward MixColumns.
// When is_inv == 1: diff is applied, yielding exact inverse MixColumns.
// Saves ~450 LUTs by eliminating the separate 128-bit InvMixColumns datapath.
//==============================================================================

module aes_mixcolumns_shared (
    input  wire         is_inv,     // 0 = Forward MixColumns, 1 = Inverse MixColumns
    input  wire [127:0] state_in,   // 128-bit input state (column-major)
    output wire [127:0] state_out   // 128-bit output state
);

    // xtime inline function in GF(2^8)
    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = b[7] ? ({b[6:0], 1'b0} ^ 8'h1b) : {b[6:0], 1'b0};
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_cols
            // 4 bytes of column i
            wire [7:0] s0 = state_in[127 - 32*i -: 8];
            wire [7:0] s1 = state_in[119 - 32*i -: 8];
            wire [7:0] s2 = state_in[111 - 32*i -: 8];
            wire [7:0] s3 = state_in[103 - 32*i -: 8];

            // Standard forward MixColumns terms:
            wire [7:0] t0 = xtime(s0);
            wire [7:0] t1 = xtime(s1);
            wire [7:0] t2 = xtime(s2);
            wire [7:0] t3 = xtime(s3);

            wire [7:0] mc0 = t0 ^ t1 ^ s1 ^ s2 ^ s3;
            wire [7:0] mc1 = s0 ^ t1 ^ t2 ^ s2 ^ s3;
            wire [7:0] mc2 = s0 ^ s1 ^ t2 ^ t3 ^ s3;
            wire [7:0] mc3 = t0 ^ s0 ^ s1 ^ s2 ^ t3;

            // Inverse correction terms:
            wire [7:0] a = s0 ^ s2;
            wire [7:0] b = s1 ^ s3;
            wire [7:0] xt_a = xtime(a);
            wire [7:0] xt_b = xtime(b);

            wire [7:0] diff0 = is_inv ? xtime(xtime(xt_a ^ a ^ xt_b)) : 8'h00;
            wire [7:0] diff1 = is_inv ? xtime(xtime(xt_b ^ b ^ xt_a)) : 8'h00;

            assign state_out[127 - 32*i -: 8] = mc0 ^ diff0;
            assign state_out[119 - 32*i -: 8] = mc1 ^ diff1;
            assign state_out[111 - 32*i -: 8] = mc2 ^ diff0;
            assign state_out[103 - 32*i -: 8] = mc3 ^ diff1;
        end
    endgenerate

endmodule
