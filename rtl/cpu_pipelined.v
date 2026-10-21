// =====================================================================
// cpu_pipelined.v — Segment 2: 4-stage pipelined CPU
//
//   IF  : fetch from instruction memory using the PC
//   ID  : decode, read register file, detect hazards
//   EX  : ALU operation (forwarding muxes sit in front of the ALU)
//   WB  : write result back to the register file
//
//   IF/ID, ID/EX and EX/WB are the pipeline registers between stages.
//   Each carries a `valid` bit so a "bubble" (an empty slot inserted by
//   a stall or by draining after HALT) is never mistaken for an instruction.
//
// HAZARD_MODE selects how read-after-write (RAW) hazards are handled:
//   0 = NONE    : no protection. Deliberately UNSAFE; exists to prove the
//                 hazard tests can actually catch a broken pipeline.
//   1 = STALL   : interlock. The instruction in ID waits (a bubble is sent
//                 down the pipe) until its producer has written back.
//   2 = FORWARD : bypass paths. EX/WB result is forwarded into the ALU
//                 inputs, and WB is bypassed into the register read in ID.
//                 No stalls are needed for this ISA (no LOAD yet).
// =====================================================================
module cpu_pipelined #(
    parameter DATA_WIDTH  = 8,
    parameter REG_ADDR    = 2,
    parameter PC_WIDTH    = 4,
    parameter INSTR_WIDTH = 12,
    parameter PROG_FILE   = "program.hex",
    parameter HAZARD_MODE = 2
) (
    input                     clk,
    input                     rst,
    output                    halted,        // HALT has reached writeback
    output [DATA_WIDTH-1:0]   r0_dbg,
    output [DATA_WIDTH-1:0]   r1_dbg,
    output [DATA_WIDTH-1:0]   r2_dbg,
    output [DATA_WIDTH-1:0]   r3_dbg,
    // Performance counters (Segment 2 is where we start quantifying)
    output reg [31:0]         cycle_cnt,     // cycles from reset release to HALT writeback
    output reg [31:0]         retired_cnt,   // instructions that reached writeback
    output reg [31:0]         stall_cnt      // cycles lost to hazard stalls
);

    // =================================================================
    // IF stage
    // =================================================================
    wire [PC_WIDTH-1:0]    pc;
    wire [INSTR_WIDTH-1:0] if_instr;
    wire                   stall;          // hazard interlock (driven from ID)
    wire                   stop_fetch;     // HALT seen: stop fetching new work
    wire                   pc_hold = stall | stop_fetch;

    program_counter #(.WIDTH(PC_WIDTH)) u_pc (
        .clk       (clk),
        .rst       (rst),
        .hold      (pc_hold),
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
        .instr (if_instr)
    );

    // ---------------- IF/ID pipeline register ----------------
    reg [INSTR_WIDTH-1:0] ifid_instr;
    reg                   ifid_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifid_instr <= {INSTR_WIDTH{1'b0}};
            ifid_valid <= 1'b0;
        end else if (stall) begin
            // hold: the stalled instruction stays in ID
        end else if (stop_fetch) begin
            ifid_instr <= {INSTR_WIDTH{1'b0}};   // bubble (NOP)
            ifid_valid <= 1'b0;
        end else begin
            ifid_instr <= if_instr;
            ifid_valid <= 1'b1;
        end
    end

    // =================================================================
    // ID stage
    // =================================================================
    wire [3:0] id_opcode  = ifid_instr[11:8];
    wire [1:0] id_rd      = ifid_instr[7:6];
    wire [1:0] id_rs1     = ifid_instr[5:4];
    wire [3:0] id_rs2_imm = ifid_instr[3:0];
    wire [1:0] id_rs2     = id_rs2_imm[1:0];

    wire        id_reg_write, id_use_imm, id_halt, id_uses_rs1, id_uses_rs2;
    wire [3:0]  id_alu_op;

    control_unit u_ctrl (
        .opcode    (id_opcode),
        .reg_write (id_reg_write),
        .alu_op    (id_alu_op),
        .use_imm   (id_use_imm),
        .halt      (id_halt),
        .uses_rs1  (id_uses_rs1),
        .uses_rs2  (id_uses_rs2)
    );

    // ---- HALT handling: once HALT is decoded, stop fetching and drain ----
    reg  halt_seen;
    wire id_is_halt = ifid_valid & id_halt;
    assign stop_fetch = halt_seen | id_is_halt;

    always @(posedge clk or posedge rst) begin
        if (rst)             halt_seen <= 1'b0;
        else if (id_is_halt) halt_seen <= 1'b1;
    end

    // ---- Register file (written by WB stage) ----
    wire [DATA_WIDTH-1:0] rf_rdata1, rf_rdata2;

    // WB-stage signals (declared here, driven by the EX/WB register below)
    reg                   exwb_valid;
    reg                   exwb_reg_write;
    reg                   exwb_halt;
    reg [REG_ADDR-1:0]    exwb_rd;
    reg [DATA_WIDTH-1:0]  exwb_result;
    wire                  wb_we = exwb_valid & exwb_reg_write;

    register_file #(.WIDTH(DATA_WIDTH), .ADDR(REG_ADDR)) u_regs (
        .clk    (clk),
        .rst    (rst),
        .we     (wb_we),
        .waddr  (exwb_rd),
        .wdata  (exwb_result),
        .raddr1 (id_rs1),
        .raddr2 (id_rs2),
        .rdata1 (rf_rdata1),
        .rdata2 (rf_rdata2)
    );

    // WB -> ID bypass (FORWARD mode only): if the instruction currently in
    // WB is writing the register ID wants to read, take the value directly
    // instead of waiting for it to land in the register file next cycle.
    wire bypass_en  = (HAZARD_MODE == 2);
    wire id_byp1    = bypass_en & wb_we & (exwb_rd == id_rs1);
    wire id_byp2    = bypass_en & wb_we & (exwb_rd == id_rs2);
    wire [DATA_WIDTH-1:0] id_rdata1 = id_byp1 ? exwb_result : rf_rdata1;
    wire [DATA_WIDTH-1:0] id_rdata2 = id_byp2 ? exwb_result : rf_rdata2;

    // ID/EX pipeline register (declared before hazard detection uses it)
    reg                   idex_valid;
    reg                   idex_reg_write;
    reg                   idex_halt;
    reg                   idex_use_imm;
    reg                   idex_uses_rs1;
    reg                   idex_uses_rs2;
    reg [3:0]             idex_alu_op;
    reg [REG_ADDR-1:0]    idex_rd;
    reg [REG_ADDR-1:0]    idex_rs1;
    reg [REG_ADDR-1:0]    idex_rs2;
    reg [3:0]             idex_imm;
    reg [DATA_WIDTH-1:0]  idex_a;
    reg [DATA_WIDTH-1:0]  idex_b;

    // ---- RAW hazard detection (STALL mode) ----
    // The instruction in ID must wait if a still-in-flight older instruction
    // (one in EX or one in WB) is going to write a register it reads.
    wire raw_ex1 = idex_valid & idex_reg_write & id_uses_rs1 & (idex_rd == id_rs1);
    wire raw_ex2 = idex_valid & idex_reg_write & id_uses_rs2 & (idex_rd == id_rs2);
    wire raw_wb1 = exwb_valid & exwb_reg_write & id_uses_rs1 & (exwb_rd == id_rs1);
    wire raw_wb2 = exwb_valid & exwb_reg_write & id_uses_rs2 & (exwb_rd == id_rs2);
    wire hazard  = ifid_valid & (raw_ex1 | raw_ex2 | raw_wb1 | raw_wb2);

    assign stall = (HAZARD_MODE == 1) & hazard;

    // ---------------- ID/EX register update ----------------
    always @(posedge clk or posedge rst) begin
        if (rst || stall) begin
            // reset, or stall: insert a bubble into EX
            idex_valid     <= 1'b0;
            idex_reg_write <= 1'b0;
            idex_halt      <= 1'b0;
            idex_use_imm   <= 1'b0;
            idex_uses_rs1  <= 1'b0;
            idex_uses_rs2  <= 1'b0;
            idex_alu_op    <= 4'h0;
            idex_rd        <= {REG_ADDR{1'b0}};
            idex_rs1       <= {REG_ADDR{1'b0}};
            idex_rs2       <= {REG_ADDR{1'b0}};
            idex_imm       <= 4'h0;
            idex_a         <= {DATA_WIDTH{1'b0}};
            idex_b         <= {DATA_WIDTH{1'b0}};
        end else begin
            idex_valid     <= ifid_valid;
            idex_reg_write <= ifid_valid & id_reg_write;
            idex_halt      <= ifid_valid & id_halt;
            idex_use_imm   <= id_use_imm;
            idex_uses_rs1  <= ifid_valid & id_uses_rs1;
            idex_uses_rs2  <= ifid_valid & id_uses_rs2;
            idex_alu_op    <= id_alu_op;
            idex_rd        <= id_rd;
            idex_rs1       <= id_rs1;
            idex_rs2       <= id_rs2;
            idex_imm       <= id_rs2_imm;
            idex_a         <= id_rdata1;
            idex_b         <= id_rdata2;
        end
    end

    // =================================================================
    // EX stage
    // =================================================================
    // EX/WB -> EX forwarding (FORWARD mode only)
    wire fwd_en = (HAZARD_MODE == 2);
    wire fwd_a  = fwd_en & wb_we & idex_uses_rs1 & (exwb_rd == idex_rs1);
    wire fwd_b  = fwd_en & wb_we & idex_uses_rs2 & (exwb_rd == idex_rs2);

    wire [DATA_WIDTH-1:0] ex_a     = fwd_a ? exwb_result : idex_a;
    wire [DATA_WIDTH-1:0] ex_b_reg = fwd_b ? exwb_result : idex_b;
    wire [DATA_WIDTH-1:0] ex_b     = idex_use_imm
                                   ? {{(DATA_WIDTH-4){1'b0}}, idex_imm}
                                   : ex_b_reg;
    wire [DATA_WIDTH-1:0] alu_result;

    alu #(.WIDTH(DATA_WIDTH)) u_alu (
        .a      (ex_a),
        .b      (ex_b),
        .op     (idex_alu_op),
        .result (alu_result),
        .zero   ()
    );

    // ---------------- EX/WB pipeline register ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exwb_valid     <= 1'b0;
            exwb_reg_write <= 1'b0;
            exwb_halt      <= 1'b0;
            exwb_rd        <= {REG_ADDR{1'b0}};
            exwb_result    <= {DATA_WIDTH{1'b0}};
        end else begin
            exwb_valid     <= idex_valid;
            exwb_reg_write <= idex_valid & idex_reg_write;
            exwb_halt      <= idex_valid & idex_halt;
            exwb_rd        <= idex_rd;
            exwb_result    <= alu_result;
        end
    end

    // =================================================================
    // WB stage: the register-file write is driven by wb_we above.
    // Completion + performance counters
    // =================================================================
    reg done_r;
    assign halted = done_r | (exwb_valid & exwb_halt);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_cnt   <= 32'd0;
            retired_cnt <= 32'd0;
            stall_cnt   <= 32'd0;
            done_r      <= 1'b0;
        end else if (!done_r) begin
            cycle_cnt <= cycle_cnt + 1;
            if (exwb_valid) retired_cnt <= retired_cnt + 1;
            if (stall)      stall_cnt   <= stall_cnt + 1;
            if (exwb_valid & exwb_halt) done_r <= 1'b1;
        end
    end

    // Debug taps
    assign r0_dbg = u_regs.regs[0];
    assign r1_dbg = u_regs.regs[1];
    assign r2_dbg = u_regs.regs[2];
    assign r3_dbg = u_regs.regs[3];

endmodule
