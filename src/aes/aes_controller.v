`timescale 1ns / 1ps
//==============================================================================
// AES Controller FSM (10-Cycle Initiation Interval)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Cycle-accurate FSM orchestrating 10-round AES execution for both
// Encryption (mode = 0) and Decryption (mode = 1).
//
// Initiation Interval (II): Exactly 10 clock cycles.
// Latency: Exactly 10 clock cycles from start pulse to done pulse.
//
// Timing Profile:
//   Cycle 0 (T0): start pulse arrives. State <= block_in ^ key.
//   Cycles 1..9 (T1..T9): Rounds 1 through 9.
//   Cycle 10 (T10): Round 10 (final round), done asserted, output latched.
//==============================================================================

module aes_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       mode,           // 0 = Encrypt, 1 = Decrypt
    output reg  [3:0] round_num,      // Current round index (1..10)
    output wire [3:0] key_rcon_idx,   // Rcon round index (1..10)
    output wire       is_final_round, // Asserted during round 10
    output wire       round_active,   // Engine actively processing rounds
    output reg        done,           // 1-cycle completion flag
    output reg        busy            // Engine busy flag
);

    localparam S_IDLE  = 2'd0;
    localparam S_ROUND = 2'd1;
    localparam S_DONE  = 2'd2;

    reg [1:0] state, next_state;

    assign is_final_round = (state == S_ROUND) && (round_num == 4'd10);
    assign round_active   = (state == S_ROUND);

    // Key Rcon index:
    // For Encrypt (mode=0): steps K_{r-1} -> K_r, using Rcon[round_num] (1..10)
    // For Decrypt (mode=1): steps K_r -> K_{r-1}, using Rcon[11 - round_num] (10..1)
    assign key_rcon_idx   = mode ? (4'd11 - round_num) : round_num;

    // Sequential State Register & Round Counter
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            round_num <= 4'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy      <= 1'b1;
                        round_num <= 4'd1;
                    end else begin
                        busy      <= 1'b0;
                        round_num <= 4'd0;
                    end
                end

                S_ROUND: begin
                    busy <= 1'b1;
                    if (round_num == 4'd10) begin
                        // Round 10 completes on this cycle -> assert done
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
                        busy      <= 1'b1;
                        round_num <= 4'd1;
                    end else begin
                        busy      <= 1'b0;
                        round_num <= 4'd0;
                    end
                end

                default: begin
                    state     <= S_IDLE;
                    done      <= 1'b0;
                    busy      <= 1'b0;
                    round_num <= 4'd0;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_ROUND;
                else
                    next_state = S_IDLE;
            end

            S_ROUND: begin
                if (round_num == 4'd10)
                    next_state = S_DONE;
                else
                    next_state = S_ROUND;
            end

            S_DONE: begin
                if (start)
                    next_state = S_ROUND;
                else
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
