`timescale 1ns / 1ps
//==============================================================================
// PS06 Top-Level Hardware AES-128 Accelerator with Full AXI4-MM Interface
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Encapsulates the entire SoC accelerator subsystem:
//   1. Full AXI4 Memory-Mapped Slave Engine (axi_mm_slave.v)
//   2. Secure Memory-Mapped Register Bank (aes_registers.v)
//   3. Unified Dual-Mode Iterative AES-128 Engine (aes_core.v)
//      - S-Box Resource Folding (< 1,500 LUT budget)
//      - 10-Cycle Datapath Schedule (II = 10, 1.28 Gbps @ 100MHz)
//      - On-The-Fly Round-Key Generation (zero BRAM)
//      - Hardware Cryptographic Isolation (zero bus leakage)
//==============================================================================

module aes_axi_top #(
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
    output wire                              s_axi_awready,

    // Write Data Channel (W)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wlast,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,

    // Write Response Channel (B)
    output wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_bid,
    output wire [1:0]                        s_axi_bresp,
    output wire                              s_axi_bvalid,
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
    output wire                              s_axi_arready,

    // Read Data Channel (R)
    output wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_rid,
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                        s_axi_rresp,
    output wire                              s_axi_rlast,
    output wire                              s_axi_rvalid,
    input  wire                              s_axi_rready,

    // Hardware Interrupt Output (Asserts on block completion)
    output wire                              interrupt
);

    //==========================================================================
    // Interconnect Wires between AXI Interface & Cryptographic Core
    //==========================================================================
    wire         core_start;
    wire         core_mode;
    wire         core_rst;
    wire [127:0] core_key;
    wire [127:0] core_block_in;
    wire [127:0] core_block_out;
    wire         core_done;
    wire         core_busy;

    // Interrupt line driven by completion pulse
    assign interrupt = core_done;

    //==========================================================================
    // Full AXI4 Memory-Mapped Slave Subsystem
    //==========================================================================
    axi_mm_slave #(
        .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) axi_slave_inst (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awregion(s_axi_awregion),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arregion(s_axi_arregion),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
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
    // Unified 10-Cycle Iterative AES-128 Core
    //==========================================================================
    aes_core core_inst (
        .clk(s_axi_aclk),
        .rst(~s_axi_aresetn | core_rst),
        .start(core_start),
        .mode(core_mode),
        .key(core_key),
        .block_in(core_block_in),
        .block_out(core_block_out),
        .done(core_done),
        .busy(core_busy)
    );

endmodule
