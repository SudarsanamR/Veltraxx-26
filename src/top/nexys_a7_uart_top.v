`timescale 1ns / 1ps
//==============================================================================
// Nexys A7 FPGA Top-Level Interactive Hardware Demo Wrapper
// PS06 AES-128 AXI-MM Hardware Accelerator with 6-Mode Operating Subsystem
// VELTRAXX '26
//==============================================================================
// Supported Operating Modes:
//   - Mode 0: ECB (Electronic Codebook - NIST SP 800-38A)
//   - Mode 1: CBC (Cipher Block Chaining - NIST SP 800-38A)
//   - Mode 2: CFB (Cipher Feedback - NIST SP 800-38A)
//   - Mode 3: OFB (Output Feedback - NIST SP 800-38A)
//   - Mode 4: CTR (Counter Mode - NIST SP 800-38A)
//   - Mode 5: GCM (Galois/Counter Mode AEAD - NIST SP 800-38D)
//
// UART Protocol Commands:
//   'M' + <0..5> + '\n'        -> Set active cipher mode
//   'I' + <32-hex IV> + '\n'   -> Load 128-bit IV / Nonce
//   'A' + <32-hex AAD> + '\n'  -> Load and hash 128-bit AAD (GCM)
//   'K' + <32-hex Key> + '\n'  -> Load 128-bit Key
//   'E' + <32-hex PT> + '\n'   -> Encrypt 128-bit block in active mode
//   'D' + <32-hex CT> + '\n'   -> Decrypt 128-bit block in active mode
//   'G' + '\n'                 -> Request 128-bit GCM Authentication Tag T
//   'R' + '\n'                 -> Reset IV, Feedback, and Counter
//   'T' + '\n'                 -> Run NIST Appendix C.1 Hardware Test
//==============================================================================

module nexys_a7_uart_top #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,            // 100 MHz Oscillator (Pin E3)
    input  wire        reset_n,        // Active-Low CPU Reset (Pin C12)
    
    // USB-UART Interface (Nexys A7 FTDI Bridge)
    input  wire        uart_rx,        // UART RX from PC (Pin C4)
    output wire        uart_tx,        // UART TX to PC (Pin D4)
    
    // Pushbuttons & Switches
    input  wire        btn_c,          // Center Button (Pin N17): Run NIST Test
    input  wire [1:0]  sw,             // Switches SW[1:0] (Word Select)
    
    // 16 Onboard LEDs
    output wire [15:0] led,
    
    // 8-Digit 7-Segment Display
    output wire [7:0]  an,             // Digit Anodes (Active Low)
    output wire [6:0]  seg,            // Segment Cathodes (CA..CG, Active Low)
    output wire        dp              // Decimal Point (Active Low)
);

    //==========================================================================
    // Reset Synchronizer
    //==========================================================================
    reg [2:0] rst_sync;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            rst_sync <= 3'b000;
        else
            rst_sync <= {rst_sync[1:0], 1'b1};
    end
    wire sys_rst_n = rst_sync[2];
    wire sys_rst   = !sys_rst_n;

    //==========================================================================
    // UART Receiver (Robust 3-State Center-Sampling Engine)
    //==========================================================================
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_byte_buf;
    reg        rx_valid;
    reg [7:0]  rx_data;
    reg [1:0]  rx_sync;

    always @(posedge clk) rx_sync <= {rx_sync[0], uart_rx};
    wire rx_in = rx_sync[1];

    always @(posedge clk) begin
        if (sys_rst) begin
            rx_state    <= RX_IDLE;
            rx_clk_cnt  <= 0;
            rx_bit_idx  <= 0;
            rx_byte_buf <= 0;
            rx_valid    <= 0;
            rx_data     <= 0;
        end else begin
            rx_valid <= 0;
            case (rx_state)
                RX_IDLE: begin
                    rx_clk_cnt <= 0;
                    rx_bit_idx <= 0;
                    if (!rx_in)
                        rx_state <= RX_START;
                end

                RX_START: begin
                    if (rx_clk_cnt >= (CLKS_PER_BIT / 2) - 1) begin
                        rx_clk_cnt <= 0;
                        if (!rx_in)
                            rx_state <= RX_DATA;
                        else
                            rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        rx_clk_cnt              <= 0;
                        rx_byte_buf[rx_bit_idx] <= rx_in;
                        if (rx_bit_idx == 3'd7) begin
                            rx_bit_idx <= 0;
                            rx_state   <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        rx_state   <= RX_IDLE;
                        if (rx_in) begin
                            rx_valid <= 1'b1;
                            rx_data  <= rx_byte_buf;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // UART Transmitter (Robust 4-State Serializer)
    //==========================================================================
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_idx;
    reg [7:0]  tx_data_buf;
    reg        tx_busy;
    reg        tx_start;
    reg [7:0]  tx_byte;
    reg        tx_out_reg;

    assign uart_tx = tx_out_reg;

    always @(posedge clk) begin
        if (sys_rst) begin
            tx_state    <= TX_IDLE;
            tx_clk_cnt  <= 0;
            tx_bit_idx  <= 0;
            tx_data_buf <= 0;
            tx_busy     <= 0;
            tx_out_reg  <= 1'b1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_out_reg <= 1'b1;
                    tx_clk_cnt <= 0;
                    tx_bit_idx <= 0;
                    if (tx_start) begin
                        tx_busy     <= 1'b1;
                        tx_data_buf <= tx_byte;
                        tx_out_reg  <= 1'b0;
                        tx_state    <= TX_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                TX_START: begin
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_out_reg <= tx_data_buf[0];
                        tx_state   <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_DATA: begin
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        if (tx_bit_idx == 3'd7) begin
                            tx_bit_idx <= 0;
                            tx_out_reg <= 1'b1;
                            tx_state   <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 1;
                            tx_out_reg <= tx_data_buf[tx_bit_idx + 1];
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_STOP: begin
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_busy    <= 1'b0;
                        tx_state   <= TX_IDLE;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // Hex ASCII Conversion Helper Functions
    //==========================================================================
    function [3:0] ascii_to_nibble(input [7:0] ascii);
        if (ascii >= "0" && ascii <= "9")
            ascii_to_nibble = ascii - "0";
        else if (ascii >= "A" && ascii <= "F")
            ascii_to_nibble = ascii - "A" + 10;
        else if (ascii >= "a" && ascii <= "f")
            ascii_to_nibble = ascii - "a" + 10;
        else
            ascii_to_nibble = 4'h0;
    endfunction

    function [7:0] nibble_to_ascii(input [3:0] nibble);
        if (nibble < 10)
            nibble_to_ascii = "0" + nibble;
        else
            nibble_to_ascii = "a" + (nibble - 10);
    endfunction

    //==========================================================================
    // Button Debouncer
    //==========================================================================
    reg [19:0] btn_cnt;
    reg        btn_c_sync, btn_c_db, btn_c_prev;
    wire       btn_pulse;

    always @(posedge clk) begin
        btn_c_sync <= btn_c;
        if (btn_c_sync != btn_c_db) begin
            btn_cnt <= btn_cnt + 1;
            if (btn_cnt == 20'd1_000_000) begin
                btn_c_db <= btn_c_sync;
                btn_cnt  <= 0;
            end
        end else begin
            btn_cnt <= 0;
        end
        btn_c_prev <= btn_c_db;
    end
    assign btn_pulse = btn_c_db && !btn_c_prev;

    //==========================================================================
    // Mode Engine & Internal Master Control FSM
    //==========================================================================
    reg  [2:0]   mode_sel_reg;
    reg          op_dir_reg;
    reg          mode_start_req;
    reg          mode_rst_state;
    reg          mode_load_iv;
    reg          mode_load_aad;
    reg          mode_gen_tag;

    reg  [127:0] key_reg;
    reg  [127:0] block_in_reg;
    reg  [127:0] iv_reg;
    reg  [127:0] block_out_reg;
    wire [127:0] engine_block_out;
    wire [127:0] engine_tag_out;
    wire         engine_done;
    wire         engine_busy;

    // Core AXI signals
    wire         core_req_start;
    wire         core_req_mode;
    wire [127:0] core_req_din;
    reg  [127:0] core_resp_dout;
    reg          core_resp_done;

    reg  [6:0]   char_cnt;
    reg  [5:0]   tx_char_idx;
    reg  [7:0]   cmd_type;
    reg          nist_pass_reg;
    reg  [15:0]  pkt_cnt;
    reg  [1:0]   burst_beat;
    reg  [31:0]  read_word_buf [0:3];
    reg          core_done_latched;

    // Mode Engine Instance
    aes_mode_engine mode_engine_inst (
        .clk(clk),
        .rst_n(sys_rst_n),
        .mode_sel(mode_sel_reg),
        .op_dir(op_dir_reg),
        .start_req(mode_start_req),
        .reset_state(mode_rst_state),
        .load_iv(mode_load_iv),
        .load_aad(mode_load_aad),
        .gen_tag_req(mode_gen_tag),
        .block_in(block_in_reg),
        .iv_in(iv_reg),
        .key_in(key_reg),
        .block_out(engine_block_out),
        .tag_out(engine_tag_out),
        .done(engine_done),
        .busy(engine_busy),
        .core_req_start(core_req_start),
        .core_req_mode(core_req_mode),
        .core_req_din(core_req_din),
        .core_resp_dout(core_resp_dout),
        .core_resp_done(core_resp_done)
    );

    // AXI Master Signals to aes_axi_top
    reg  [3:0]   m_axi_awid;
    reg  [31:0]  m_axi_awaddr;
    reg  [7:0]   m_axi_awlen;
    wire [2:0]   m_axi_awsize = 3'b010;
    wire [1:0]   m_axi_awburst = 2'b01;
    reg          m_axi_awvalid;
    wire         m_axi_awready;

    reg  [31:0]  m_axi_wdata;
    wire [3:0]   m_axi_wstrb = 4'hF;
    reg          m_axi_wlast;
    reg          m_axi_wvalid;
    wire         m_axi_wready;

    wire [3:0]   m_axi_bid;
    wire [1:0]   m_axi_bresp;
    wire         m_axi_bvalid;
    reg          m_axi_bready;

    reg  [3:0]   m_axi_arid;
    reg  [31:0]  m_axi_araddr;
    reg  [7:0]   m_axi_arlen;
    wire [2:0]   m_axi_arsize = 3'b010;
    wire [1:0]   m_axi_arburst = 2'b01;
    reg          m_axi_arvalid;
    wire         m_axi_arready;

    wire [3:0]   m_axi_rid;
    wire [31:0]  m_axi_rdata;
    wire [1:0]   m_axi_rresp;
    wire         m_axi_rlast;
    wire         m_axi_rvalid;
    reg          m_axi_rready;

    wire         core_interrupt;

    localparam S_IDLE        = 4'd0;
    localparam S_RX_LINE     = 4'd1;
    localparam S_WR_KEY      = 4'd2;
    localparam S_WR_KEY_RESP = 4'd3;
    localparam S_WR_DIN      = 4'd4;
    localparam S_WR_DIN_RESP = 4'd5;
    localparam S_START_CMD   = 4'd6;
    localparam S_START_RESP  = 4'd7;
    localparam S_WAIT_CORE   = 4'd8;
    localparam S_RD_DOUT     = 4'd9;
    localparam S_RD_DOUT_DATA= 4'd10;
    localparam S_TX_RESULT   = 4'd11;

    reg [3:0] state;

    always @(posedge clk) begin
        if (sys_rst) begin
            state             <= S_IDLE;
            mode_sel_reg      <= 3'd0; // ECB
            op_dir_reg        <= 1'b0; // Encrypt
            mode_start_req    <= 1'b0;
            mode_rst_state    <= 1'b0;
            mode_load_iv      <= 1'b0;
            mode_load_aad     <= 1'b0;
            mode_gen_tag      <= 1'b0;
            key_reg           <= 128'h000102030405060708090a0b0c0d0e0f;
            block_in_reg      <= 128'h00112233445566778899aabbccddeeff;
            iv_reg            <= 128'h0;
            block_out_reg     <= 128'h0;
            char_cnt          <= 0;
            tx_char_idx       <= 0;
            tx_start          <= 0;
            tx_byte           <= 0;
            cmd_type          <= 0;
            nist_pass_reg     <= 0;
            pkt_cnt           <= 0;
            burst_beat        <= 0;
            core_done_latched <= 0;
            core_resp_dout    <= 128'h0;
            core_resp_done    <= 1'b0;

            m_axi_awid        <= 0;
            m_axi_awaddr      <= 0;
            m_axi_awlen       <= 0;
            m_axi_awvalid     <= 0;
            m_axi_wdata       <= 0;
            m_axi_wlast       <= 0;
            m_axi_wvalid      <= 0;
            m_axi_bready      <= 0;
            m_axi_arid        <= 0;
            m_axi_araddr      <= 0;
            m_axi_arlen       <= 0;
            m_axi_arvalid     <= 0;
            m_axi_rready      <= 0;
        end else begin
            tx_start       <= 1'b0;
            mode_start_req <= 1'b0;
            mode_rst_state <= 1'b0;
            mode_load_iv   <= 1'b0;
            mode_load_aad  <= 1'b0;
            mode_gen_tag   <= 1'b0;
            core_resp_done <= 1'b0;

            if (core_interrupt)
                core_done_latched <= 1'b1;

            case (state)
                S_IDLE: begin
                    char_cnt          <= 0;
                    tx_char_idx       <= 0;
                    core_done_latched <= 0;

                    if (core_req_start) begin
                        // Mode engine requested hardware AES core execution
                        m_axi_awid    <= 4'h1;
                        m_axi_awaddr  <= 32'h0000_0010; // Write Key
                        m_axi_awlen   <= 8'd3;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= key_reg[127:96];
                        m_axi_wlast   <= 1'b0;
                        m_axi_wvalid  <= 1'b1;
                        burst_beat    <= 2'd0;
                        state         <= S_WR_KEY;
                    end else if (engine_done) begin
                        block_out_reg <= (cmd_type == "G") ? engine_tag_out : engine_block_out;
                        if (engine_block_out == 128'h69c4e0d86a7b0430d8cdb78070b4c55a)
                            nist_pass_reg <= 1'b1;
                        tx_char_idx <= 0;
                        state       <= S_TX_RESULT;
                    end else if (rx_valid) begin
                        cmd_type <= rx_data;
                        if (rx_data == "M" || rx_data == "m") begin
                            // 'M' + <0..5>
                            state <= S_RX_LINE;
                        end else if (rx_data == "I" || rx_data == "i" ||
                                   rx_data == "A" || rx_data == "a" ||
                                   rx_data == "K" || rx_data == "k" ||
                                   rx_data == "E" || rx_data == "e" ||
                                   rx_data == "D" || rx_data == "d") begin
                            state <= S_RX_LINE;
                        end else if (rx_data == "G" || rx_data == "g") begin
                            // Generate GCM Tag
                            cmd_type     <= "G";
                            mode_gen_tag <= 1'b1;
                        end else if (rx_data == "R" || rx_data == "r") begin
                            // Reset mode feedback state
                            mode_rst_state <= 1'b1;
                        end else if (rx_data == "T" || rx_data == "t") begin
                            // NIST KAT
                            cmd_type       <= "E";
                            mode_sel_reg   <= 3'd0; // ECB
                            op_dir_reg     <= 1'b0;
                            key_reg        <= 128'h000102030405060708090a0b0c0d0e0f;
                            block_in_reg   <= 128'h00112233445566778899aabbccddeeff;
                            mode_start_req <= 1'b1;
                        end
                    end else if (btn_pulse) begin
                        cmd_type       <= "E";
                        mode_sel_reg   <= 3'd0;
                        op_dir_reg     <= 1'b0;
                        key_reg        <= 128'h000102030405060708090a0b0c0d0e0f;
                        block_in_reg   <= 128'h00112233445566778899aabbccddeeff;
                        mode_start_req <= 1'b1;
                    end
                end

                S_RX_LINE: begin
                    if (rx_valid) begin
                        if (rx_data == "\n" || rx_data == "\r" || char_cnt == 7'd32) begin
                            pkt_cnt <= pkt_cnt + 1;
                            case (cmd_type)
                                "M", "m": begin
                                    // Mode was latched during line rx
                                    state <= S_IDLE;
                                end
                                "I", "i": begin
                                    mode_load_iv <= 1'b1;
                                    state        <= S_IDLE;
                                end
                                "A", "a": begin
                                    mode_load_aad <= 1'b1;
                                    state         <= S_IDLE;
                                end
                                "K", "k": begin
                                    state <= S_IDLE;
                                end
                                "E", "e": begin
                                    op_dir_reg     <= 1'b0;
                                    mode_start_req <= 1'b1;
                                    state          <= S_IDLE;
                                end
                                "D", "d": begin
                                    op_dir_reg     <= 1'b1;
                                    mode_start_req <= 1'b1;
                                    state          <= S_IDLE;
                                end
                                default: state <= S_IDLE;
                            endcase
                        end else begin
                            if (cmd_type == "M" || cmd_type == "m") begin
                                if (rx_data >= "0" && rx_data <= "5")
                                    mode_sel_reg <= rx_data - "0";
                            end else if (cmd_type == "I" || cmd_type == "i") begin
                                iv_reg <= {iv_reg[123:0], ascii_to_nibble(rx_data)};
                            end else if (cmd_type == "K" || cmd_type == "k") begin
                                key_reg <= {key_reg[123:0], ascii_to_nibble(rx_data)};
                            end else if (cmd_type == "A" || cmd_type == "a" ||
                                       cmd_type == "E" || cmd_type == "e" ||
                                       cmd_type == "D" || cmd_type == "d") begin
                                block_in_reg <= {block_in_reg[123:0], ascii_to_nibble(rx_data)};
                            end
                            char_cnt <= char_cnt + 1;
                        end
                    end
                end

                //--------------------------------------------------------------
                // AXI Step 1: Write KEY (0x10..0x1C)
                //--------------------------------------------------------------
                S_WR_KEY: begin
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;

                    if (m_axi_wvalid && m_axi_wready) begin
                        if (burst_beat == 2'd3) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state        <= S_WR_KEY_RESP;
                        end else begin
                            burst_beat  <= burst_beat + 1;
                            m_axi_wlast <= (burst_beat == 2'd2);
                            case (burst_beat)
                                2'd0: m_axi_wdata <= key_reg[95:64];
                                2'd1: m_axi_wdata <= key_reg[63:32];
                                2'd2: m_axi_wdata <= key_reg[31:0];
                            endcase
                        end
                    end
                end

                S_WR_KEY_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        
                        m_axi_awid    <= 4'h2;
                        m_axi_awaddr  <= 32'h0000_0020;
                        m_axi_awlen   <= 8'd3;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= core_req_din[127:96];
                        m_axi_wlast   <= 1'b0;
                        m_axi_wvalid  <= 1'b1;
                        burst_beat    <= 2'd0;
                        state         <= S_WR_DIN;
                    end
                end

                //--------------------------------------------------------------
                // AXI Step 2: Write BLOCK_IN (0x20..0x2C)
                //--------------------------------------------------------------
                S_WR_DIN: begin
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;

                    if (m_axi_wvalid && m_axi_wready) begin
                        if (burst_beat == 2'd3) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state        <= S_WR_DIN_RESP;
                        end else begin
                            burst_beat  <= burst_beat + 1;
                            m_axi_wlast <= (burst_beat == 2'd2);
                            case (burst_beat)
                                2'd0: m_axi_wdata <= core_req_din[95:64];
                                2'd1: m_axi_wdata <= core_req_din[63:32];
                                2'd2: m_axi_wdata <= core_req_din[31:0];
                            endcase
                        end
                    end
                end

                S_WR_DIN_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        
                        m_axi_awid    <= 4'h3;
                        m_axi_awaddr  <= 32'h0000_0000;
                        m_axi_awlen   <= 8'd0;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= core_req_mode ? 32'h0000_0003 : 32'h0000_0001;
                        m_axi_wlast   <= 1'b1;
                        m_axi_wvalid  <= 1'b1;
                        state         <= S_START_CMD;
                    end
                end

                //--------------------------------------------------------------
                // AXI Step 3: Write CONTROL (0x00)
                //--------------------------------------------------------------
                S_START_CMD: begin
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;

                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        m_axi_wlast  <= 1'b0;
                        m_axi_bready <= 1'b1;
                        state        <= S_START_RESP;
                    end
                end

                S_START_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        state        <= S_WAIT_CORE;
                    end
                end

                //--------------------------------------------------------------
                // AXI Step 4: Wait Core Done
                //--------------------------------------------------------------
                S_WAIT_CORE: begin
                    if (core_interrupt || core_done_latched) begin
                        core_done_latched <= 1'b0;
                        
                        m_axi_arid    <= 4'h4;
                        m_axi_araddr  <= 32'h0000_0030;
                        m_axi_arlen   <= 8'd3;
                        m_axi_arvalid <= 1'b1;
                        m_axi_rready  <= 1'b1;
                        burst_beat    <= 2'd0;
                        state         <= S_RD_DOUT;
                    end
                end

                //--------------------------------------------------------------
                // AXI Step 5: Read BLOCK_OUT (0x30..0x3C)
                //--------------------------------------------------------------
                S_RD_DOUT: begin
                    if (m_axi_arvalid && m_axi_arready)
                        m_axi_arvalid <= 1'b0;

                    if (m_axi_rvalid && m_axi_rready) begin
                        read_word_buf[burst_beat] <= m_axi_rdata;
                        if (burst_beat == 2'd3 || m_axi_rlast) begin
                            m_axi_rready   <= 1'b0;
                            core_resp_dout <= {read_word_buf[0], read_word_buf[1], read_word_buf[2], m_axi_rdata};
                            core_resp_done <= 1'b1;
                            state          <= S_IDLE;
                        end else begin
                            burst_beat <= burst_beat + 1;
                        end
                    end
                end

                //--------------------------------------------------------------
                // Step 6: Transmit 32 Hex Characters + \r\n
                //--------------------------------------------------------------
                S_TX_RESULT: begin
                    if (!tx_busy && !tx_start) begin
                        if (tx_char_idx < 32) begin
                            tx_byte     <= nibble_to_ascii(block_out_reg[127 - (tx_char_idx * 4) -: 4]);
                            tx_start    <= 1'b1;
                            tx_char_idx <= tx_char_idx + 1;
                        end else if (tx_char_idx == 32) begin
                            tx_byte     <= 8'h0D;
                            tx_start    <= 1'b1;
                            tx_char_idx <= tx_char_idx + 1;
                        end else if (tx_char_idx == 33) begin
                            tx_byte     <= 8'h0A;
                            tx_start    <= 1'b1;
                            tx_char_idx <= tx_char_idx + 1;
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    //==========================================================================
    // AES-128 Accelerator Core Subsystem Instance
    //==========================================================================
    aes_axi_top #(
        .C_S_AXI_ID_WIDTH(4),
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(32)
    ) aes_inst (
        .s_axi_aclk(clk),
        .s_axi_aresetn(sys_rst_n),

        .s_axi_awid(m_axi_awid),
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awlen(m_axi_awlen),
        .s_axi_awsize(m_axi_awsize),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'h0),
        .s_axi_awprot(3'b000),
        .s_axi_awqos(4'h0),
        .s_axi_awregion(4'h0),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),

        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wlast(m_axi_wlast),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),

        .s_axi_bid(m_axi_bid),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),

        .s_axi_arid(m_axi_arid),
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arlen(m_axi_arlen),
        .s_axi_arsize(m_axi_arsize),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'h0),
        .s_axi_arprot(3'b000),
        .s_axi_arqos(4'h0),
        .s_axi_arregion(4'h0),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),

        .s_axi_rid(m_axi_rid),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rlast(m_axi_rlast),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready),

        .interrupt(core_interrupt)
    );

    //==========================================================================
    // 8-Digit 7-Segment Multiplexed Display Driver
    //==========================================================================
    wire [31:0] disp_word = (sw == 2'b00) ? block_out_reg[127:96] :
                            (sw == 2'b01) ? block_out_reg[95:64]  :
                            (sw == 2'b10) ? block_out_reg[63:32]  :
                                            block_out_reg[31:0];

    reg [19:0] refresh_cnt;
    always @(posedge clk) refresh_cnt <= refresh_cnt + 1;
    wire [2:0] digit_sel = refresh_cnt[19:17];

    reg [3:0] current_nibble;
    reg [7:0] an_reg;

    always @(*) begin
        case (digit_sel)
            3'd0: begin an_reg = 8'b1111_1110; current_nibble = disp_word[3:0];   end
            3'd1: begin an_reg = 8'b1111_1101; current_nibble = disp_word[7:4];   end
            3'd2: begin an_reg = 8'b1111_1011; current_nibble = disp_word[11:8];  end
            3'd3: begin an_reg = 8'b1111_0111; current_nibble = disp_word[15:12]; end
            3'd4: begin an_reg = 8'b1110_1111; current_nibble = disp_word[19:16]; end
            3'd5: begin an_reg = 8'b1101_1111; current_nibble = disp_word[23:20]; end
            3'd6: begin an_reg = 8'b1011_1111; current_nibble = disp_word[27:24]; end
            3'd7: begin an_reg = 8'b0111_1111; current_nibble = disp_word[31:28]; end
        endcase
    end
    assign an = an_reg;

    reg [6:0] seg_reg;
    always @(*) begin
        case (current_nibble)
            4'h0: seg_reg = 7'b100_0000;
            4'h1: seg_reg = 7'b111_1001;
            4'h2: seg_reg = 7'b010_0100;
            4'h3: seg_reg = 7'b011_0000;
            4'h4: seg_reg = 7'b001_1001;
            4'h5: seg_reg = 7'b001_0010;
            4'h6: seg_reg = 7'b000_0010;
            4'h7: seg_reg = 7'b111_1000;
            4'h8: seg_reg = 7'b000_0000;
            4'h9: seg_reg = 7'b001_0000;
            4'hA: seg_reg = 7'b000_1000;
            4'hB: seg_reg = 7'b000_0011;
            4'hC: seg_reg = 7'b100_0110;
            4'hD: seg_reg = 7'b010_0001;
            4'hE: seg_reg = 7'b000_0110;
            4'hF: seg_reg = 7'b000_1110;
        endcase
    end
    assign seg = seg_reg;
    assign dp  = (digit_sel == {1'b0, sw}) ? 1'b0 : 1'b1;

    //==========================================================================
    // Onboard LEDs Mapping
    //==========================================================================
    assign led[0]    = (state == S_IDLE && !engine_busy); // READY
    assign led[1]    = (state != S_IDLE || engine_busy);  // BUSY
    assign led[2]    = core_interrupt;                    // DONE
    assign led[3]    = nist_pass_reg;                     // NIST PASS
    assign led[6:4]  = mode_sel_reg;                      // Active Mode (0..5)
    assign led[7]    = op_dir_reg;                        // 0: Enc, 1: Dec
    assign led[15:8] = pkt_cnt[7:0];                      // Total Packets Processed

endmodule
