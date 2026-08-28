`timescale 1ns / 1ps
//==============================================================================
// AES-128 Unified Iterative Core (Key-Ahead Architecture, II=10)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Key innovation: the round key is computed ONE CYCLE AHEAD and registered
// in key_reg. During the START cycle, K1 (or K9 for dec) is computed from the
// input key and registered. Each subsequent round uses key_reg (pre-computed)
// for AddRoundKey while simultaneously computing the NEXT round key.
//
// Mode signal is locally cached on start with max_fanout constraint to
// eliminate inter-module cross-hierarchy routing delay and achieve positive WNS.
//==============================================================================

module aes_core (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire         mode,         // 0 = Encrypt, 1 = Decrypt
    input  wire [127:0] key,
    input  wire [127:0] block_in,
    output reg  [127:0] block_out,
    output wire         done,
    output wire         busy
);

    //==========================================================================
    // Controller FSM
    //==========================================================================
    wire [3:0] round_num;
    wire       is_final_round;
    wire       round_active;

    aes_controller ctrl_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode(mode),
        .round_num(round_num),
        .key_rcon_idx(),       // Not used — computed in key-ahead unit
        .is_final_round(is_final_round),
        .round_active(round_active),
        .done(done),
        .busy(busy)
    );

    //==========================================================================
    // State, Key, and Mode Registers
    //==========================================================================
    reg [127:0] state_reg;
    reg [127:0] key_reg;   // Holds the CURRENT round's key (pre-computed)

    (* max_fanout = 16 *)
    reg         cached_mode;

    // Active mode: during start cycle use incoming mode; during execution use cached_mode
    wire active_mode = start ? mode : cached_mode;

    //==========================================================================
    // Key-Ahead Rcon Index Computation
    //==========================================================================
    // Key expansion runs one step ahead:
    //   At START:    compute K1 from input key using Rcon[1] (enc) / K9 from K10 using Rcon[10] (dec)
    //   At round r:  compute K_{r+1} using Rcon[r+1] (enc) / K_{10-r-1} using Rcon[10-r] (dec)
    wire [3:0] ahead_rcon_enc = round_num + 4'd1;             // 0+1=1, 1+1=2, ..., 9+1=10
    wire [3:0] ahead_rcon_dec = 4'd10 - round_num;            // 10-0=10, 10-1=9, ..., 10-9=1
    wire [3:0] key_rcon_idx   = active_mode ? ahead_rcon_dec : ahead_rcon_enc;

    //==========================================================================
    // On-The-Fly Key Expander (4 S-Boxes, OFF critical path)
    //==========================================================================
    // During START: input is the raw key; during ROUND: input is key_reg
    wire [127:0] key_exp_in = start ? key : key_reg;
    wire [127:0] next_key;

    aes_key_expand key_exp_inst (
        .dir_inv(active_mode),
        .round_idx(key_rcon_idx),
        .key_in(key_exp_in),
        .key_out(next_key)
    );

    //==========================================================================
    // Folded Shared Datapath (16 Shared S-Boxes Total)
    //==========================================================================
    // AddRoundKey uses key_reg (REGISTERED, pre-computed) — NOT next_key!

    wire [127:0] dec_inv_shiftrows_out;
    aes_inv_shiftrows dec_inv_shiftrows_inst (
        .state_in(state_reg),
        .state_out(dec_inv_shiftrows_out)
    );

    wire [127:0] subbytes_in = cached_mode ? dec_inv_shiftrows_out : state_reg;
    wire [127:0] subbytes_out;

    aes_subbytes_shared shared_subbytes_inst (
        .is_inv(cached_mode),
        .state_in(subbytes_in),
        .state_out(subbytes_out)
    );

    wire [127:0] enc_shiftrows_out;
    aes_shiftrows enc_shiftrows_inst (
        .state_in(subbytes_out),
        .state_out(enc_shiftrows_out)
    );

    // AddRoundKey uses key_reg (pre-computed, registered, OFF critical path)
    wire [127:0] dec_after_key = subbytes_out ^ key_reg;
    wire [127:0] mix_in = cached_mode ? dec_after_key : enc_shiftrows_out;
    wire [127:0] mix_out;

    aes_mixcolumns_shared shared_mixcolumns_inst (
        .is_inv(cached_mode),
        .state_in(mix_in),
        .state_out(mix_out)
    );

    wire [127:0] enc_before_key = is_final_round ? enc_shiftrows_out : mix_out;
    wire [127:0] enc_next_state = enc_before_key ^ key_reg;
    wire [127:0] dec_next_state = is_final_round ? dec_after_key : mix_out;

    wire [127:0] round_next_state = cached_mode ? dec_next_state : enc_next_state;

    //==========================================================================
    // Sequential Datapath Logic
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state_reg   <= 128'h0;
            key_reg     <= 128'h0;
            block_out   <= 128'h0;
            cached_mode <= 1'b0;
        end else begin
            if (start) begin
                // Cycle 0: Initial AddRoundKey + key-ahead computation
                state_reg   <= block_in ^ key;
                key_reg     <= next_key;
                cached_mode <= mode;
            end else if (round_active) begin
                // Rounds 1-10: use key_reg (pre-computed) for AddRoundKey
                state_reg <= round_next_state;
                
                // Advance key: register next_key for the FOLLOWING round
                if (!is_final_round)
                    key_reg <= next_key;

                // Latch final result
                if (is_final_round)
                    block_out <= round_next_state;
            end
        end
    end

endmodule
