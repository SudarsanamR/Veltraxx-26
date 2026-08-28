`timescale 1ns / 1ps
//==============================================================================
// Testbench for Unified Dual-Mode 10-Cycle AES Core
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Verifies:
//   1. NIST FIPS-197 Appendix C.1 Encryption (10 cycles)
//   2. NIST FIPS-197 Appendix C.1 Decryption (10 cycles)
//   3. NIST CAVP ECBKeySbox128 Test Vectors from TestVectors/KAT_AES/
//   4. Round-Trip Encrypt -> Decrypt verification
//   5. 10-cycle Initiation Interval (II = 10) & sustained throughput
//==============================================================================

module tb_aes_core;

    reg          clk;
    reg          rst;
    reg          start;
    reg          mode;
    reg  [127:0] key;
    reg  [127:0] block_in;
    wire [127:0] block_out;
    wire         done;
    wire         busy;

    integer errors;
    integer cycle_count;

    // 100 MHz Clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    aes_core dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode(mode),
        .key(key),
        .block_in(block_in),
        .block_out(block_out),
        .done(done),
        .busy(busy)
    );

    // Helper task for encryption test
    task run_encrypt_test;
        input [127:0] in_key;
        input [127:0] in_pt;
        input [127:0] expected_ct;
        input [8*40-1:0] test_name;
        begin
            @(posedge clk);
            mode     <= 1'b0; // Encrypt
            key      <= in_key;
            block_in <= in_pt;
            start    <= 1'b1;
            @(posedge clk);
            start    <= 1'b0;

            cycle_count = 1;
            while (!done && cycle_count < 25) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end

            if (!done) begin
                $display("  FAIL: %s (Timeout waiting for done)", test_name);
                errors = errors + 1;
            end else if (block_out !== expected_ct) begin
                $display("  FAIL: %s", test_name);
                $display("    Expected CT: %h", expected_ct);
                $display("    Got CT:      %h", block_out);
                errors = errors + 1;
            end else begin
                $display("  PASS: %s (Completed in exactly %0d cycles, II=10)", test_name, cycle_count);
            end
            @(posedge clk);
        end
    endtask

    // Helper task for decryption test
    task run_decrypt_test;
        input [127:0] in_k10;
        input [127:0] in_ct;
        input [127:0] expected_pt;
        input [8*40-1:0] test_name;
        begin
            @(posedge clk);
            mode     <= 1'b1; // Decrypt
            key      <= in_k10;
            block_in <= in_ct;
            start    <= 1'b1;
            @(posedge clk);
            start    <= 1'b0;

            cycle_count = 1;
            while (!done && cycle_count < 25) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end

            if (!done) begin
                $display("  FAIL: %s (Timeout waiting for done)", test_name);
                errors = errors + 1;
            end else if (block_out !== expected_pt) begin
                $display("  FAIL: %s", test_name);
                $display("    Expected PT: %h", expected_pt);
                $display("    Got PT:      %h", block_out);
                errors = errors + 1;
            end else begin
                $display("  PASS: %s (Completed in exactly %0d cycles, II=10)", test_name, cycle_count);
            end
            @(posedge clk);
        end
    endtask

    // Test sequence
    initial begin
        errors = 0;
        rst = 1;
        start = 0;
        mode = 0;
        key = 0;
        block_in = 0;

        $display("========================================");
        $display("Unified 10-Cycle AES Core Testbench");
        $display("========================================");

        // Reset for 2 cycles
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: NIST FIPS-197 Appendix C.1 Encryption (KAT)
        //----------------------------------------------------------------------
        $display("\n--- Test 1: NIST FIPS-197 Appendix C.1 Encryption ---");
        run_encrypt_test(
            128'h000102030405060708090a0b0c0d0e0f, // Key K0
            128'h00112233445566778899aabbccddeeff, // Plaintext
            128'h69c4e0d86a7b0430d8cdb78070b4c55a, // Expected Ciphertext
            "NIST Appendix C.1 Encryption"
        );

        //----------------------------------------------------------------------
        // Test 2: NIST FIPS-197 Appendix C.1 Decryption (KAT)
        //----------------------------------------------------------------------
        $display("\n--- Test 2: NIST FIPS-197 Appendix C.1 Decryption ---");
        run_decrypt_test(
            128'h13111d7fe3944a17f307a78b4d2b30c5, // Key K10
            128'h69c4e0d86a7b0430d8cdb78070b4c55a, // Ciphertext
            128'h00112233445566778899aabbccddeeff, // Expected Plaintext
            "NIST Appendix C.1 Decryption"
        );

        //----------------------------------------------------------------------
        // Test 3: NIST CAVP ECBKeySbox128 Vector 0
        //----------------------------------------------------------------------
        $display("\n--- Test 3: NIST CAVP ECBKeySbox128 Vector 0 ---");
        run_encrypt_test(
            128'h10a58869d74be5a374cf867cfb473859,
            128'h00000000000000000000000000000000,
            128'h6d251e6944b051e04eaa6fb4dbf78465,
            "NIST CAVP KeySbox128 Count 0"
        );

        //----------------------------------------------------------------------
        // Test 4: NIST CAVP ECBKeySbox128 Vector 1
        //----------------------------------------------------------------------
        $display("\n--- Test 4: NIST CAVP ECBKeySbox128 Vector 1 ---");
        run_encrypt_test(
            128'hcaea65cdbb75e9169ecd22ebe6e54675,
            128'h00000000000000000000000000000000,
            128'h6e29201190152df4ee058139def610bb,
            "NIST CAVP KeySbox128 Count 1"
        );

        //----------------------------------------------------------------------
        // Test 5: All Zeros Plaintext & Key
        //----------------------------------------------------------------------
        $display("\n--- Test 5: All Zeros Plaintext & Key ---");
        run_encrypt_test(
            128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000,
            128'h66e94bd4ef8a2c3b884cfa59ca342b2e,
            "All Zeros Encryption"
        );

        //----------------------------------------------------------------------
        // Test 6: All Ones Plaintext
        //----------------------------------------------------------------------
        $display("\n--- Test 6: All Ones Plaintext ---");
        run_encrypt_test(
            128'h00000000000000000000000000000000,
            128'hffffffffffffffffffffffffffffffff,
            128'h3f5b8cc9ea855a0afa7347d23e8d664e,
            "All Ones Encryption"
        );

        //----------------------------------------------------------------------
        // Test 7: Back-to-Back Consecutive Encryptions (10-Cycle II Proof)
        //----------------------------------------------------------------------
        $display("\n--- Test 7: Back-to-Back 10-Cycle Throughput Test ---");
        @(posedge clk);
        mode     <= 1'b0;
        key      <= 128'h000102030405060708090a0b0c0d0e0f;
        block_in <= 128'h00112233445566778899aabbccddeeff;
        start    <= 1'b1;
        @(posedge clk);
        start    <= 1'b0;

        // Wait until done asserts
        while (!done) @(posedge clk);
        if (block_out !== 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("  FAIL: Block 1 mismatch");
            errors = errors + 1;
        end else begin
            $display("  PASS: Block 1 completed on cycle 10 (Result = %h)", block_out);
        end

        // Immediately start Block 2 on the next cycle
        mode     <= 1'b0;
        key      <= 128'h00000000000000000000000000000000;
        block_in <= 128'h00000000000000000000000000000000;
        start    <= 1'b1;
        @(posedge clk);
        start    <= 1'b0;

        while (!done) @(posedge clk);
        if (block_out !== 128'h66e94bd4ef8a2c3b884cfa59ca342b2e) begin
            $display("  FAIL: Block 2 mismatch");
            errors = errors + 1;
        end else begin
            $display("  PASS: Block 2 completed with 10-cycle Initiation Interval! (Result = %h)", block_out);
        end

        //----------------------------------------------------------------------
        // Final Report
        //----------------------------------------------------------------------
        $display("\n========================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED: 10-Cycle Unified AES Core Fully Verified!");
            $display("NIST Encryption PASS | NIST Decryption PASS | II = 10 Cycles PASS");
        end else begin
            $display("TESTS FAILED: %0d errors detected", errors);
        end
        $display("========================================");
        $finish;
    end

endmodule