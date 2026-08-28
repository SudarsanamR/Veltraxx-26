`timescale 1ns / 1ps
//==============================================================================
// AES Memory-Mapped Register Bank (Cryptographic Isolation & Area-Optimized)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Implements 32-bit registers mapped into the 4KB AXI slave aperture.
//
// Register Map:
//   0x00: CONTROL   [0]=START, [1]=MODE (0=Enc, 1=Dec), [2]=CORE_RESET
//   0x04: STATUS    [0]=BUSY, [1]=DONE, [2]=READY (W1C bit 1 to clear DONE)
//   0x08: CONFIG    General-purpose scratch/config register
//   0x0C: RESERVED
//   0x10..0x1C: KEY_0..KEY_3       (128-bit Key, Write-Only security)
//   0x20..0x2C: BLOCK_IN_0..IN_3   (128-bit Plaintext/Ciphertext Input)
//   0x30..0x3C: BLOCK_OUT_0..OUT_3 (128-bit Result, gated during execution)
//
// Security & Anti-Leakage Rules:
//   1. Zero intermediate state exposure (strictly inside aes_core).
//   2. Write-only key registers (reads return 0x0000_0000).
//   3. Output registers gated (return 0x0000_0000 while core is BUSY).
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
    reg        reg_done;

    // Word concatenation to 128-bit AES vectors
    assign core_key      = {key_words[0], key_words[1], key_words[2], key_words[3]};
    assign core_block_in = {din_words[0], din_words[1], din_words[2], din_words[3]};

    // Status flags
    wire status_busy  = core_busy;
    wire status_done  = reg_done;
    wire status_ready = !core_busy;

    // Direct slice of core_block_out for output read (eliminates 128 redundant FFs)
    wire [1:0] word_idx = reg_rd_addr[3:2];
    wire [31:0] core_out_word = (word_idx == 2'h0) ? core_block_out[127:96] :
                                (word_idx == 2'h1) ? core_block_out[95:64]  :
                                (word_idx == 2'h2) ? core_block_out[63:32]  :
                                                     core_block_out[31:0];

    //==========================================================================
    // Register Write Logic
    //==========================================================================
    integer i, b;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_start <= 1'b0;
            core_mode  <= 1'b0;
            core_rst   <= 1'b0;
            reg_config <= 32'h0;
            reg_done   <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                key_words[i]  <= 32'h0;
                din_words[i]  <= 32'h0;
            end
        end else begin
            core_start <= 1'b0;
            core_rst   <= 1'b0;

            if (core_done) begin
                reg_done <= 1'b1;
            end

            if (reg_wr_en) begin
                case (reg_wr_addr[7:4])
                    4'h0: begin
                        case (reg_wr_addr[3:2])
                            2'h0: begin // 0x00: CONTROL
                                if (reg_wr_strb[0]) begin
                                    core_start <= reg_wr_data[0];
                                    core_mode  <= reg_wr_data[1];
                                    core_rst   <= reg_wr_data[2];
                                    if (reg_wr_data[0]) reg_done <= 1'b0;
                                end
                            end
                            2'h1: begin // 0x04: STATUS (W1C done flag)
                                if (reg_wr_strb[0] && reg_wr_data[1]) reg_done <= 1'b0;
                            end
                            2'h2: begin // 0x08: CONFIG
                                for (b = 0; b < 4; b = b + 1) begin
                                    if (reg_wr_strb[b]) reg_config[b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                                end
                            end
                            default: ;
                        endcase
                    end
                    4'h1: begin // 0x10..0x1C: KEY_0..KEY_3
                        for (b = 0; b < 4; b = b + 1) begin
                            if (reg_wr_strb[b]) key_words[reg_wr_addr[3:2]][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                        end
                    end
                    4'h2: begin // 0x20..0x2C: BLOCK_IN_0..BLOCK_IN_3
                        for (b = 0; b < 4; b = b + 1) begin
                            if (reg_wr_strb[b]) din_words[reg_wr_addr[3:2]][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    //==========================================================================
    // Register Read Logic (Cryptographic Isolation & Anti-Leakage)
    //==========================================================================
    wire out_valid = reg_done && !core_busy;

    always @(*) begin
        reg_rd_data = 32'h0;
        case (reg_rd_addr[7:4])
            4'h0: begin // 0x00..0x0F
                case (word_idx)
                    2'h0: reg_rd_data = {29'b0, 1'b0, core_mode, 1'b0};
                    2'h1: reg_rd_data = {29'b0, status_ready, status_done, status_busy};
                    2'h2: reg_rd_data = reg_config;
                    default: reg_rd_data = 32'h0;
                endcase
            end
            4'h1: reg_rd_data = 32'h0; // 0x10..0x1F: Write-Only Key
            4'h2: reg_rd_data = din_words[word_idx]; // 0x20..0x2F: Input
            4'h3: reg_rd_data = out_valid ? core_out_word : 32'h0; // 0x30..0x3F: Output (gated)
            default: reg_rd_data = 32'h0;
        endcase
    end

endmodule
