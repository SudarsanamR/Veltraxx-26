`timescale 1ns / 1ps
//==============================================================================
// Testbench for On-The-Fly AES Key Expander (Forward & Reverse)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================

module tb_aes_key_expand;

    reg         dir_inv;
    reg  [3:0]   round_idx;
    reg  [127:0] key_in;
    wire [127:0] key_out;

    integer errors;
    integer r;

    // NIST FIPS-197 Round Keys
    reg [127:0] nist_keys[0:10];

    aes_key_expand dut (
        .dir_inv(dir_inv),
        .round_idx(round_idx),
        .key_in(key_in),
        .key_out(key_out)
    );

    initial begin
        errors = 0;
        $display("========================================");
        $display("On-The-Fly Key Expander Testbench");
        $display("========================================");

        nist_keys[0]  = 128'h000102030405060708090a0b0c0d0e0f;
        nist_keys[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
        nist_keys[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
        nist_keys[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
        nist_keys[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
        nist_keys[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
        nist_keys[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
        nist_keys[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
        nist_keys[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
        nist_keys[9]  = 128'h549932d1f08557681093ed9cbe2c974e;
        nist_keys[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;

        //----------------------------------------------------------------------
        // Test 1: Forward On-The-Fly Expansion (K0 -> K1 -> ... -> K10)
        //----------------------------------------------------------------------
        $display("\n--- Test 1: Forward On-The-Fly Expansion (K0 -> K10) ---");
        dir_inv = 0;
        key_in = nist_keys[0];

        for (r = 1; r <= 10; r = r + 1) begin
            round_idx = r;
            #10;
            if (key_out !== nist_keys[r]) begin
                $display("  FAIL: Round %0d key mismatch", r);
                $display("    Expected: %h", nist_keys[r]);
                $display("    Got:      %h", key_out);
                errors = errors + 1;
            end else begin
                $display("  PASS: Round %0d key match (%h)", r, key_out);
            end
            key_in = key_out; // Chain next step
        end

        //----------------------------------------------------------------------
        // Test 2: Reverse On-The-Fly Expansion (K10 -> K9 -> ... -> K0)
        //----------------------------------------------------------------------
        $display("\n--- Test 2: Reverse On-The-Fly Expansion (K10 -> K0) ---");
        dir_inv = 1;
        key_in = nist_keys[10];

        for (r = 10; r >= 1; r = r - 1) begin
            round_idx = r;
            #10;
            if (key_out !== nist_keys[r-1]) begin
                $display("  FAIL: Reverse Round %0d -> %0d key mismatch", r, r-1);
                $display("    Expected: %h", nist_keys[r-1]);
                $display("    Got:      %h", key_out);
                errors = errors + 1;
            end else begin
                $display("  PASS: Reverse Round %0d -> %0d key match (%h)", r, r-1, key_out);
            end
            key_in = key_out; // Chain next step
        end

        //----------------------------------------------------------------------
        // Final Report
        //----------------------------------------------------------------------
        $display("\n========================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED: On-The-Fly Key Expander Verified!");
        end else begin
            $display("TESTS FAILED: %0d errors", errors);
        end
        $display("========================================");
        $finish;
    end

endmodule
