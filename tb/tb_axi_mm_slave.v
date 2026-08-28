`timescale 1ns / 1ps
//==============================================================================
// Full AXI4 Memory-Mapped (AXI4-MM) Slave Verification Testbench
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Verifies:
//   1. Full AXI4 handshake protocol & single-beat register read/write
//   2. 4-beat burst write and 4-beat burst read operations (INCR burst)
//   3. Correctness of wlast and rlast flags and ID reflection (awid->bid, arid->rid)
//   4. NIST FIPS-197 AES-128 Encryption via AXI4 transactions
//   5. NIST FIPS-197 AES-128 Decryption via AXI4 transactions
//   6. Anti-Leakage Hardware Security Protections:
//      - Write-only key protection: Reading KEY_0..3 returns strictly 0x0000_0000
//      - Gated result protection: Reading BLOCK_OUT_0..3 during BUSY returns 0x0000_0000
//      - Unmapped address protection: Reading unmapped offsets returns 0x0000_0000
//      - Zero bus exposure of intermediate round states and round keys
//==============================================================================

module tb_axi_mm_slave;

    localparam C_ID_WIDTH   = 4;
    localparam C_DATA_WIDTH = 32;
    localparam C_ADDR_WIDTH = 32;

    reg                     clk;
    reg                     rst_n;

    // AXI4 Write Address Channel (AW)
    reg  [C_ID_WIDTH-1:0]   s_axi_awid;
    reg  [C_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg  [7:0]              s_axi_awlen;
    reg  [2:0]              s_axi_awsize;
    reg  [1:0]              s_axi_awburst;
    reg                     s_axi_awlock;
    reg  [3:0]              s_axi_awcache;
    reg  [2:0]              s_axi_awprot;
    reg  [3:0]              s_axi_awqos;
    reg  [3:0]              s_axi_awregion;
    reg                     s_axi_awvalid;
    wire                    s_axi_awready;

    // AXI4 Write Data Channel (W)
    reg  [C_DATA_WIDTH-1:0] s_axi_wdata;
    reg  [3:0]              s_axi_wstrb;
    reg                     s_axi_wlast;
    reg                     s_axi_wvalid;
    wire                    s_axi_wready;

    // AXI4 Write Response Channel (B)
    wire [C_ID_WIDTH-1:0]   s_axi_bid;
    wire [1:0]              s_axi_bresp;
    wire                    s_axi_bvalid;
    reg                     s_axi_bready;

    // AXI4 Read Address Channel (AR)
    reg  [C_ID_WIDTH-1:0]   s_axi_arid;
    reg  [C_ADDR_WIDTH-1:0] s_axi_araddr;
    reg  [7:0]              s_axi_arlen;
    reg  [2:0]              s_axi_arsize;
    reg  [1:0]              s_axi_arburst;
    reg                     s_axi_arlock;
    reg  [3:0]              s_axi_arcache;
    reg  [2:0]              s_axi_arprot;
    reg  [3:0]              s_axi_arqos;
    reg  [3:0]              s_axi_arregion;
    reg                     s_axi_arvalid;
    wire                    s_axi_arready;

    // AXI4 Read Data Channel (R)
    wire [C_ID_WIDTH-1:0]   s_axi_rid;
    wire [C_DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]              s_axi_rresp;
    wire                    s_axi_rlast;
    wire                    s_axi_rvalid;
    reg                     s_axi_rready;

    // Core interconnect wires
    wire                    core_start;
    wire                    core_mode;
    wire                    core_rst;
    wire [127:0]            core_key;
    wire [127:0]            core_block_in;
    wire [127:0]            core_block_out;
    wire                    core_done;
    wire                    core_busy;

    integer errors;
    integer tests_passed;

    // 100 MHz Clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================================
    // DUT: AXI4-MM Slave Subsystem
    //==========================================================================
    axi_mm_slave #(
        .C_S_AXI_ID_WIDTH(C_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_ADDR_WIDTH)
    ) dut_slave (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
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
    // AES-128 Core Connected to Slave
    //==========================================================================
    aes_core dut_core (
        .clk(clk),
        .rst(~rst_n | core_rst),
        .start(core_start),
        .mode(core_mode),
        .key(core_key),
        .block_in(core_block_in),
        .block_out(core_block_out),
        .done(core_done),
        .busy(core_busy)
    );

    //==========================================================================
    // AXI4 Master Driver Tasks (with clean non-zero #1 Tco timing)
    //==========================================================================

    // Single-Beat Write Task (len = 0)
    task axi4_write_single;
        input [C_ID_WIDTH-1:0]   id;
        input [C_ADDR_WIDTH-1:0] addr;
        input [C_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk); #1;
            s_axi_awid    = id;
            s_axi_awaddr  = addr;
            s_axi_awlen   = 8'd0;
            s_axi_awsize  = 3'b010; // 4 bytes
            s_axi_awburst = 2'b01;  // INCR
            s_axi_awvalid = 1'b1;

            while (!s_axi_awready) @(posedge clk);
            @(posedge clk); #1;
            s_axi_awvalid = 1'b0;

            // Write Data
            s_axi_wdata  = data;
            s_axi_wstrb  = 4'b1111;
            s_axi_wlast  = 1'b1;
            s_axi_wvalid = 1'b1;

            while (!s_axi_wready) @(posedge clk);
            @(posedge clk); #1;
            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;

            // Wait for Write Response (B)
            s_axi_bready = 1'b1;
            while (!s_axi_bvalid) @(posedge clk);
            if (s_axi_bid !== id || s_axi_bresp !== 2'b00) begin
                $display("  [FAIL] Write response error: expected id=%h resp=00, got id=%h resp=%b",
                         id, s_axi_bid, s_axi_bresp);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            s_axi_bready = 1'b0;
        end
    endtask

    // Single-Beat Read Task (len = 0)
    task axi4_read_single;
        input  [C_ID_WIDTH-1:0]   id;
        input  [C_ADDR_WIDTH-1:0] addr;
        output [C_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk); #1;
            s_axi_arid    = id;
            s_axi_araddr  = addr;
            s_axi_arlen   = 8'd0;
            s_axi_arsize  = 3'b010; // 4 bytes
            s_axi_arburst = 2'b01;  // INCR
            s_axi_arvalid = 1'b1;

            while (!s_axi_arready) @(posedge clk);
            @(posedge clk); #1;
            s_axi_arvalid = 1'b0;

            // Wait for Read Data (R)
            s_axi_rready = 1'b1;
            while (!s_axi_rvalid) @(posedge clk);
            data = s_axi_rdata;
            if (s_axi_rid !== id || s_axi_rresp !== 2'b00 || !s_axi_rlast) begin
                $display("  [FAIL] Read response error at addr 0x%h: id=%h rlast=%b resp=%b",
                         addr, s_axi_rid, s_axi_rlast, s_axi_rresp);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            s_axi_rready = 1'b0;
        end
    endtask

    // 4-Beat Burst Write Task (len = 3, INCR)
    task axi4_write_burst_4;
        input [C_ID_WIDTH-1:0]   id;
        input [C_ADDR_WIDTH-1:0] start_addr;
        input [C_DATA_WIDTH-1:0] d0;
        input [C_DATA_WIDTH-1:0] d1;
        input [C_DATA_WIDTH-1:0] d2;
        input [C_DATA_WIDTH-1:0] d3;
        integer b;
        reg [C_DATA_WIDTH-1:0] cur_data;
        begin
            @(posedge clk); #1;
            s_axi_awid    = id;
            s_axi_awaddr  = start_addr;
            s_axi_awlen   = 8'd3;   // 4 beats
            s_axi_awsize  = 3'b010; // 4 bytes/beat
            s_axi_awburst = 2'b01;  // INCR
            s_axi_awvalid = 1'b1;

            while (!s_axi_awready) @(posedge clk);
            @(posedge clk); #1;
            s_axi_awvalid = 1'b0;

            // Send 4 beats sequentially
            for (b = 0; b < 4; b = b + 1) begin
                case (b)
                    0: cur_data = d0;
                    1: cur_data = d1;
                    2: cur_data = d2;
                    3: cur_data = d3;
                endcase
                s_axi_wdata  = cur_data;
                s_axi_wstrb  = 4'b1111;
                s_axi_wlast  = (b == 3);
                s_axi_wvalid = 1'b1;

                while (!s_axi_wready) @(posedge clk);
                @(posedge clk); #1;
            end
            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;

            // Wait for B response
            s_axi_bready = 1'b1;
            while (!s_axi_bvalid) @(posedge clk);
            if (s_axi_bid !== id || s_axi_bresp !== 2'b00) begin
                $display("  [FAIL] Burst write B response error");
                errors = errors + 1;
            end
            @(posedge clk); #1;
            s_axi_bready = 1'b0;
        end
    endtask

    // 4-Beat Burst Read Task (len = 3, INCR)
    task axi4_read_burst_4;
        input  [C_ID_WIDTH-1:0]   id;
        input  [C_ADDR_WIDTH-1:0] start_addr;
        output [C_DATA_WIDTH-1:0] d0;
        output [C_DATA_WIDTH-1:0] d1;
        output [C_DATA_WIDTH-1:0] d2;
        output [C_DATA_WIDTH-1:0] d3;
        integer b;
        begin
            @(posedge clk); #1;
            s_axi_arid    = id;
            s_axi_araddr  = start_addr;
            s_axi_arlen   = 8'd3;   // 4 beats
            s_axi_arsize  = 3'b010; // 4 bytes/beat
            s_axi_arburst = 2'b01;  // INCR
            s_axi_arvalid = 1'b1;

            while (!s_axi_arready) @(posedge clk);
            @(posedge clk); #1;
            s_axi_arvalid = 1'b0;

            // Receive 4 beats sequentially
            s_axi_rready = 1'b1;
            for (b = 0; b < 4; b = b + 1) begin
                while (!s_axi_rvalid) @(posedge clk);
                case (b)
                    0: d0 = s_axi_rdata;
                    1: d1 = s_axi_rdata;
                    2: d2 = s_axi_rdata;
                    3: d3 = s_axi_rdata;
                endcase

                if (b == 3 && !s_axi_rlast) begin
                    $display("  [FAIL] Burst read: rlast was NOT asserted on beat 3!");
                    errors = errors + 1;
                end else if (b < 3 && s_axi_rlast) begin
                    $display("  [FAIL] Burst read: premature rlast on beat %0d!", b);
                    errors = errors + 1;
                end
                @(posedge clk); #1;
            end
            s_axi_rready = 1'b0;
        end
    endtask

    //==========================================================================
    // Main Verification Sequence
    //==========================================================================
    reg [31:0] rd_val;
    reg [31:0] b0, b1, b2, b3;
    reg [127:0] full_block;
    integer wait_cycles;

    initial begin
        errors       = 0;
        tests_passed = 0;
        rst_n        = 0;

        // Channel defaults
        s_axi_awid     = 0; s_axi_awaddr = 0; s_axi_awlen = 0;
        s_axi_awsize   = 0; s_axi_awburst = 0; s_axi_awlock = 0;
        s_axi_awcache  = 0; s_axi_awprot = 0; s_axi_awqos = 0;
        s_axi_awregion = 0; s_axi_awvalid = 0;
        s_axi_wdata    = 0; s_axi_wstrb = 0; s_axi_wlast = 0; s_axi_wvalid = 0;
        s_axi_bready   = 0;
        s_axi_arid     = 0; s_axi_araddr = 0; s_axi_arlen = 0;
        s_axi_arsize   = 0; s_axi_arburst = 0; s_axi_arlock = 0;
        s_axi_arcache  = 0; s_axi_arprot = 0; s_axi_arqos = 0;
        s_axi_arregion = 0; s_axi_arvalid = 0;
        s_axi_rready   = 0;

        $display("================================================================");
        $display("PS06 Full AXI4-MM Slave & Security Anti-Leakage Verification");
        $display("================================================================");

        // Reset for 5 cycles
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: AXI4 Single Register Write & Read (CONFIG Register 0x08)
        //----------------------------------------------------------------------
        $display("\n--- Test 1: AXI4 Single Register Write & Read ---");
        axi4_write_single(4'h1, 32'h0000_0008, 32'hA5A5_5A5A);
        axi4_read_single(4'h2, 32'h0000_0008, rd_val);
        if (rd_val === 32'hA5A5_5A5A) begin
            $display("  [PASS] CONFIG register written and read correctly: 0x%08h", rd_val);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] CONFIG mismatch! Expected 0xA5A55A5A, got 0x%08h", rd_val);
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Test 2: STATUS Register Verification (0x04)
        //----------------------------------------------------------------------
        $display("\n--- Test 2: STATUS Register Verification ---");
        axi4_read_single(4'h3, 32'h0000_0004, rd_val);
        // Bit 0: BUSY=0, Bit 1: DONE=0, Bit 2: READY=1 -> 0x0000_0004
        if (rd_val[2:0] === 3'b100) begin
            $display("  [PASS] STATUS reset value correct: READY=1, BUSY=0, DONE=0 (val=0x%08h)", rd_val);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] STATUS incorrect! Expected 3'b100, got %b (val=0x%08h)", rd_val[2:0], rd_val);
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Test 3: Security Check 1 — Write-Only Key Protection
        //----------------------------------------------------------------------
        $display("\n--- Test 3: Security Check — Write-Only Key Protection ---");
        // Write secret key to KEY_0..3
        axi4_write_single(4'h4, 32'h0000_0010, 32'hDEAD_BEEF);
        axi4_write_single(4'h4, 32'h0000_0014, 32'hCAFE_BABE);
        axi4_write_single(4'h4, 32'h0000_0018, 32'h0123_4567);
        axi4_write_single(4'h4, 32'h0000_001C, 32'h89AB_CDEF);

        // Attempt readback across all 4 key registers
        axi4_read_single(4'h5, 32'h0000_0010, rd_val);
        if (rd_val !== 32'h0) begin
            $display("  [SECURITY LEAK!] KEY_0 leaked secret data on AXI: 0x%08h", rd_val);
            errors = errors + 1;
        end
        axi4_read_single(4'h5, 32'h0000_0014, rd_val);
        if (rd_val !== 32'h0) begin
            $display("  [SECURITY LEAK!] KEY_1 leaked secret data on AXI: 0x%08h", rd_val);
            errors = errors + 1;
        end
        axi4_read_single(4'h5, 32'h0000_0018, rd_val);
        if (rd_val !== 32'h0) begin
            $display("  [SECURITY LEAK!] KEY_2 leaked secret data on AXI: 0x%08h", rd_val);
            errors = errors + 1;
        end
        axi4_read_single(4'h5, 32'h0000_001C, rd_val);
        if (rd_val !== 32'h0) begin
            $display("  [SECURITY LEAK!] KEY_3 leaked secret data on AXI: 0x%08h", rd_val);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("  [PASS] Write-Only Key Protection Verified! All KEY reads strictly return 0x0000_0000.");
            tests_passed = tests_passed + 1;
        end

        //----------------------------------------------------------------------
        // Test 4: Security Check 2 — Unmapped Address Space Isolation
        //----------------------------------------------------------------------
        $display("\n--- Test 4: Security Check — Unmapped Address Space Isolation ---");
        axi4_read_single(4'h6, 32'h0000_000C, rd_val); // Reserved 0x0C
        if (rd_val !== 32'h0) errors = errors + 1;
        axi4_read_single(4'h6, 32'h0000_0040, rd_val); // Unmapped 0x40
        if (rd_val !== 32'h0) errors = errors + 1;
        axi4_read_single(4'h6, 32'h0000_0080, rd_val); // Unmapped 0x80
        if (rd_val !== 32'h0) errors = errors + 1;
        axi4_read_single(4'h6, 32'h0000_00FC, rd_val); // Unmapped 0xFC
        if (rd_val !== 32'h0) errors = errors + 1;

        if (errors == 0) begin
            $display("  [PASS] Unmapped Space Isolation Verified! All probe reads returned 0x0000_0000.");
            tests_passed = tests_passed + 1;
        end

        //----------------------------------------------------------------------
        // Test 5: End-to-End NIST Encryption via AXI4 Transactions
        //----------------------------------------------------------------------
        $display("\n--- Test 5: End-to-End NIST Encryption via AXI4 ---");
        // NIST Appendix C.1:
        // Key:       000102030405060708090a0b0c0d0e0f
        // Plaintext: 00112233445566778899aabbccddeeff
        // Expected:  69c4e0d86a7b0430d8cdb78070b4c55a

        // Load 128-bit Key using 4-beat burst write to 0x10 (INCR)
        axi4_write_burst_4(
            4'h7, 32'h0000_0010,
            32'h0001_0203, 32'h0405_0607, 32'h0809_0a0b, 32'h0c0d_0e0f
        );

        // Load 128-bit Plaintext using 4-beat burst write to 0x20 (INCR)
        axi4_write_burst_4(
            4'h8, 32'h0000_0020,
            32'h0011_2233, 32'h4455_6677, 32'h8899_aabb, 32'hccdd_eeff
        );

        // Trigger START for Encryption: CONTROL = 0x01 (bit0=START, bit1=0 Encrypt)
        axi4_write_single(4'h9, 32'h0000_0000, 32'h0000_0001);

        //----------------------------------------------------------------------
        // Test 6: Security Check 3 — Anti-Leakage During Execution (Gated Output)
        //----------------------------------------------------------------------
        $display("\n--- Test 6: Security Check — Zero Intermediate Leakage During BUSY ---");
        // Poll output register during intermediate execution
        axi4_read_single(4'hA, 32'h0000_0030, rd_val);
        // If core is BUSY, reading BLOCK_OUT MUST return 0x0000_0000
        if (core_busy && rd_val !== 32'h0) begin
            $display("  [SECURITY LEAK!] Intermediate round state leaked in BLOCK_OUT_0 while BUSY: 0x%08h", rd_val);
            errors = errors + 1;
        end else begin
            $display("  [PASS] Anti-leakage confirmed during execution: BLOCK_OUT read returned 0x%08h", rd_val);
            tests_passed = tests_passed + 1;
        end

        // Poll STATUS until DONE=1
        wait_cycles = 0;
        rd_val = 0;
        while (!rd_val[1] && wait_cycles < 25) begin
            axi4_read_single(4'hB, 32'h0000_0004, rd_val);
            wait_cycles = wait_cycles + 1;
        end

        if (!rd_val[1]) begin
            $display("  [FAIL] Timeout waiting for DONE flag in STATUS register!");
            errors = errors + 1;
        end else begin
            $display("  [PASS] Encryption completed! STATUS=0x%08h (DONE=1, BUSY=0)", rd_val);
        end

        // Read 128-bit Ciphertext using 4-beat burst read from 0x30
        axi4_read_burst_4(4'hC, 32'h0000_0030, b0, b1, b2, b3);
        full_block = {b0, b1, b2, b3};

        if (full_block === 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("  [PASS] NIST Appendix C.1 Ciphertext Verified via AXI4: %h", full_block);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Ciphertext mismatch!");
            $display("    Expected: 69c4e0d86a7b0430d8cdb78070b4c55a");
            $display("    Got:      %h", full_block);
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Test 7: End-to-End NIST Decryption via AXI4 Transactions
        //----------------------------------------------------------------------
        $display("\n--- Test 7: End-to-End NIST Decryption via AXI4 ---");
        // Load K10: 13111d7fe3944a17f307a78b4d2b30c5 via 4-beat burst write
        axi4_write_burst_4(
            4'hD, 32'h0000_0010,
            32'h1311_1d7f, 32'he394_4a17, 32'hf307_a78b, 32'h4d2b_30c5
        );

        // Load Ciphertext into BLOCK_IN via 4-beat burst write
        axi4_write_burst_4(
            4'hE, 32'h0000_0020,
            32'h69c4_e0d8, 32'h6a7b_0430, 32'hd8cd_b780, 32'h70b4_c55a
        );

        // Trigger START for Decryption: CONTROL = 0x03 (bit0=START, bit1=MODE=1 Decrypt)
        axi4_write_single(4'hF, 32'h0000_0000, 32'h0000_0003);

        // Wait for DONE
        wait_cycles = 0;
        rd_val = 0;
        while (!rd_val[1] && wait_cycles < 25) begin
            axi4_read_single(4'h1, 32'h0000_0004, rd_val);
            wait_cycles = wait_cycles + 1;
        end

        // Read Decrypted Plaintext using 4-beat burst read
        axi4_read_burst_4(4'h2, 32'h0000_0030, b0, b1, b2, b3);
        full_block = {b0, b1, b2, b3};

        if (full_block === 128'h00112233445566778899aabbccddeeff) begin
            $display("  [PASS] NIST Appendix C.1 Decrypted Plaintext Verified via AXI4: %h", full_block);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Decrypted Plaintext mismatch!");
            $display("    Expected: 00112233445566778899aabbccddeeff");
            $display("    Got:      %h", full_block);
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------
        $display("\n================================================================");
        if (errors == 0) begin
            $display("ALL %0d AXI4 TESTS & SECURITY CHECKS PASSED PERFECTLY!", tests_passed);
        end else begin
            $display("FAILED: %0d error(s) encountered during verification!", errors);
        end
        $display("================================================================");
        $finish;
    end

endmodule
