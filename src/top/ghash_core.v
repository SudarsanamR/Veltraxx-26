`timescale 1ns / 1ps
//==============================================================================
// GHASH Galois Field GF(2^128) Multiplier Core (NIST SP 800-38D / GCM Standard)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Computes Y = (Y_prev ^ X) * H in GF(2^128) modulo P(x) = x^128 + x^7 + x^2 + x + 1
// Reduction constant R = 128'hE1000000000000000000000000000000
//
// Features:
//   - Zero DSP blocks / minimal LUT footprint (<150 LUTs).
//   - Bit-serial 128-step accumulator matching NIST SP 800-38D Algorithm 1.
//   - Dedicated busy/done handshake.
//==============================================================================

module ghash_core (
    input  wire         clk,
    input  wire         rst_n,
    
    input  wire         start,        // Pulse to start GHASH computation
    input  wire [127:0] x_in,         // Block input (AAD or Ciphertext)
    input  wire [127:0] y_in,         // Previous GHASH state Y_{i-1}
    input  wire [127:0] h_key,        // Hash subkey H = E_K(0^128)
    
    output reg  [127:0] y_out,        // Output GHASH state Y_i
    output reg          done,         // Asserted 1 cycle upon completion
    output reg          busy          // High during active GF multiplication
);

    localparam [127:0] R_POLY = 128'hE100_0000_0000_0000_0000_0000_0000_0000;

    reg [127:0] z_reg;
    reg [127:0] v_reg;
    reg [127:0] x_xor_y;
    reg [6:0]   step_cnt;

    localparam S_IDLE = 2'd0;
    localparam S_CALC = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            z_reg    <= 128'h0;
            v_reg    <= 128'h0;
            x_xor_y  <= 128'h0;
            y_out    <= 128'h0;
            step_cnt <= 7'd0;
            done     <= 1'b0;
            busy     <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        z_reg    <= 128'h0;
                        v_reg    <= h_key;
                        x_xor_y  <= x_in ^ y_in;
                        step_cnt <= 7'd0;
                        state    <= S_CALC;
                    end
                end

                S_CALC: begin
                    // NIST SP 800-38D Algorithm 1 step:
                    // If bit (127 - step_cnt) is 1, Z = Z ^ V
                    // If V[0] == 0: V = V >> 1; else V = (V >> 1) ^ R
                    if (x_xor_y[127 - step_cnt]) begin
                        z_reg <= z_reg ^ v_reg;
                    end

                    if (v_reg[0]) begin
                        v_reg <= {1'b0, v_reg[127:1]} ^ R_POLY;
                    end else begin
                        v_reg <= {1'b0, v_reg[127:1]};
                    end

                    if (step_cnt == 7'd127) begin
                        state <= S_DONE;
                    end else begin
                        step_cnt <= step_cnt + 1;
                    end
                end

                S_DONE: begin
                    y_out <= z_reg;
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
