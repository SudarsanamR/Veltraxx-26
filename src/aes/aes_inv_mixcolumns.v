`timescale 1ns / 1ps
//==============================================================================
// AES Inverse MixColumns Transformation
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Multiplies each column of the AES state by the InvMixColumns matrix in GF(2^8):
//
//   [out0]   [0e 0b 0d 09] [s0]
//   [out1] = [09 0e 0b 0d] [s1]   (all arithmetic in GF(2^8), poly 0x11b)
//   [out2]   [0d 09 0e 0b] [s2]
//   [out3]   [0b 0d 09 0e] [s3]
//
// GF(2^8) Decomposition:
//   xtime(a)  = 2*a = a[7] ? ({a[6:0], 1'b0} ^ 8'h1b) : {a[6:0], 1'b0}
//   xtime2(a) = 4*a = xtime(2*a)
//   xtime3(a) = 8*a = xtime(4*a)
//
//   09*a = 8*a ^ a
//   0b*a = 8*a ^ 2*a ^ a
//   0d*a = 8*a ^ 4*a ^ a
//   0e*a = 8*a ^ 4*a ^ 2*a
//==============================================================================

module aes_inv_mixcolumns (
    input  wire [127:0] state_in,   // Input state (16 bytes, column-major)
    output wire [127:0] state_out   // Output state after Inverse MixColumns
);

    // Function for xtime in GF(2^8)
    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = b[7] ? ({b[6:0], 1'b0} ^ 8'h1b) : {b[6:0], 1'b0};
        end
    endfunction

    // Multiplications by 0x09, 0x0b, 0x0d, 0x0e
    function [7:0] mul9;
        input [7:0] b;
        reg [7:0] x2, x4, x8;
        begin
            x2 = xtime(b);
            x4 = xtime(x2);
            x8 = xtime(x4);
            mul9 = x8 ^ b;
        end
    endfunction

    function [7:0] mulb;
        input [7:0] b;
        reg [7:0] x2, x4, x8;
        begin
            x2 = xtime(b);
            x4 = xtime(x2);
            x8 = xtime(x4);
            mulb = x8 ^ x2 ^ b;
        end
    endfunction

    function [7:0] muld;
        input [7:0] b;
        reg [7:0] x2, x4, x8;
        begin
            x2 = xtime(b);
            x4 = xtime(x2);
            x8 = xtime(x4);
            muld = x8 ^ x4 ^ b;
        end
    endfunction

    function [7:0] mule;
        input [7:0] b;
        reg [7:0] x2, x4, x8;
        begin
            x2 = xtime(b);
            x4 = xtime(x2);
            x8 = xtime(x4);
            mule = x8 ^ x4 ^ x2;
        end
    endfunction

    //==========================================================================
    // Column 0: state_in[127:96]
    //==========================================================================
    wire [7:0] c0_s0 = state_in[127:120];
    wire [7:0] c0_s1 = state_in[119:112];
    wire [7:0] c0_s2 = state_in[111:104];
    wire [7:0] c0_s3 = state_in[103:96];

    assign state_out[127:120] = mule(c0_s0) ^ mulb(c0_s1) ^ muld(c0_s2) ^ mul9(c0_s3);
    assign state_out[119:112] = mul9(c0_s0) ^ mule(c0_s1) ^ mulb(c0_s2) ^ muld(c0_s3);
    assign state_out[111:104] = muld(c0_s0) ^ mul9(c0_s1) ^ mule(c0_s2) ^ mulb(c0_s3);
    assign state_out[103:96]  = mulb(c0_s0) ^ muld(c0_s1) ^ mul9(c0_s2) ^ mule(c0_s3);

    //==========================================================================
    // Column 1: state_in[95:64]
    //==========================================================================
    wire [7:0] c1_s0 = state_in[95:88];
    wire [7:0] c1_s1 = state_in[87:80];
    wire [7:0] c1_s2 = state_in[79:72];
    wire [7:0] c1_s3 = state_in[71:64];

    assign state_out[95:88]  = mule(c1_s0) ^ mulb(c1_s1) ^ muld(c1_s2) ^ mul9(c1_s3);
    assign state_out[87:80]  = mul9(c1_s0) ^ mule(c1_s1) ^ mulb(c1_s2) ^ muld(c1_s3);
    assign state_out[79:72]  = muld(c1_s0) ^ mul9(c1_s1) ^ mule(c1_s2) ^ mulb(c1_s3);
    assign state_out[71:64]  = mulb(c1_s0) ^ muld(c1_s1) ^ mul9(c1_s2) ^ mule(c1_s3);

    //==========================================================================
    // Column 2: state_in[63:32]
    //==========================================================================
    wire [7:0] c2_s0 = state_in[63:56];
    wire [7:0] c2_s1 = state_in[55:48];
    wire [7:0] c2_s2 = state_in[47:40];
    wire [7:0] c2_s3 = state_in[39:32];

    assign state_out[63:56]  = mule(c2_s0) ^ mulb(c2_s1) ^ muld(c2_s2) ^ mul9(c2_s3);
    assign state_out[55:48]  = mul9(c2_s0) ^ mule(c2_s1) ^ mulb(c2_s2) ^ muld(c2_s3);
    assign state_out[47:40]  = muld(c2_s0) ^ mul9(c2_s1) ^ mule(c2_s2) ^ mulb(c2_s3);
    assign state_out[39:32]  = mulb(c2_s0) ^ muld(c2_s1) ^ mul9(c2_s2) ^ mule(c2_s3);

    //==========================================================================
    // Column 3: state_in[31:0]
    //==========================================================================
    wire [7:0] c3_s0 = state_in[31:24];
    wire [7:0] c3_s1 = state_in[23:16];
    wire [7:0] c3_s2 = state_in[15:8];
    wire [7:0] c3_s3 = state_in[7:0];

    assign state_out[31:24]  = mule(c3_s0) ^ mulb(c3_s1) ^ muld(c3_s2) ^ mul9(c3_s3);
    assign state_out[23:16]  = mul9(c3_s0) ^ mule(c3_s1) ^ mulb(c3_s2) ^ muld(c3_s3);
    assign state_out[15:8]   = muld(c3_s0) ^ mul9(c3_s1) ^ mule(c3_s2) ^ mulb(c3_s3);
    assign state_out[7:0]    = mulb(c3_s0) ^ muld(c3_s1) ^ mul9(c3_s2) ^ mule(c3_s3);

endmodule
