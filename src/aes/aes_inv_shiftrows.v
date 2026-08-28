`timescale 1ns / 1ps
//==============================================================================
// AES Inverse ShiftRows Transformation
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Performs the AES InvShiftRows step: cyclically shifts each row of the state
// matrix right by the row index (0, 1, 2, 3 byte positions).
//
// This is PURE WIRE ROUTING - zero logic gates, zero LUTs consumed.
// Synthesis will implement this as direct net connections only.
//
// AES State Matrix (column-major layout):
//
//           col0       col1      col2      col3
//   row0:  [127:120]  [95:88]   [63:56]   [31:24]   <- shift right 0 (unchanged)
//   row1:  [119:112]  [87:80]   [55:48]   [23:16]   <- shift right 1
//   row2:  [111:104]  [79:72]   [47:40]   [15: 8]   <- shift right 2
//   row3:  [103: 96]  [71:64]   [39:32]   [ 7: 0]   <- shift right 3 (= shift left 1)
//
// InvShiftRows result:
//
//           col0       col1      col2      col3
//   row0:   b[0]       b[4]      b[8]      b[12]   (unchanged)
//   row1:   b[13]      b[1]      b[5]      b[9]    (rotated right 1)
//   row2:   b[10]      b[14]     b[2]      b[6]    (rotated right 2)
//   row3:   b[7]       b[11]     b[15]     b[3]    (rotated right 3 = left 1)
//==============================================================================

module aes_inv_shiftrows (
    input  wire [127:0] state_in,   // Input state (16 bytes, column-major)
    output wire [127:0] state_out   // Output state after inverse row shifts
);

    // Row 0 - No Shift
    assign state_out[127:120] = state_in[127:120]; // b0
    assign state_out[95:88]   = state_in[95:88];   // b4
    assign state_out[63:56]   = state_in[63:56];   // b8
    assign state_out[31:24]   = state_in[31:24];   // b12

    // Row 1 - Shift Right by 1 Byte (col3 wraps to col0)
    assign state_out[119:112] = state_in[23:16];   // b13 -> col0
    assign state_out[87:80]   = state_in[119:112]; // b1  -> col1
    assign state_out[55:48]   = state_in[87:80];   // b5  -> col2
    assign state_out[23:16]   = state_in[55:48];   // b9  -> col3

    // Row 2 - Shift Right by 2 Bytes (swap halves)
    assign state_out[111:104] = state_in[47:40];   // b10 -> col0
    assign state_out[79:72]   = state_in[15:8];    // b14 -> col1
    assign state_out[47:40]   = state_in[111:104]; // b2  -> col2
    assign state_out[15:8]    = state_in[79:72];   // b6  -> col3

    // Row 3 - Shift Right by 3 Bytes (= Shift Left by 1 Byte)
    assign state_out[103:96]  = state_in[71:64];   // b7  -> col0
    assign state_out[71:64]   = state_in[39:32];   // b11 -> col1
    assign state_out[39:32]   = state_in[7:0];     // b15 -> col2
    assign state_out[7:0]     = state_in[103:96];  // b3  -> col3

endmodule
