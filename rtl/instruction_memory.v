// =====================================================================
// instruction_memory.v — ROM-style instruction store, loaded from a
// plain hex file via $readmemh. Asynchronous read (Segment 1 baseline);
// will be restyled for synchronous BRAM inference in Segment 7 (FPGA).
// =====================================================================
module instruction_memory #(
    parameter ADDR_WIDTH  = 4,
    parameter INSTR_WIDTH = 12,
    parameter FILE        = "program.hex"
) (
    input      [ADDR_WIDTH-1:0]  addr,
    output     [INSTR_WIDTH-1:0] instr
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [INSTR_WIDTH-1:0] mem [0:DEPTH-1];

    initial begin
        $readmemh(FILE, mem);
    end

    assign instr = mem[addr];

endmodule
