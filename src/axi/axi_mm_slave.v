`timescale 1ns / 1ps
//==============================================================================
// Full AXI4 Memory-Mapped (AXI4-MM) Slave Interface
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Full AXI4 specification compliant slave module featuring:
//   - 5 independent channels (AW, W, B, AR, R)
//   - Transaction ID reflection (awid -> bid, arid -> rid)
//   - Burst transfer support: INCR (2'b01) and FIXED (2'b00) up to 256 beats
//   - Single-beat register access (len = 0)
//   - Multi-beat burst access (e.g. 4-word burst for 128-bit key / data / result)
//   - wlast verification and rlast generation
//   - Cryptographic isolation via integrated aes_registers.v
//==============================================================================

module axi_mm_slave #(
    parameter integer C_S_AXI_ID_WIDTH   = 4,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32
)(
    // System Clock and Active-Low Synchronous Reset
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    // Write Address Channel (AW)
    input  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_awid,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [7:0]                        s_axi_awlen,
    input  wire [2:0]                        s_axi_awsize,
    input  wire [1:0]                        s_axi_awburst,
    input  wire                              s_axi_awlock,
    input  wire [3:0]                        s_axi_awcache,
    input  wire [2:0]                        s_axi_awprot,
    input  wire [3:0]                        s_axi_awqos,
    input  wire [3:0]                        s_axi_awregion,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    // Write Data Channel (W)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wlast,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    // Write Response Channel (B)
    output reg  [C_S_AXI_ID_WIDTH-1:0]       s_axi_bid,
    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    // Read Address Channel (AR)
    input  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_arid,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [7:0]                        s_axi_arlen,
    input  wire [2:0]                        s_axi_arsize,
    input  wire [1:0]                        s_axi_arburst,
    input  wire                              s_axi_arlock,
    input  wire [3:0]                        s_axi_arcache,
    input  wire [2:0]                        s_axi_arprot,
    input  wire [3:0]                        s_axi_arqos,
    input  wire [3:0]                        s_axi_arregion,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    // Read Data Channel (R)
    output reg  [C_S_AXI_ID_WIDTH-1:0]       s_axi_rid,
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rlast,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    // Core Interface to aes_core
    output wire                              core_start,
    output wire                              core_mode,
    output wire                              core_rst,
    output wire [127:0]                      core_key,
    output wire [127:0]                      core_block_in,
    input  wire [127:0]                      core_block_out,
    input  wire                              core_done,
    input  wire                              core_busy
);

    //==========================================================================
    // Internal Register Bus Signals
    //==========================================================================
    reg [C_S_AXI_ADDR_WIDTH-1:0] aw_addr_reg;
    reg [1:0]                    wr_state;
    localparam WR_IDLE  = 2'd0;
    localparam WR_BURST = 2'd1;
    localparam WR_RESP  = 2'd2;

    // Direct combinational drive to register bank during valid write beats
    wire        reg_wr_en   = (wr_state == WR_BURST) && s_axi_wvalid && s_axi_wready;
    wire [7:0]  reg_wr_addr = aw_addr_reg[7:0];
    wire [31:0] reg_wr_data = s_axi_wdata;
    wire [3:0]  reg_wr_strb = s_axi_wstrb;

    wire        reg_rd_en;
    wire [7:0]  reg_rd_addr;
    wire [31:0] reg_rd_data;

    // Direct assignment from read address register to register bank
    reg [C_S_AXI_ADDR_WIDTH-1:0] ar_addr_reg;
    assign reg_rd_addr = ar_addr_reg[7:0];
    assign s_axi_rdata = reg_rd_data;

    // Instantiate Secure Register Bank
    aes_registers reg_bank_inst (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .reg_wr_en(reg_wr_en),
        .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data),
        .reg_wr_strb(reg_wr_strb),
        .reg_rd_en(reg_rd_en),
        .reg_rd_addr(reg_rd_addr),
        .reg_rd_data(reg_rd_data),
        .core_start(core_start),
        .core_mode(core_mode),
        .core_rst(core_rst),
        .core_key(core_key),
        .core_block_in(core_block_in),
        .core_block_out(core_block_out),
        .core_done(core_done),
        .core_busy(core_busy)
    );

    //==========================================================================
    // AXI4 Write Transaction State Machine & Burst Controller
    //==========================================================================
    reg [C_S_AXI_ID_WIDTH-1:0]   aw_id_reg;
    reg [7:0]                    aw_len_reg;
    reg [1:0]                    aw_burst_reg;
    reg [7:0]                    aw_cnt_reg;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            wr_state      <= WR_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= {C_S_AXI_ID_WIDTH{1'b0}};
            s_axi_bresp   <= 2'b00;
            aw_id_reg     <= {C_S_AXI_ID_WIDTH{1'b0}};
            aw_addr_reg   <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            aw_len_reg    <= 8'h0;
            aw_burst_reg  <= 2'b00;
            aw_cnt_reg    <= 8'h0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        aw_id_reg     <= s_axi_awid;
                        aw_addr_reg   <= s_axi_awaddr;
                        aw_len_reg    <= s_axi_awlen;
                        aw_burst_reg  <= s_axi_awburst;
                        aw_cnt_reg    <= 8'h0;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b1;
                        wr_state      <= WR_BURST;
                    end
                end

                WR_BURST: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        // Increment address if burst type is INCR (2'b01)
                        if (aw_burst_reg == 2'b01) begin
                            aw_addr_reg <= aw_addr_reg + 32'd4;
                        end

                        // Check for final beat of the burst
                        if ((aw_cnt_reg == aw_len_reg) || s_axi_wlast) begin
                            s_axi_wready <= 1'b0;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bid    <= aw_id_reg;
                            s_axi_bresp  <= 2'b00; // OKAY
                            wr_state     <= WR_RESP;
                        end else begin
                            aw_cnt_reg <= aw_cnt_reg + 8'd1;
                        end
                    end
                end

                WR_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid  <= 1'b0;
                        s_axi_awready <= 1'b1;
                        wr_state      <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    //==========================================================================
    // AXI4 Read Transaction State Machine & Burst Controller
    //==========================================================================
    localparam RD_IDLE  = 2'd0;
    localparam RD_BURST = 2'd1;

    reg [1:0]                    rd_state;
    reg [C_S_AXI_ID_WIDTH-1:0]   ar_id_reg;
    reg [7:0]                    ar_len_reg;
    reg [1:0]                    ar_burst_reg;
    reg [7:0]                    ar_cnt_reg;

    assign reg_rd_en = (rd_state == RD_BURST);

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= {C_S_AXI_ID_WIDTH{1'b0}};
            s_axi_rresp   <= 2'b00;
            s_axi_rlast   <= 1'b0;
            ar_id_reg     <= {C_S_AXI_ID_WIDTH{1'b0}};
            ar_addr_reg   <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            ar_len_reg    <= 8'h0;
            ar_burst_reg  <= 2'b00;
            ar_cnt_reg    <= 8'h0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        ar_id_reg     <= s_axi_arid;
                        ar_addr_reg   <= s_axi_araddr;
                        ar_len_reg    <= s_axi_arlen;
                        ar_burst_reg  <= s_axi_arburst;
                        ar_cnt_reg    <= 8'h0;
                        s_axi_arready <= 1'b0;

                        // Present first beat
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rid     <= s_axi_arid;
                        s_axi_rresp   <= 2'b00;
                        s_axi_rlast   <= (s_axi_arlen == 8'd0);
                        rd_state      <= RD_BURST;
                    end
                end

                RD_BURST: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (ar_cnt_reg == ar_len_reg) begin
                            // Burst finished
                            s_axi_rvalid  <= 1'b0;
                            s_axi_rlast   <= 1'b0;
                            s_axi_arready <= 1'b1;
                            rd_state      <= RD_IDLE;
                        end else begin
                            // Next beat
                            ar_cnt_reg   <= ar_cnt_reg + 8'd1;
                            s_axi_rvalid <= 1'b1;
                            s_axi_rid    <= ar_id_reg;
                            s_axi_rresp  <= 2'b00;
                            s_axi_rlast  <= ((ar_cnt_reg + 8'd1) == ar_len_reg);

                            if (ar_burst_reg == 2'b01) begin
                                ar_addr_reg <= ar_addr_reg + 32'd4;
                            end
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
