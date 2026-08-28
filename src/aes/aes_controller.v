`timescale 1ns / 1ps
//==============================================================================
// AES Controller FSM (Unified Dual-Mode Enc/Dec from Master Key K0)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Cycle-accurate FSM orchestrating AES execution for both
// Encryption (mode = 0, 10 cycles) and Decryption (mode = 1, 20 cycles)
// using the single 128-bit Master Cipher Key (K0).
//
// Timing Profile:
//   Encryption (mode = 0):
//     - Cycle 0: start pulse arrives, state <= block_in ^ K0.
//     - Cycles 1..9: Rounds 1 through 9 (forward key step K0 -> K9).
//     - Cycle 10: Round 10 (final round), done asserted, output latched.
//
//   Decryption (mode = 1):
//     - Cycle 0: start pulse arrives, save ciphertext block, load K0.
//     - Cycles 1..10 (Prep Phase): On-the-fly forward expansion K0 -> K10.
//     - End of Cycle 10: State <= ciphertext ^ K10.
//     - Cycles 11..20 (Decryption Phase): Rounds 1 through 10 (reverse step K10 -> K0).
//     - Cycle 20: Round 10 (final round), done asserted, plaintext latched.
//==============================================================================

module aes_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       mode,           // 0 = Encrypt, 1 = Decrypt
    output reg  [3:0] round_num,      // Current round index (1..10)
    output wire [3:0] key_rcon_idx,   // Rcon round index (1..10)
    output wire       key_dir_inv,    // 0 = Forward, 1 = Reverse
    output wire       is_final_round, // Asserted during round 10
    output wire       round_active,   // Datapath rounds active
    output wire       prep_active,    // Key prep phase active (for decryption)
    output wire       prep_done,      // Key prep completed at step 10
    output reg        done,           // 1-cycle completion flag
    output reg        busy            // Engine busy flag
);

    localparam S_IDLE     = 2'd0;
    localparam S_KEY_PREP = 2'd1;
    localparam S_ROUND    = 2'd2;
    localparam S_DONE     = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] prep_cnt;
    reg       mode_reg;

    assign is_final_round = (state == S_ROUND) && (round_num == 4'd10);
    assign round_active   = (state == S_ROUND);
    assign prep_active    = (state == S_KEY_PREP);
    assign prep_done      = (state == S_KEY_PREP) && (prep_cnt == 4'd10);

    // Key Expander Direction & Rcon Index:
    // - In S_KEY_PREP: Forward expansion (K0 -> K10) using prep_cnt (1..10)
    // - In S_ROUND (Encrypt): Forward expansion (K0 -> K10) using round_num (1..10)
    // - In S_ROUND (Decrypt): Reverse expansion (K10 -> K0) using (11 - round_num) (10..1)
    assign key_dir_inv  = (state == S_ROUND) ? mode_reg : 1'b0;
    assign key_rcon_idx = (state == S_KEY_PREP) ? prep_cnt :
                          (mode_reg ? (4'd11 - round_num) : round_num);

    // Sequential State Register & Counters
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            round_num <= 4'd0;
            prep_cnt  <= 4'd0;
            mode_reg  <= 1'b0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        mode_reg <= mode;
                        if (mode) begin
                            // Decryption: start forward key prep
                            prep_cnt  <= 4'd1;
                            round_num <= 4'd0;
                        end else begin
                            // Encryption: start rounds directly
                            prep_cnt  <= 4'd0;
                            round_num <= 4'd1;
                        end
                    end else begin
                        busy      <= 1'b0;
                        round_num <= 4'd0;
                        prep_cnt  <= 4'd0;
                    end
                end

                S_KEY_PREP: begin
                    busy <= 1'b1;
                    if (prep_cnt == 4'd10) begin
                        // Forward expansion K0 -> K10 complete; start decryption rounds
                        prep_cnt  <= 4'd0;
                        round_num <= 4'd1;
                    end else begin
                        prep_cnt <= prep_cnt + 4'd1;
                    end
                end

                S_ROUND: begin
                    busy <= 1'b1;
                    if (round_num == 4'd10) begin
                        // Final round completes -> assert done
                        done      <= 1'b1;
                        round_num <= 4'd0;
                    end else begin
                        done      <= 1'b0;
                        round_num <= round_num + 4'd1;
                    end
                end

                S_DONE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        mode_reg <= mode;
                        if (mode) begin
                            prep_cnt  <= 4'd1;
                            round_num <= 4'd0;
                        end else begin
                            prep_cnt  <= 4'd0;
                            round_num <= 4'd1;
                        end
                    end else begin
                        busy      <= 1'b0;
                        round_num <= 4'd0;
                        prep_cnt  <= 4'd0;
                    end
                end

                default: begin
                    state     <= S_IDLE;
                    done      <= 1'b0;
                    busy      <= 1'b0;
                    round_num <= 4'd0;
                    prep_cnt  <= 4'd0;
                    mode_reg  <= 1'b0;
                end
            endcase
        end
    end

    // Next State Combinational Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = mode ? S_KEY_PREP : S_ROUND;
                else
                    next_state = S_IDLE;
            end

            S_KEY_PREP: begin
                if (prep_cnt == 4'd10)
                    next_state = S_ROUND;
                else
                    next_state = S_KEY_PREP;
            end

            S_ROUND: begin
                if (round_num == 4'd10)
                    next_state = S_DONE;
                else
                    next_state = S_ROUND;
            end

            S_DONE: begin
                if (start)
                    next_state = mode ? S_KEY_PREP : S_ROUND;
                else
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
