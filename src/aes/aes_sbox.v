`timescale 1ns / 1ps
//==============================================================================
// AES Forward S-Box Module (Canright Compact Composite Field Core)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================

module aes_sbox (
    input  wire [7:0] byte_in,
    output wire [7:0] byte_out
);

    bSbox canright_inst (
        .A(byte_in),
        .encrypt(1'b1),
        .Q(byte_out)
    );

endmodule