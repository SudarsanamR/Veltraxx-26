`timescale 1ns / 1ps
//==============================================================================
// AES-128 Secure Register Bank (AXI Memory-Mapped Subsystem)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Implements the official memory-mapped register bank compliant with:
//   - docs/register_map.md
//   - docs/security.md (Cryptographic isolation & anti-leakage boundary)
//
// Register Map (32-bit aligned, byte offsets):
//   0x00: CONTROL    - Bit 0: START (self-clearing), Bit 1: MODE (0=Enc, 1=Dec), Bit 2: CORE_RESET
//   0x04: STATUS     - Bit 0: BUSY, Bit 1: DONE, Bit 2: READY (RO)
//   0x08: CONFIG     - General Configuration Register (R/W)
//   0x0C: RESERVED   - Reserved (RO, returns 0x0000_0000)
//   0x10: KEY_0      - 128-bit Key Word 0 [127:96] (WO, reads return 0x0000_0000)
//   0x14: KEY_1      - 128-bit Key Word 1 [95:64]  (WO, reads return 0x0000_0000)
//   0x18: KEY_2      - 128-bit Key Word 2 [63:32]  (WO, reads return 0x0000_0000)
//   0x1C: KEY_3      - 128-bit Key Word 3 [31:0]   (WO, reads return 0x0000_0000)
//   0x20: BLOCK_IN_0 - Input Block Word 0 [127:96] (R/W)
//   0x24: BLOCK_IN_1 - Input Block Word 1 [95:64]  (R/W)
//   0x28: BLOCK_IN_2 - Input Block Word 2 [63:32]  (R/W)
//   0x2C: BLOCK_IN_3 - Input Block Word 3 [31:0]   (R/W)
//   0x30: BLOCK_OUT_0- Output Block Word 0 [127:96] (RO, gated when not DONE)
//   0x34: BLOCK_OUT_1- Output Block Word 1 [95:64]  (RO, gated when not DONE)
//   0x38: BLOCK_OUT_2- Output Block Word 2 [63:32]  (RO, gated when not DONE)
//   0x3C: BLOCK_OUT_3- Output Block Word 3 [31:0]   (RO, gated when not DONE)
//   >0x3C: UNMAPPED  - Returns 0x0000_0000
//
// Anti-Leakage Hardware Hardening:
//   1. Zero exposure of intermediate states: Round states and round keys are strictly
//      isolated inside aes_core and are NEVER mapped to any address.
//   2. Write-only key registers: Key readback returns 0x0000_0000 to prevent secret theft.
//   3. Gated results: Output registers return 0x0000_0000 while core is BUSY.
//==============================================================================

module aes_registers (
    input  wire        clk,
    input  wire        rst_n,

    // Internal bus interface from AXI slave
    input  wire        reg_wr_en,
    input  wire [7:0]  reg_wr_addr,
    input  wire [31:0] reg_wr_data,
    input  wire [3:0]  reg_wr_strb,

    input  wire        reg_rd_en,
    input  wire [7:0]  reg_rd_addr,
    output reg  [31:0] reg_rd_data,

    // Core interface to aes_core
    output reg         core_start,
    output reg         core_mode,
    output reg         core_rst,
    output wire [127:0] core_key,
    output wire [127:0] core_block_in,
    input  wire [127:0] core_block_out,
    input  wire        core_done,
    input  wire        core_busy
);

    //==========================================================================
    // Register Storage
    //==========================================================================
    reg [31:0] reg_config;
    reg [31:0] key_words   [0:3];
    reg [31:0] din_words   [0:3];
    reg [31:0] dout_words  [0:3];
    reg        reg_done;

    // Word concatenation to 128-bit AES vectors
    assign core_key      = {key_words[0], key_words[1], key_words[2], key_words[3]};
    assign core_block_in = {din_words[0], din_words[1], din_words[2], din_words[3]};

    // Status flags
    wire status_busy  = core_busy;
    wire status_done  = reg_done;
    wire status_ready = ~core_busy;

    //==========================================================================
    // Register Write Logic
    //==========================================================================
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            core_start   <= 1'b0;
            core_mode    <= 1'b0;
            core_rst     <= 1'b0;
            reg_config   <= 32'h0;
            reg_done     <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                key_words[i]  <= 32'h0;
                din_words[i]  <= 32'h0;
                dout_words[i] <= 32'h0;
            end
        end else begin
            // Pulse signals default to de-asserted
            core_start <= 1'b0;
            core_rst   <= 1'b0;

            // Track completion from aes_core
            if (core_done) begin
                reg_done      <= 1'b1;
                dout_words[0] <= core_block_out[127:96];
                dout_words[1] <= core_block_out[95:64];
                dout_words[2] <= core_block_out[63:32];
                dout_words[3] <= core_block_out[31:0];
            end

            // Register writes from AXI
            if (reg_wr_en) begin
                case (reg_wr_addr[7:2])
                    6'h00: begin // 0x00: CONTROL
                        if (reg_wr_strb[0]) begin
                            if (reg_wr_data[0]) begin
                                core_start <= 1'b1;
                                reg_done   <= 1'b0; // Clear done flag on new start
                            end
                            core_mode <= reg_wr_data[1];
                            if (reg_wr_data[2]) begin
                                core_rst <= 1'b1;
                                reg_done <= 1'b0;
                            end
                        end
                    end

                    6'h02: begin // 0x08: CONFIG
                        if (reg_wr_strb[0]) reg_config[7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) reg_config[15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) reg_config[23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) reg_config[31:24] <= reg_wr_data[31:24];
                    end

                    // 0x10..0x1C: KEY_0..KEY_3
                    6'h04: begin // 0x10: KEY_0
                        if (reg_wr_strb[0]) key_words[0][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) key_words[0][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) key_words[0][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) key_words[0][31:24] <= reg_wr_data[31:24];
                    end
                    6'h05: begin // 0x14: KEY_1
                        if (reg_wr_strb[0]) key_words[1][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) key_words[1][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) key_words[1][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) key_words[1][31:24] <= reg_wr_data[31:24];
                    end
                    6'h06: begin // 0x18: KEY_2
                        if (reg_wr_strb[0]) key_words[2][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) key_words[2][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) key_words[2][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) key_words[2][31:24] <= reg_wr_data[31:24];
                    end
                    6'h07: begin // 0x1C: KEY_3
                        if (reg_wr_strb[0]) key_words[3][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) key_words[3][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) key_words[3][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) key_words[3][31:24] <= reg_wr_data[31:24];
                    end

                    // 0x20..0x2C: BLOCK_IN_0..BLOCK_IN_3
                    6'h08: begin // 0x20: BLOCK_IN_0
                        if (reg_wr_strb[0]) din_words[0][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) din_words[0][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) din_words[0][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) din_words[0][31:24] <= reg_wr_data[31:24];
                    end
                    6'h09: begin // 0x24: BLOCK_IN_1
                        if (reg_wr_strb[0]) din_words[1][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) din_words[1][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) din_words[1][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) din_words[1][31:24] <= reg_wr_data[31:24];
                    end
                    6'h0A: begin // 0x28: BLOCK_IN_2
                        if (reg_wr_strb[0]) din_words[2][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) din_words[2][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) din_words[2][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) din_words[2][31:24] <= reg_wr_data[31:24];
                    end
                    6'h0B: begin // 0x2C: BLOCK_IN_3
                        if (reg_wr_strb[0]) din_words[3][7:0]   <= reg_wr_data[7:0];
                        if (reg_wr_strb[1]) din_words[3][15:8]  <= reg_wr_data[15:8];
                        if (reg_wr_strb[2]) din_words[3][23:16] <= reg_wr_data[23:16];
                        if (reg_wr_strb[3]) din_words[3][31:24] <= reg_wr_data[31:24];
                    end

                    default: ; // Other addresses are Read-Only or Reserved
                endcase
            end
        end
    end

    //==========================================================================
    // Register Read Logic (Cryptographic Isolation & Anti-Leakage)
    //==========================================================================
    always @(*) begin
        case (reg_rd_addr[7:2])
            6'h00: reg_rd_data = {29'b0, 1'b0, core_mode, 1'b0}; // 0x00: CONTROL
            6'h01: reg_rd_data = {29'b0, status_ready, status_done, status_busy}; // 0x04: STATUS
            6'h02: reg_rd_data = reg_config; // 0x08: CONFIG
            6'h03: reg_rd_data = 32'h0;      // 0x0C: RESERVED

            // 0x10..0x1C: KEY_0..KEY_3 (Write-Only Key Protection)
            // Reads strictly return 0x0000_0000 to prevent secret extraction
            6'h04: reg_rd_data = 32'h0;
            6'h05: reg_rd_data = 32'h0;
            6'h06: reg_rd_data = 32'h0;
            6'h07: reg_rd_data = 32'h0;

            // 0x20..0x2C: BLOCK_IN_0..BLOCK_IN_3 (Plaintext/Ciphertext Input)
            6'h08: reg_rd_data = din_words[0];
            6'h09: reg_rd_data = din_words[1];
            6'h0A: reg_rd_data = din_words[2];
            6'h0B: reg_rd_data = din_words[3];

            // 0x30..0x3C: BLOCK_OUT_0..BLOCK_OUT_3 (Result Output)
            // Gated: returns valid data ONLY when operation is DONE and NOT busy
            // During execution (BUSY == 1), returns 0x0000_0000
            6'h0C: reg_rd_data = (reg_done && !core_busy) ? dout_words[0] : 32'h0;
            6'h0D: reg_rd_data = (reg_done && !core_busy) ? dout_words[1] : 32'h0;
            6'h0E: reg_rd_data = (reg_done && !core_busy) ? dout_words[2] : 32'h0;
            6'h0F: reg_rd_data = (reg_done && !core_busy) ? dout_words[3] : 32'h0;

            // Unmapped address space protection: returns 0x0000_0000
            default: reg_rd_data = 32'h0;
        endcase
    end

endmodule
