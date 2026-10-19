// =====================================================================
// register_file_tb.v — Unit testbench for register_file.v
// Checks reset behavior, write-then-read, and dual simultaneous reads.
// =====================================================================
`timescale 1ns/1ps

module register_file_tb;

    reg        clk = 0;
    reg        rst;
    reg        we;
    reg  [1:0] waddr, raddr1, raddr2;
    reg  [7:0] wdata;
    wire [7:0] rdata1, rdata2;

    integer errors = 0;

    register_file #(.WIDTH(8), .ADDR(2)) dut (
        .clk(clk), .rst(rst), .we(we),
        .waddr(waddr), .wdata(wdata),
        .raddr1(raddr1), .raddr2(raddr2),
        .rdata1(rdata1), .rdata2(rdata2)
    );

    always #5 clk = ~clk;

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
        $dumpfile("sim/register_file_tb.vcd");
        $dumpvars(0, register_file_tb);

        // Reset: all registers should read 0
        rst = 1; we = 0; waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 1;
        @(posedge clk); #1;
        check(8'd0, rdata1, "post-reset R0");
        rst = 0;

        // Write R2 = 77
        @(negedge clk);
        we = 1; waddr = 2'd2; wdata = 8'd77;
        @(posedge clk); #1;
        we = 0;
        raddr1 = 2'd2;
        #1;
        check(8'd77, rdata1, "R2 after write");

        // Write R3 = 33, then read R2 and R3 simultaneously
        @(negedge clk);
        we = 1; waddr = 2'd3; wdata = 8'd33;
        @(posedge clk); #1;
        we = 0;
        raddr1 = 2'd2; raddr2 = 2'd3;
        #1;
        check(8'd77, rdata1, "simultaneous read: R2");
        check(8'd33, rdata2, "simultaneous read: R3");

        // Write-enable=0 should not modify a register
        @(negedge clk);
        we = 0; waddr = 2'd2; wdata = 8'd200;
        @(posedge clk); #1;
        raddr1 = 2'd2;
        #1;
        check(8'd77, rdata1, "write ignored when we=0");

        if (errors == 0)
            $display("\n=== REGISTER FILE TESTBENCH: ALL TESTS PASSED ===");
        else
            $display("\n=== REGISTER FILE TESTBENCH: %0d FAILURE(S) ===", errors);

        $finish;
    end

endmodule
