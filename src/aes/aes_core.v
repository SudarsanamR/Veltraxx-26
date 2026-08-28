`timescale 1ns / 1ps
//==============================================================================
// AES-128 Unified Iterative Core (Dual-Mode Enc/Dec, Folded Shared Datapath)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Highly resource-optimized, synthesizable AES-128 core featuring:
//   1. < 1,500 4-input LUT budget on Xilinx 7-series FPGA via S-Box folding.
//   2. 10-cycle Initiation Interval (II = 10) for 1.28 Gbps @ 100MHz.
//   3. Full NIST FIPS-197 compliance for both Encryption and Decryption.
//   4. On-The-Fly Key Expansion (uses only 4 S-boxes total, zero BRAM).
//   5. Cryptographic isolation (intermediate states strictly private).
//==============================================================================

module aes_core (
    input  wire         clk,          // System clock
    input  wire         rst,          // Synchronous reset (active high)
    input  wire         start,        // Start trigger (1-cycle pulse)
    input  wire         mode,         // 0 = Encryption, 1 = Decryption
    input  wire [127:0] key,          // 128-bit Cipher Key (K0 for Enc, K10 for Dec)
    input  wire [127:0] block_in,     // 128-bit Input Block (Plaintext or Ciphertext)
    output reg  [127:0] block_out,    // 128-bit Output Block (Ciphertext or Plaintext)
    output wire         done,         // 1-cycle completion pulse
    output wire         busy          // 1 when encryption/decryption in progress
);

    //==========================================================================
    // Controller FSM
    //==========================================================================
    wire [3:0] round_num;
    wire [3:0] key_rcon_idx;
    wire       is_final_round;
    wire       round_active;

    aes_controller ctrl_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode(mode),
        .round_num(round_num),
        .key_rcon_idx(key_rcon_idx),
        .is_final_round(is_final_round),
        .round_active(round_active),
        .done(done),
        .busy(busy)
    );

    //==========================================================================
    // State & Key Registers
    //==========================================================================
    reg [127:0] state_reg;
    reg [127:0] key_reg;

    //==========================================================================
    // On-The-Fly Key Expander (4 S-Boxes total)
    //==========================================================================
    wire [127:0] next_key;

    aes_key_expand key_exp_inst (
        .dir_inv(mode),
        .round_idx(key_rcon_idx),
        .key_in(key_reg),
        .key_out(next_key)
    );

    //==========================================================================
    // Folded Shared Datapath (16 Shared S-Boxes Total)
    //==========================================================================
    // In Encryption: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
    // In Decryption: InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
    
    // Decryption pre-shift:
    wire [127:0] dec_inv_shiftrows_out;
    aes_inv_shiftrows dec_inv_shiftrows_inst (
        .state_in(state_reg),
        .state_out(dec_inv_shiftrows_out)
    );

    // Shared SubBytes input multiplexer:
    wire [127:0] subbytes_in = mode ? dec_inv_shiftrows_out : state_reg;
    wire [127:0] subbytes_out;

    aes_subbytes_shared shared_subbytes_inst (
        .is_inv(mode),
        .state_in(subbytes_in),
        .state_out(subbytes_out)
    );

    // Encryption post-shift and post-mix:
    wire [127:0] enc_shiftrows_out;
    aes_shiftrows enc_shiftrows_inst (
        .state_in(subbytes_out),
        .state_out(enc_shiftrows_out)
    );

    wire [127:0] enc_mixcolumns_out;
    aes_mixcolumns enc_mixcolumns_inst (
        .state_in(enc_shiftrows_out),
        .state_out(enc_mixcolumns_out)
    );

    wire [127:0] enc_before_key = is_final_round ? enc_shiftrows_out : enc_mixcolumns_out;
    wire [127:0] enc_next_state = enc_before_key ^ next_key;

    // Decryption post-key and post-mix:
    wire [127:0] dec_after_key = subbytes_out ^ next_key;
    wire [127:0] dec_inv_mixcolumns_out;
    aes_inv_mixcolumns dec_inv_mixcolumns_inst (
        .state_in(dec_after_key),
        .state_out(dec_inv_mixcolumns_out)
    );

    wire [127:0] dec_next_state = is_final_round ? dec_after_key : dec_inv_mixcolumns_out;

    // Unified Next State:
    wire [127:0] round_next_state = mode ? dec_next_state : enc_next_state;

    //==========================================================================
    // Sequential Datapath Logic
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state_reg <= 128'h0;
            key_reg   <= 128'h0;
            block_out <= 128'h0;
        end else begin
            if (start) begin
                // Cycle 0: Initial AddRoundKey (K0 for Enc, K10 for Dec)
                state_reg <= block_in ^ key;
                key_reg   <= key;
            end else if (round_active) begin
                // Cycles 1 to 10: Step state and key synchronously
                state_reg <= round_next_state;
                key_reg   <= next_key;
                
                // Latch final result at round 10
                if (is_final_round) begin
                    block_out <= round_next_state;
                end
            end
        end
    end

endmodule
