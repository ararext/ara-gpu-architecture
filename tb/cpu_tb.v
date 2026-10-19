// =====================================================================
// cpu_tb.v — Integration testbench for cpu_top.v
// Runs the hand-assembled program in sim/program.hex to completion
// (HALT) and checks final architectural register state against the
// expected values documented in docs/program_listing.md.
// =====================================================================
`timescale 1ns/1ps

module cpu_tb;

    reg clk = 0;
    reg rst;
    wire halted;
    wire [7:0] r0_dbg, r1_dbg, r2_dbg, r3_dbg;

    integer errors = 0;
    integer cycle_count = 0;

    cpu_top #(
        .DATA_WIDTH  (8),
        .REG_ADDR    (2),
        .PC_WIDTH    (4),
        .INSTR_WIDTH (12),
        .PROG_FILE   ("sim/program.hex")
    ) dut (
        .clk    (clk),
        .rst    (rst),
        .halted (halted),
        .r0_dbg (r0_dbg),
        .r1_dbg (r1_dbg),
        .r2_dbg (r2_dbg),
        .r3_dbg (r3_dbg)
    );

    always #5 clk = ~clk;

    // Cycle counter, purely for the "quantify it" habit we want from Segment 1 onward.
    always @(posedge clk) begin
        if (!rst) cycle_count = cycle_count + 1;
    end

    task check(input [7:0] expected, input [7:0] actual, input [127:0] name);
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s  expected=%0d got=%0d", name, expected, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s  value=%0d", name, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        // Run until HALT or a generous timeout (safety net against infinite loops)
        wait (halted == 1'b1 || cycle_count > 100);
        #1;

        if (cycle_count > 100) begin
            $display("FAIL: CPU never asserted halted — check control_unit/HALT decode");
            errors = errors + 1;
        end else begin
            $display("CPU halted after %0d cycles", cycle_count);
        end

        check(8'd10, r0_dbg, "R0 final value");
        check(8'd5,  r1_dbg, "R1 final value");
        check(8'd50, r2_dbg, "R2 final value (ADD then overwritten by MUL)");
        check(8'd5,  r3_dbg, "R3 final value");

        if (errors == 0)
            $display("\n=== CPU INTEGRATION TESTBENCH: ALL TESTS PASSED ===");
        else
            $display("\n=== CPU INTEGRATION TESTBENCH: %0d FAILURE(S) ===", errors);

        $finish;
    end

endmodule
