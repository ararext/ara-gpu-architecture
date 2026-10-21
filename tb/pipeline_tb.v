// =====================================================================
// pipeline_tb.v — Segment 2 testbench
//
// Runs ONE program on four CPUs at the same time:
//   base : Segment 1 single-cycle CPU (the golden reference)
//   m0   : pipelined, HAZARD_MODE 0 (no protection  — expected to be wrong
//          on programs with close dependencies)
//   m1   : pipelined, HAZARD_MODE 1 (stall / interlock)
//   m2   : pipelined, HAZARD_MODE 2 (forwarding)
//
// Checks:
//   1. base, m1, m2 end with the expected register values.
//   2. m0 is WRONG when HAS_HAZARDS=1 (proves the test can detect the bug)
//      and RIGHT when HAS_HAZARDS=0.
//   3. Bookkeeping invariants:  cycles == retired + 3 + stalls
//      retired == number of instructions the baseline executed
//      forwarding mode needs zero stalls.
// Override PROG / E0..E3 / HAS_HAZARDS from the command line (see run_tests.sh).
// =====================================================================
`timescale 1ns/1ps

module pipeline_tb;

    parameter        NAME        = "program";
    parameter        PROG        = "sim/program.hex";
    parameter [7:0]  E0          = 8'd10;
    parameter [7:0]  E1          = 8'd5;
    parameter [7:0]  E2          = 8'd50;
    parameter [7:0]  E3          = 8'd5;
    parameter        HAS_HAZARDS = 1;

    reg clk = 0;
    reg rst;
    always #5 clk = ~clk;

    // ---------------- DUTs ----------------
    wire        b_halted;
    wire [7:0]  b_r0, b_r1, b_r2, b_r3;
    cpu_top #(.PROG_FILE(PROG)) base (
        .clk(clk), .rst(rst), .halted(b_halted),
        .r0_dbg(b_r0), .r1_dbg(b_r1), .r2_dbg(b_r2), .r3_dbg(b_r3));

    wire        h0, h1, h2;
    wire [7:0]  a0, a1, a2, a3;    // m0 registers
    wire [7:0]  c0, c1, c2, c3;    // m1 registers
    wire [7:0]  d0, d1, d2, d3;    // m2 registers
    wire [31:0] cyc0, ret0, stl0, cyc1, ret1, stl1, cyc2, ret2, stl2;

    cpu_pipelined #(.PROG_FILE(PROG), .HAZARD_MODE(0)) m0 (
        .clk(clk), .rst(rst), .halted(h0),
        .r0_dbg(a0), .r1_dbg(a1), .r2_dbg(a2), .r3_dbg(a3),
        .cycle_cnt(cyc0), .retired_cnt(ret0), .stall_cnt(stl0));

    cpu_pipelined #(.PROG_FILE(PROG), .HAZARD_MODE(1)) m1 (
        .clk(clk), .rst(rst), .halted(h1),
        .r0_dbg(c0), .r1_dbg(c1), .r2_dbg(c2), .r3_dbg(c3),
        .cycle_cnt(cyc1), .retired_cnt(ret1), .stall_cnt(stl1));

    cpu_pipelined #(.PROG_FILE(PROG), .HAZARD_MODE(2)) m2 (
        .clk(clk), .rst(rst), .halted(h2),
        .r0_dbg(d0), .r1_dbg(d1), .r2_dbg(d2), .r3_dbg(d3),
        .cycle_cnt(cyc2), .retired_cnt(ret2), .stall_cnt(stl2));

    // Cycle counter for the single-cycle baseline (1 instruction per cycle).
    integer base_cycles = 0;
    reg     base_done   = 0;
    always @(posedge clk) begin
        if (!rst && !base_done) begin
            base_cycles = base_cycles + 1;
            if (b_halted) base_done = 1;
        end
    end

    // ---------------- Checking ----------------
    integer errors = 0;

    wire base_ok = (b_r0 === E0) && (b_r1 === E1) && (b_r2 === E2) && (b_r3 === E3);
    wire m0_ok   = (a0 === E0) && (a1 === E1) && (a2 === E2) && (a3 === E3);
    wire m1_ok   = (c0 === E0) && (c1 === E1) && (c2 === E2) && (c3 === E3);
    wire m2_ok   = (d0 === E0) && (d1 === E1) && (d2 === E2) && (d3 === E3);

    task verify(input cond, input [8*60:1] msg);
        begin
            if (!cond) begin
                $display("  FAIL: %0s", msg);
                errors = errors + 1;
            end else
                $display("  PASS: %0s", msg);
        end
    endtask

    initial begin
        #20000;
        $display("TIMEOUT: a CPU never halted");
        $finish;
    end

    reg [8*64:1] vcd_name;
    initial begin
        $sformat(vcd_name, "sim/pipeline_%0s.vcd", NAME);
        $dumpfile(vcd_name);
        $dumpvars(0, pipeline_tb);

        rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;

        wait (b_halted && h0 && h1 && h2);
        // HALT is in writeback right now. Wait for the clock edge that ends
        // that final cycle so the performance counters include it.
        @(posedge clk); #1;

        $display("\n=== Program: %0s  (expected R0..R3 = %0d %0d %0d %0d) ===",
                 NAME, E0, E1, E2, E3);
        $display("  %-26s  R0..R3            cycles stalls  CPI", "CPU");
        $display("  %-26s  %0d %0d %0d %0d%s %6d %6d  %0.2f", "single-cycle (Segment 1)",
                 b_r0, b_r1, b_r2, b_r3, "", base_cycles, 0, 1.0);
        $display("  %-26s  %0d %0d %0d %0d%s %6d %6d  %0.2f", "pipelined, no protection",
                 a0, a1, a2, a3, "", cyc0, stl0, cyc0 * 1.0 / ret0);
        $display("  %-26s  %0d %0d %0d %0d%s %6d %6d  %0.2f", "pipelined, stall",
                 c0, c1, c2, c3, "", cyc1, stl1, cyc1 * 1.0 / ret1);
        $display("  %-26s  %0d %0d %0d %0d%s %6d %6d  %0.2f", "pipelined, forwarding",
                 d0, d1, d2, d3, "", cyc2, stl2, cyc2 * 1.0 / ret2);
        $display("");

        verify(base_ok, "single-cycle baseline matches expected registers");
        verify(m1_ok,   "stall mode matches expected registers");
        verify(m2_ok,   "forwarding mode matches expected registers");
        if (HAS_HAZARDS)
            verify(!m0_ok, "unprotected pipeline is WRONG (test detects the hazard)");
        else
            verify(m0_ok,  "unprotected pipeline is right (no close dependencies)");

        verify(cyc0 == ret0 + 3 + stl0, "m0: cycles == retired + 3 + stalls");
        verify(cyc1 == ret1 + 3 + stl1, "m1: cycles == retired + 3 + stalls");
        verify(cyc2 == ret2 + 3 + stl2, "m2: cycles == retired + 3 + stalls");
        verify(ret1 == base_cycles && ret2 == base_cycles,
               "retired count equals baseline instruction count");
        verify(stl2 == 0, "forwarding mode needs zero stalls");
        if (HAS_HAZARDS)
            verify(stl1 > 0, "stall mode actually stalled on a hazard program");
        else
            verify(stl1 == 0, "stall mode did not stall on independent code");

        if (errors == 0) $display("\n=== PIPELINE TESTBENCH [%0s]: ALL TESTS PASSED ===", NAME);
        else             $display("\n=== PIPELINE TESTBENCH [%0s]: %0d FAILURE(S) ===", NAME, errors);
        $finish;
    end

endmodule
