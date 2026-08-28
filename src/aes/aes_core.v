`timescale 1ns / 1ps
//==============================================================================
// AES-128 Core with Round FSM
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Complete AES-128 encryption engine using iterative round architecture.
// Integrates: SubBytes, ShiftRows, MixColumns, AddRoundKey, KeyExpansion.
//
// MODIFIED from reference:
//   - Removed subbytes_out port (was for Hamming-weight side-channel monitor,
//     not needed for PS06 and would violate the security anti-leakage rule).
//   - Updated headers and project identifiers.
//
// Operation:
//   1. Assert 'start' with valid plaintext and cipher_key
//   2. FSM executes 10 AES rounds + final round
//   3. 'done' asserts when ciphertext is ready
//   4. Read ciphertext output
//
// Timing:
//   - Initial AddRoundKey: 1 cycle
//   - Rounds 1-9: 1 cycle each (SubBytes+ShiftRows+MixColumns+AddRoundKey)
//   - Round 10: 1 cycle (SubBytes+ShiftRows+AddRoundKey, NO MixColumns)
//   - Total: ~12 clock cycles from start to done
//
// FSM States:
//   IDLE:  Waiting for start signal
//   INIT:  Apply initial AddRoundKey with round_key[0]
//   ROUND: Execute rounds 1-9 (full transformation)
//   FINAL: Execute round 10 (no MixColumns)
//   DONE:  Encryption complete, ciphertext valid
//
// NIST Test Vector (FIPS 197 Appendix C.1):
//   Plaintext:  00112233445566778899aabbccddeeff
//   Key:        000102030405060708090a0b0c0d0e0f
//   Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a
//==============================================================================

module aes_core (
    input  wire         clk,           // System clock
    input  wire         rst,           // Synchronous reset (active high)
    input  wire         start,         // Start encryption (pulse)
    input  wire [127:0] plaintext,     // Input plaintext (128 bits)
    input  wire [127:0] cipher_key,    // Input cipher key (128 bits)
    output reg  [127:0] ciphertext,    // Output ciphertext (128 bits)
    output reg          done           // Encryption complete flag
);

    //==========================================================================
    // FSM State Encoding
    //==========================================================================
    localparam IDLE  = 3'b000;
    localparam INIT  = 3'b001;
    localparam ROUND = 3'b010;
    localparam FINAL = 3'b011;
    localparam DONE  = 3'b100;

    reg [2:0] state, next_state;

    //==========================================================================
    // Round Counter
    //==========================================================================
    reg [3:0] round_counter;
    wire [3:0] next_round;
    assign next_round = round_counter + 1;

    //==========================================================================
    // State Register (Holds Intermediate AES State)
    //==========================================================================
    reg [127:0] state_reg;
    reg [127:0] state_next;

    //==========================================================================
    // Key Expansion - Generate All 11 Round Keys
    //==========================================================================
    wire [127:0] round_key[0:10];
    
    aes_key_expansion key_expand (
        .cipher_key(cipher_key),
        .round_key_0(round_key[0]),
        .round_key_1(round_key[1]),
        .round_key_2(round_key[2]),
        .round_key_3(round_key[3]),
        .round_key_4(round_key[4]),
        .round_key_5(round_key[5]),
        .round_key_6(round_key[6]),
        .round_key_7(round_key[7]),
        .round_key_8(round_key[8]),
        .round_key_9(round_key[9]),
        .round_key_10(round_key[10])
    );

    //==========================================================================
    // AES Transformation Modules (Combinational)
    //==========================================================================
    wire [127:0] after_subbytes;
    wire [127:0] after_shiftrows;
    wire [127:0] after_mixcolumns;
    wire [127:0] after_addroundkey;
    
    // SubBytes transformation
    aes_subbytes subbytes_inst (
        .state_in(state_reg),
        .state_out(after_subbytes)
    );
    
    // ShiftRows transformation
    aes_shiftrows shiftrows_inst (
        .state_in(after_subbytes),
        .state_out(after_shiftrows)
    );
    
    // MixColumns transformation
    aes_mixcolumns mixcolumns_inst (
        .state_in(after_shiftrows),
        .state_out(after_mixcolumns)
    );
    
    // AddRoundKey transformation
    // Input depends on current round:
    //   - Round 10 (final): skip MixColumns, use after_shiftrows
    //   - Rounds 1-9: use after_mixcolumns
    //   - Round 0 (init): use plaintext (handled in FSM)
    wire [127:0] before_addroundkey;
    assign before_addroundkey = (state == FINAL) ? after_shiftrows : after_mixcolumns;
    
    aes_addroundkey addroundkey_inst (
        .state_in(before_addroundkey),
        .round_key(round_key[round_counter]),
        .state_out(after_addroundkey)
    );

    //==========================================================================
    // FSM Sequential Logic (State Register)
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            round_counter <= 4'd0;
            state_reg <= 128'h0;
            ciphertext <= 128'h0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Update round counter based on current state
            case (state)
                IDLE: begin
                    round_counter <= 4'd0;
                end
                INIT: begin
                    round_counter <= 4'd1;
                end
                ROUND: begin
                    if (round_counter < 4'd9)
                        round_counter <= next_round;
                    else
                        round_counter <= 4'd10;
                end
                FINAL: begin
                    round_counter <= 4'd10;
                end
                default: begin
                    round_counter <= round_counter;
                end
            endcase
            
            done <= (state == FINAL);
            
            // Update state register
            state_reg <= state_next;
            
            // Capture final ciphertext when ENTERING DONE state
            if (next_state == DONE) begin
                ciphertext <= state_next;
            end
        end
    end

    //==========================================================================
    // FSM Combinational Logic (Next State + Data Path)
    //==========================================================================
    always @(*) begin
        // Default: maintain current state
        next_state = state;
        state_next = state_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    state_next = plaintext;
                end else begin
                    state_next = 128'h0;
                end
            end
            
            INIT: begin
                // Initial AddRoundKey with round_key[0]
                next_state = ROUND;
                state_next = plaintext ^ round_key[0];
            end
            
            ROUND: begin
                // Rounds 1-9: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
                state_next = after_addroundkey;
                
                if (round_counter == 4'd9) begin
                    next_state = FINAL;
                end else begin
                    next_state = ROUND;
                end
            end
            
            FINAL: begin
                // Round 10: SubBytes -> ShiftRows -> AddRoundKey (NO MixColumns)
                state_next = after_addroundkey;
                next_state = DONE;
            end
            
            DONE: begin
                if (start) begin
                    next_state = INIT;
                    state_next = plaintext;
                end else begin
                    next_state = DONE;
                    state_next = state_reg;
                end
            end
            
            default: begin
                next_state = IDLE;
                state_next = 128'h0;
            end
        endcase
    end

endmodule
