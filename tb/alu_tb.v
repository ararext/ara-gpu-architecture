// =====================================================================
// alu_tb.v — Unit testbench for alu.v
// Exercises every supported opcode with known operand pairs.
// =====================================================================
`timescale 1ns/1ps

module alu_tb;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       zero;

    integer errors = 0;

    alu #(.WIDTH(8)) dut (
        .a(a), .b(b), .op(op),
        .result(result), .zero(zero)
    );

    task check(input [7:0] expected, input [127:0] name);
        begin
            if (result !== expected) begin
                $display("FAIL: %0s  a=%0d b=%0d op=%0h  expected=%0d got=%0d",
                          name, a, b, op, expected, result);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s  a=%0d b=%0d op=%0h  result=%0d",
                          name, a, b, op, result);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/alu_tb.vcd");
        $dumpvars(0, alu_tb);

        a = 8'd10; b = 8'd5; op = 4'h1; #1; check(8'd15, "ADD");
        a = 8'd10; b = 8'd5; op = 4'h2; #1; check(8'd5,  "SUB");
        a = 8'd10; b = 8'd5; op = 4'h3; #1; check(8'd50, "MUL");
        a = 8'hF0; b = 8'h0F; op = 4'h4; #1; check(8'h00, "AND");
        a = 8'hF0; b = 8'h0F; op = 4'h5; #1; check(8'hFF, "OR");
        a = 8'hFF; b = 8'h0F; op = 4'h6; #1; check(8'hF0, "XOR");
        a = 8'b00000011; b = 8'd2; op = 4'h7; #1; check(8'b00001100, "SHL");
        a = 8'b00001100; b = 8'd2; op = 4'h8; #1; check(8'b00000011, "SHR");
        a = 8'd5; b = 8'd5; op = 4'h9; #1;
            if (zero !== 1'b1) begin
                $display("FAIL: CMP equal operands should set zero flag");
                errors = errors + 1;
            end else
                $display("PASS: CMP  a=%0d b=%0d  zero=%0d", a, b, zero);
        a = 8'd99; b = 8'd42; op = 4'hA; #1; check(8'd42, "MOVI (passthrough of b)");

        // MUL truncation edge case — 20*20=400, which wraps in 8 bits (400 mod 256 = 144)
        a = 8'd20; b = 8'd20; op = 4'h3; #1; check(8'd144, "MUL truncation edge case");

        if (errors == 0)
            $display("\n=== ALU TESTBENCH: ALL TESTS PASSED ===");
        else
            $display("\n=== ALU TESTBENCH: %0d FAILURE(S) ===", errors);

        $finish;
    end

endmodule
