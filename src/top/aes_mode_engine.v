`timescale 1ns / 1ps
//==============================================================================
// AES Multi-Mode Operating Subsystem (ECB, CBC, CFB, OFB, CTR, GCM)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Supports all 6 NIST Operating Modes:
//   - Mode 0: ECB (Electronic Codebook - NIST SP 800-38A)
//   - Mode 1: CBC (Cipher Block Chaining - NIST SP 800-38A)
//   - Mode 2: CFB (Cipher Feedback - NIST SP 800-38A)
//   - Mode 3: OFB (Output Feedback - NIST SP 800-38A)
//   - Mode 4: CTR (Counter Mode - NIST SP 800-38A)
//   - Mode 5: GCM (Galois/Counter Mode AEAD - NIST SP 800-38D)
//==============================================================================

module aes_mode_engine (
    input  wire         clk,
    input  wire         rst_n,

    // Host / Control Interface
    input  wire [2:0]   mode_sel,     // 0:ECB, 1:CBC, 2:CFB, 3:OFB, 4:CTR, 5:GCM
    input  wire         op_dir,       // 0 = Encrypt, 1 = Decrypt
    input  wire         start_req,    // Start transformation on input block
    input  wire         reset_state,  // Reset IV / Counters / Feedback registers
    input  wire         load_iv,      // Strobe to load iv_in into internal IV/counter register
    input  wire         load_aad,     // Strobe to load and hash AAD block (GCM)
    input  wire         gen_tag_req,  // Strobe to compute final GCM Tag T

    input  wire [127:0] block_in,     // Incoming 128-bit block
    input  wire [127:0] iv_in,        // 128-bit IV / Nonce input
    input  wire [127:0] key_in,       // 128-bit Key input

    output reg  [127:0] block_out,    // Transformed 128-bit result
    output reg  [127:0] tag_out,      // 128-bit GCM Authentication Tag
    output reg          done,         // Asserted when block transformation complete
    output reg          busy,         // High during active multi-step operation

    // Core Interface to aes_axi_top (or internal AXI master bridge)
    output reg          core_req_start,
    output reg          core_req_mode, // 0:Enc, 1:Dec
    output reg  [127:0] core_req_din,
    input  wire [127:0] core_resp_dout,
    input  wire         core_resp_done
);

    // Internal State Registers
    reg [127:0] iv_reg;
    reg [127:0] feedback_reg;
    reg [127:0] counter_reg;
    reg [127:0] h_subkey;       // H = E_K(0^128) for GCM
    reg [127:0] j0_masked;      // E_K(J0) for GCM Tag
    reg [127:0] ghash_accum;    // Accumulator for GCM GHASH

    // GHASH Module Interface
    reg         ghash_start;
    reg  [127:0] ghash_x_in;
    wire [127:0] ghash_y_out;
    wire        ghash_done;
    wire        ghash_busy;

    ghash_core ghash_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ghash_start),
        .x_in(ghash_x_in),
        .y_in(ghash_accum),
        .h_key(h_subkey),
        .y_out(ghash_y_out),
        .done(ghash_done),
        .busy(ghash_busy)
    );

    // State Machine
    localparam S_IDLE       = 4'd0;
    localparam S_INIT_H     = 4'd1;  // GCM: Compute H = E_K(0^128)
    localparam S_WAIT_H     = 4'd2;
    localparam S_INIT_J0    = 4'd3;  // GCM: Compute E_K(J0)
    localparam S_WAIT_J0    = 4'd4;
    localparam S_CORE_START = 4'd5;
    localparam S_CORE_WAIT  = 4'd6;
    localparam S_GHASH_RUN  = 4'd7;
    localparam S_GHASH_WAIT = 4'd8;
    localparam S_FINISH     = 4'd9;

    reg [3:0] state;
    reg [127:0] pending_in;
    reg         h_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            iv_reg         <= 128'h0;
            feedback_reg   <= 128'h0;
            counter_reg    <= 128'h0;
            h_subkey       <= 128'h0;
            j0_masked      <= 128'h0;
            ghash_accum    <= 128'h0;
            block_out      <= 128'h0;
            tag_out        <= 128'h0;
            done           <= 1'b0;
            busy           <= 1'b0;
            core_req_start <= 1'b0;
            core_req_mode  <= 1'b0;
            core_req_din   <= 128'h0;
            ghash_start    <= 1'b0;
            ghash_x_in     <= 128'h0;
            pending_in     <= 128'h0;
            h_valid        <= 1'b0;
        end else begin
            done           <= 1'b0;
            core_req_start <= 1'b0;
            ghash_start    <= 1'b0;

            if (reset_state) begin
                feedback_reg <= iv_reg;
                counter_reg  <= (mode_sel == 3'd5) ? {iv_reg[127:32], 32'd2} : iv_reg;
                ghash_accum  <= 128'h0;
                h_valid      <= 1'b0;
            end else if (load_iv) begin
                iv_reg       <= iv_in;
                feedback_reg <= iv_in;
                // For GCM with 96-bit IV: J0 = IV || 0x00000001; payload counter starts at J1 = IV || 0x00000002
                counter_reg  <= (mode_sel == 3'd5) ? {iv_in[127:32], 32'd2} : iv_in;
                ghash_accum  <= 128'h0;
            end

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_req) begin
                        busy       <= 1'b1;
                        pending_in <= block_in;

                        if (mode_sel == 3'd5 && !h_valid) begin
                            // GCM: Must compute H = E_K(0^128) first
                            core_req_din   <= 128'h0;
                            core_req_mode  <= 1'b0; // Encrypt
                            core_req_start <= 1'b1;
                            state          <= S_WAIT_H;
                        end else if (mode_sel == 3'd5 && j0_masked == 128'h0) begin
                            // GCM: Must compute E_K(J0)
                            core_req_din   <= {iv_reg[127:32], 32'd1};
                            core_req_mode  <= 1'b0;
                            core_req_start <= 1'b1;
                            state          <= S_WAIT_J0;
                        end else begin
                            state <= S_CORE_START;
                        end
                    end else if (load_aad && mode_sel == 3'd5) begin
                        // AAD block: feed directly into GHASH
                        busy        <= 1'b1;
                        ghash_x_in  <= block_in;
                        ghash_start <= 1'b1;
                        state       <= S_GHASH_WAIT;
                    end else if (gen_tag_req && mode_sel == 3'd5) begin
                        // GCM Final Tag T = GHASH(AAD, C) ^ E_K(J0)
                        busy    <= 1'b1;
                        tag_out <= ghash_accum ^ j0_masked;
                        done    <= 1'b1;
                        state   <= S_IDLE;
                    end
                end

                S_WAIT_H: begin
                    if (core_resp_done) begin
                        h_subkey <= core_resp_dout;
                        h_valid  <= 1'b1;
                        // Now compute E_K(J0)
                        core_req_din   <= {iv_reg[127:32], 32'd1};
                        core_req_mode  <= 1'b0;
                        core_req_start <= 1'b1;
                        state          <= S_WAIT_J0;
                    end
                end

                S_WAIT_J0: begin
                    if (core_resp_done) begin
                        j0_masked <= core_resp_dout;
                        state     <= S_CORE_START;
                    end
                end

                S_CORE_START: begin
                    case (mode_sel)
                        3'd0: begin // ECB
                            core_req_din   <= pending_in;
                            core_req_mode  <= op_dir;
                            core_req_start <= 1'b1;
                        end
                        3'd1: begin // CBC
                            core_req_din   <= op_dir ? pending_in : (pending_in ^ feedback_reg);
                            core_req_mode  <= op_dir;
                            core_req_start <= 1'b1;
                        end
                        3'd2: begin // CFB
                            core_req_din   <= feedback_reg;
                            core_req_mode  <= 1'b0; // Always Encrypt in CFB
                            core_req_start <= 1'b1;
                        end
                        3'd3: begin // OFB
                            core_req_din   <= feedback_reg;
                            core_req_mode  <= 1'b0; // Always Encrypt in OFB
                            core_req_start <= 1'b1;
                        end
                        3'd4: begin // CTR
                            core_req_din   <= counter_reg;
                            core_req_mode  <= 1'b0; // Always Encrypt in CTR
                            core_req_start <= 1'b1;
                        end
                        3'd5: begin // GCM (uses CTR)
                            core_req_din   <= counter_reg;
                            core_req_mode  <= 1'b0;
                            core_req_start <= 1'b1;
                        end
                        default: begin
                            core_req_din   <= pending_in;
                            core_req_mode  <= op_dir;
                            core_req_start <= 1'b1;
                        end
                    endcase
                    state <= S_CORE_WAIT;
                end

                S_CORE_WAIT: begin
                    if (core_resp_done) begin
                        case (mode_sel)
                            3'd0: begin // ECB
                                block_out <= core_resp_dout;
                                done      <= 1'b1;
                                state     <= S_IDLE;
                            end

                            3'd1: begin // CBC
                                if (op_dir == 1'b0) begin // Encrypt
                                    block_out    <= core_resp_dout;
                                    feedback_reg <= core_resp_dout;
                                end else begin // Decrypt
                                    block_out    <= core_resp_dout ^ feedback_reg;
                                    feedback_reg <= pending_in;
                                end
                                done  <= 1'b1;
                                state <= S_IDLE;
                            end

                            3'd2: begin // CFB
                                block_out <= pending_in ^ core_resp_dout;
                                if (op_dir == 1'b0)
                                    feedback_reg <= pending_in ^ core_resp_dout;
                                else
                                    feedback_reg <= pending_in;
                                done  <= 1'b1;
                                state <= S_IDLE;
                            end

                            3'd3: begin // OFB
                                block_out    <= pending_in ^ core_resp_dout;
                                feedback_reg <= core_resp_dout;
                                done         <= 1'b1;
                                state        <= S_IDLE;
                            end

                            3'd4: begin // CTR
                                block_out   <= pending_in ^ core_resp_dout;
                                counter_reg <= counter_reg + 128'd1;
                                done        <= 1'b1;
                                state       <= S_IDLE;
                            end

                            3'd5: begin // GCM
                                block_out   <= pending_in ^ core_resp_dout;
                                counter_reg <= counter_reg + 128'd1;
                                // Feed ciphertext into GHASH
                                ghash_x_in  <= (op_dir == 1'b0) ? (pending_in ^ core_resp_dout) : pending_in;
                                ghash_start <= 1'b1;
                                state       <= S_GHASH_RUN;
                            end

                            default: begin
                                block_out <= core_resp_dout;
                                done      <= 1'b1;
                                state     <= S_IDLE;
                            end
                        endcase
                    end
                end

                S_GHASH_RUN: begin
                    state <= S_GHASH_WAIT;
                end

                S_GHASH_WAIT: begin
                    if (ghash_done) begin
                        ghash_accum <= ghash_y_out;
                        tag_out     <= ghash_y_out ^ j0_masked;
                        done        <= 1'b1;
                        state       <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
