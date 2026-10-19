// =====================================================================
// cpu_top.v — Segment 1 Baseline CPU (single-cycle)
//
// Fetch (async ROM read) -> Decode (control_unit) -> Execute (ALU) ->
// Writeback (register_file), all within one clock edge. Pipelining with
// explicit pipeline registers and hazard handling is Segment 2's job —
// deliberately not attempted here.
// =====================================================================
module cpu_top #(
    parameter DATA_WIDTH  = 8,
    parameter REG_ADDR    = 2,
    parameter PC_WIDTH    = 4,
    parameter INSTR_WIDTH = 12,
    parameter PROG_FILE   = "program.hex"
) (
    input                     clk,
    input                     rst,
    output                    halted,
    // Debug taps so a testbench (or, later, an LED/UART interface) can
    // observe architectural state without needing internal hierarchy access.
    output [DATA_WIDTH-1:0]   r0_dbg,
    output [DATA_WIDTH-1:0]   r1_dbg,
    output [DATA_WIDTH-1:0]   r2_dbg,
    output [DATA_WIDTH-1:0]   r3_dbg
);

    wire [PC_WIDTH-1:0]    pc;
    wire [INSTR_WIDTH-1:0] instr;

    // ---- Instruction field decode ----
    wire [3:0] opcode   = instr[11:8];
    wire [1:0] rd_addr  = instr[7:6];
    wire [1:0] rs1_addr = instr[5:4];
    wire [3:0] rs2_imm  = instr[3:0];
    wire [1:0] rs2_addr = rs2_imm[1:0];

    // ---- Control signals ----
    wire        reg_write;
    wire [3:0]  alu_op;
    wire        use_imm;
    wire        halt;

    // ---- Datapath signals ----
    wire [DATA_WIDTH-1:0] rdata1, rdata2;
    wire [DATA_WIDTH-1:0] alu_b = use_imm ? {4'b0, rs2_imm} : rdata2;
    wire [DATA_WIDTH-1:0] alu_result;
    wire                  alu_zero;

    assign halted = halt;

    program_counter #(.WIDTH(PC_WIDTH)) u_pc (
        .clk       (clk),
        .rst       (rst),
        .hold      (halt),
        .jump      (1'b0),
        .jump_addr ({PC_WIDTH{1'b0}}),
        .pc        (pc)
    );

    instruction_memory #(
        .ADDR_WIDTH  (PC_WIDTH),
        .INSTR_WIDTH (INSTR_WIDTH),
        .FILE        (PROG_FILE)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    control_unit u_ctrl (
        .opcode    (opcode),
        .reg_write (reg_write),
        .alu_op    (alu_op),
        .use_imm   (use_imm),
        .halt      (halt)
    );

    register_file #(.WIDTH(DATA_WIDTH), .ADDR(REG_ADDR)) u_regs (
        .clk    (clk),
        .rst    (rst),
        .we     (reg_write & ~halt),
        .waddr  (rd_addr),
        .wdata  (alu_result),
        .raddr1 (rs1_addr),
        .raddr2 (rs2_addr),
        .rdata1 (rdata1),
        .rdata2 (rdata2)
    );

    alu #(.WIDTH(DATA_WIDTH)) u_alu (
        .a      (rdata1),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // Debug taps — reach into the register file for waveform/testbench visibility.
    assign r0_dbg = u_regs.regs[0];
    assign r1_dbg = u_regs.regs[1];
    assign r2_dbg = u_regs.regs[2];
    assign r3_dbg = u_regs.regs[3];

endmodule
