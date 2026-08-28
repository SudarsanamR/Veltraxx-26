#!/usr/bin/env python3
"""
NIST CAVP / Known Answer Test (KAT) Automated Verification Suite for AES-128
PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
"""

import os
import sys
import subprocess
import glob

RSP_DIR = "/home/sudar/Documents/Veltraxx/TestVectors/KAT_AES"
PS06_DIR = "/home/sudar/Documents/Veltraxx/ps06_aes"

def parse_rsp_file(filepath):
    """Parse NIST .rsp vector file and return list of test cases."""
    tests = []
    current_mode = None
    current_test = {}
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if line == '[ENCRYPT]':
                current_mode = 'ENCRYPT'
                continue
            elif line == '[DECRYPT]':
                current_mode = 'DECRYPT'
                continue
                
            if '=' in line:
                key, val = [x.strip() for x in line.split('=', 1)]
                if key == 'COUNT':
                    if current_test and 'KEY' in current_test:
                        tests.append(current_test)
                    current_test = {'MODE': current_mode, 'COUNT': val}
                elif key in ('KEY', 'PLAINTEXT', 'CIPHERTEXT'):
                    current_test[key] = val
                    
        if current_test and 'KEY' in current_test:
            tests.append(current_test)
            
    return tests

def generate_tb(test_cases, output_file="tb/tb_nist_kat_runner.v"):
    """Generate synthesizable self-checking testbench for all test cases."""
    lines = []
    lines.append("`timescale 1ns / 1ps")
    lines.append("// Auto-generated NIST CAVP KAT Verification Testbench")
    lines.append("module tb_nist_kat_runner;")
    lines.append("    reg          clk;")
    lines.append("    reg          rst;")
    lines.append("    reg          start;")
    lines.append("    reg          mode;")
    lines.append("    reg  [127:0] key;")
    lines.append("    reg  [127:0] block_in;")
    lines.append("    wire [127:0] block_out;")
    lines.append("    wire         done;")
    lines.append("    wire         busy;")
    lines.append("    integer errors;")
    lines.append("    integer total_tests;")
    lines.append("")
    lines.append("    initial begin clk = 0; forever #5 clk = ~clk; end")
    lines.append("")
    lines.append("    aes_core dut (")
    lines.append("        .clk(clk), .rst(rst), .start(start), .mode(mode),")
    lines.append("        .key(key), .block_in(block_in), .block_out(block_out),")
    lines.append("        .done(done), .busy(busy)")
    lines.append("    );")
    lines.append("")
    lines.append("    task run_test;")
    lines.append("        input        t_mode;")
    lines.append("        input [127:0] t_key;")
    lines.append("        input [127:0] t_in;")
    lines.append("        input [127:0] t_exp;")
    lines.append("        input [8*40-1:0] t_name;")
    lines.append("        begin")
    lines.append("            @(posedge clk);")
    lines.append("            mode     <= t_mode;")
    lines.append("            key      <= t_key;")
    lines.append("            block_in <= t_in;")
    lines.append("            start    <= 1'b1;")
    lines.append("            @(posedge clk);")
    lines.append("            start    <= 1'b0;")
    lines.append("            while (!done) @(posedge clk);")
    lines.append("            if (block_out !== t_exp) begin")
    lines.append("                $display(\"  [FAIL] %s\", t_name);")
    lines.append("                $display(\"    Expected: %h\", t_exp);")
    lines.append("                $display(\"    Got:      %h\", block_out);")
    lines.append("                errors = errors + 1;")
    lines.append("            end")
    lines.append("            total_tests = total_tests + 1;")
    lines.append("            @(posedge clk);")
    lines.append("        end")
    lines.append("    endtask")
    lines.append("")
    lines.append("    initial begin")
    lines.append("        errors = 0;")
    lines.append("        total_tests = 0;")
    lines.append("        rst = 1; start = 0; mode = 0; key = 0; block_in = 0;")
    lines.append("        repeat(2) @(posedge clk);")
    lines.append("        rst = 0; @(posedge clk);")
    lines.append("        $display(\"========================================\");")
    lines.append("        $display(\"Running NIST CAVP KAT Verification Suite\");")
    lines.append("        $display(\"========================================\");")
    lines.append("")

    for i, tc in enumerate(test_cases):
        is_enc = 0 if tc['MODE'] == 'ENCRYPT' else 1
        t_key = tc['KEY']
        t_in = tc['PLAINTEXT'] if is_enc == 0 else tc['CIPHERTEXT']
        t_exp = tc['CIPHERTEXT'] if is_enc == 0 else tc['PLAINTEXT']
        name = f"{tc.get('FILE', 'KAT')}_{tc['MODE']}_{tc['COUNT']}"
        lines.append(f"        run_test({is_enc}, 128'h{t_key}, 128'h{t_in}, 128'h{t_exp}, \"{name}\");")

    lines.append("")
    lines.append("        $display(\"========================================\");")
    lines.append("        if (errors == 0) begin")
    lines.append("            $display(\"ALL %0d NIST CAVP TESTS PASSED!\", total_tests);")
    lines.append("        end else begin")
    lines.append("            $display(\"FAILED: %0d / %0d tests failed\", errors, total_tests);")
    lines.append("        end")
    lines.append("        $display(\"========================================\");")
    lines.append("        $finish;")
    lines.append("    end")
    lines.append("endmodule")

    target = os.path.join(PS06_DIR, output_file)
    with open(target, 'w') as f:
        f.write("\n".join(lines))
    print(f"Generated testbench {target} with {len(test_cases)} NIST test cases.")
    return target

def main():
    target_files = [
        "ECBKeySbox128.rsp",
        "ECBVarKey128.rsp",
        "ECBVarTxt128.rsp",
        "ECBGFSbox128.rsp"
    ]
    
    all_tests = []
    for tf in target_files:
        path = os.path.join(RSP_DIR, tf)
        if os.path.exists(path):
            tests = parse_rsp_file(path)
            for t in tests:
                t['FILE'] = tf.replace('.rsp', '')
            # For [ENCRYPT] tests, key is K0.
            # Filter for ENCRYPT tests to run comprehensive sweep
            enc_tests = [t for t in tests if t['MODE'] == 'ENCRYPT']
            all_tests.extend(enc_tests)
            print(f"Loaded {len(enc_tests)} ENCRYPT vectors from {tf}")
            
    tb_path = generate_tb(all_tests)
    
    print("\n==> Compiling and Simulating with Icarus Verilog...")
    cmd = [
        "iverilog", "-g2012", "-o", "/tmp/sim_nist_suite",
        f"{PS06_DIR}/src/aes/aes_sbox.v",
        f"{PS06_DIR}/src/aes/aes_sbox_canright.v",
        f"{PS06_DIR}/src/aes/aes_inv_sbox.v",
        f"{PS06_DIR}/src/aes/aes_gf_inv.v",
        f"{PS06_DIR}/src/aes/aes_sbox_shared.v",
        f"{PS06_DIR}/src/aes/aes_subbytes_shared.v",
        f"{PS06_DIR}/src/aes/aes_shiftrows.v",
        f"{PS06_DIR}/src/aes/aes_inv_shiftrows.v",
        f"{PS06_DIR}/src/aes/aes_mixcolumns.v",
        f"{PS06_DIR}/src/aes/aes_inv_mixcolumns.v",
        f"{PS06_DIR}/src/aes/aes_mixcolumns_shared.v",
        f"{PS06_DIR}/src/aes/aes_addroundkey.v",
        f"{PS06_DIR}/src/aes/aes_key_expand.v",
        f"{PS06_DIR}/src/aes/aes_controller.v",
        f"{PS06_DIR}/src/aes/aes_core.v",
        tb_path
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Compilation error:\n{res.stderr}")
        sys.exit(1)
        
    sim_res = subprocess.run(["vvp", "/tmp/sim_nist_suite"], capture_output=True, text=True)
    print(sim_res.stdout)
    if "ALL" in sim_res.stdout and "PASSED" in sim_res.stdout:
        print("==> NIST CAVP Vector Suite Verification Succeeded!")
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
