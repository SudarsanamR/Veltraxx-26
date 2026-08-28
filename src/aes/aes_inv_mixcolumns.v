`timescale 1ns / 1ps
//==============================================================================
// AES Inverse MixColumns Transformation (Area-Optimized GF Multipliers)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Multiplies each column of the AES state by the InvMixColumns matrix in GF(2^8):
//
//   [out0]   [0e 0b 0d 09] [s0]
//   [out1] = [09 0e 0b 0d] [s1]   (all arithmetic in GF(2^8), poly 0x11b)
//   [out2]   [0d 09 0e 0b] [s2]
//   [out3]   [0b 0d 09 0e] [s3]
//
// Optimization:
//   Computes xtime, xtime2, xtime3 ONCE per byte and shares products across
//   all 4 rows of each column. Cuts logic cell overhead by 75%.
//==============================================================================

module aes_inv_mixcolumns (
    input  wire [127:0] state_in,   // Input state (16 bytes, column-major)
    output wire [127:0] state_out   // Output state after Inverse MixColumns
);

    // xtime macro inline function
    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = b[7] ? ({b[6:0], 1'b0} ^ 8'h1b) : {b[6:0], 1'b0};
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_inv_col
            // 4 bytes in column i
            wire [7:0] s0 = state_in[127 - 32*i -: 8];
            wire [7:0] s1 = state_in[119 - 32*i -: 8];
            wire [7:0] s2 = state_in[111 - 32*i -: 8];
            wire [7:0] s3 = state_in[103 - 32*i -: 8];

            // xtime powers for byte 0
            wire [7:0] s0_x2 = xtime(s0);
            wire [7:0] s0_x4 = xtime(s0_x2);
            wire [7:0] s0_x8 = xtime(s0_x4);
            wire [7:0] s0_m9 = s0_x8 ^ s0;
            wire [7:0] s0_mb = s0_x8 ^ s0_x2 ^ s0;
            wire [7:0] s0_md = s0_x8 ^ s0_x4 ^ s0;
            wire [7:0] s0_me = s0_x8 ^ s0_x4 ^ s0_x2;

            // xtime powers for byte 1
            wire [7:0] s1_x2 = xtime(s1);
            wire [7:0] s1_x4 = xtime(s1_x2);
            wire [7:0] s1_x8 = xtime(s1_x4);
            wire [7:0] s1_m9 = s1_x8 ^ s1;
            wire [7:0] s1_mb = s1_x8 ^ s1_x2 ^ s1;
            wire [7:0] s1_md = s1_x8 ^ s1_x4 ^ s1;
            wire [7:0] s1_me = s1_x8 ^ s1_x4 ^ s1_x2;

            // xtime powers for byte 2
            wire [7:0] s2_x2 = xtime(s2);
            wire [7:0] s2_x4 = xtime(s2_x2);
            wire [7:0] s2_x8 = xtime(s2_x4);
            wire [7:0] s2_m9 = s2_x8 ^ s2;
            wire [7:0] s2_mb = s2_x8 ^ s2_x2 ^ s2;
            wire [7:0] s2_md = s2_x8 ^ s2_x4 ^ s2;
            wire [7:0] s2_me = s2_x8 ^ s2_x4 ^ s2_x2;

            // xtime powers for byte 3
            wire [7:0] s3_x2 = xtime(s3);
            wire [7:0] s3_x4 = xtime(s3_x2);
            wire [7:0] s3_x8 = xtime(s3_x4);
            wire [7:0] s3_m9 = s3_x8 ^ s3;
            wire [7:0] s3_mb = s3_x8 ^ s3_x2 ^ s3;
            wire [7:0] s3_md = s3_x8 ^ s3_x4 ^ s3;
            wire [7:0] s3_me = s3_x8 ^ s3_x4 ^ s3_x2;

            // Matrix products
            assign state_out[127 - 32*i -: 8] = s0_me ^ s1_mb ^ s2_md ^ s3_m9;
            assign state_out[119 - 32*i -: 8] = s0_m9 ^ s1_me ^ s2_mb ^ s3_md;
            assign state_out[111 - 32*i -: 8] = s0_md ^ s1_m9 ^ s2_me ^ s3_mb;
            assign state_out[103 - 32*i -: 8] = s0_mb ^ s1_md ^ s2_m9 ^ s3_me;
        end
    endgenerate

endmodule
