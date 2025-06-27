module pipeline_processor(
    input clk,
    input reset
);

// Instruction encoding:
// [15:12] Opcode | [11:8] Rd | [7:4] Rs1 | [3:0] Rs2/Imm
parameter ADD  = 4'b0001;
parameter SUB  = 4'b0010;
parameter LOAD = 4'b0011;

// Simple Register File (16x8)
reg [7:0] regfile [0:15];

// Simple Memory (16x8)
reg [7:0] memory [0:15];

// Program Counter
reg [3:0] PC;

// Pipeline Registers
reg [15:0] IF_ID, ID_EX, EX_WB;
reg [3:0]  PC_IF_ID, PC_ID_EX, PC_EX_WB;

// Pipeline Stage Outputs
reg [7:0] alu_result, wb_data;
reg [3:0] wb_dest;
reg wb_en;

// Sample Program
// ADD R1, R2, R3
// SUB R4, R1, R2
// LOAD R5, [R0+2]
// ADD R6, R5, R1
reg [15:0] instr_mem [0:7];
initial begin
    instr_mem[0] = {ADD, 4'd1, 4'd2, 4'd3};
    instr_mem[1] = {SUB, 4'd4, 4'd1, 4'd2};
    instr_mem[2] = {LOAD, 4'd5, 4'd0, 4'd2};
    instr_mem[3] = {ADD, 4'd6, 4'd5, 4'd1};
    instr_mem[4] = 16'd0;
    instr_mem[5] = 16'd0;
    instr_mem[6] = 16'd0;
    instr_mem[7] = 16'd0;
end

// Reset and sample data
integer i;
always @(posedge reset) begin
    PC <= 0;
    IF_ID <= 0; ID_EX <= 0; EX_WB <= 0;
    for (i=0; i<16; i=i+1) begin
        regfile[i] <= i;
        memory[i] <= i + 10;
    end
end

// IF Stage
wire [15:0] instr = instr_mem[PC];
always @(posedge clk) begin
    if (!reset) begin
        IF_ID <= instr;
        PC_IF_ID <= PC;
        PC <= PC + 1;
    end
end

// ID Stage
reg [3:0] id_opcode, id_rd, id_rs1, id_rs2imm;
reg [7:0] id_rs1_val, id_rs2_val;
always @(posedge clk) begin
    if (!reset) begin
        id_opcode  <= IF_ID[15:12];
        id_rd      <= IF_ID[11:8];
        id_rs1     <= IF_ID[7:4];
        id_rs2imm  <= IF_ID[3:0];
        id_rs1_val <= regfile[IF_ID[7:4]];
        id_rs2_val <= regfile[IF_ID[3:0]];
        ID_EX <= IF_ID;
        PC_ID_EX <= PC_IF_ID;
    end
end

// EX Stage
always @(posedge clk) begin
    if (!reset) begin
        case (ID_EX[15:12])
            ADD:  alu_result <= regfile[ID_EX[7:4]] + regfile[ID_EX[3:0]];
            SUB:  alu_result <= regfile[ID_EX[7:4]] - regfile[ID_EX[3:0]];
            LOAD: alu_result <= memory[regfile[ID_EX[7:4]] + ID_EX[3:0]];
            default: alu_result <= 0;
        endcase
        wb_dest <= ID_EX[11:8];
        wb_en   <= (ID_EX[15:12] != 0);
        EX_WB   <= ID_EX;
        PC_EX_WB <= PC_ID_EX;
        wb_data <= alu_result;
    end
end

// WB Stage
always @(posedge clk) begin
    if (!reset && wb_en) begin
        regfile[wb_dest] <= wb_data;
    end
end

// Optional: Monitor pipeline
always @(posedge clk) begin
    if (!reset) begin
        $display("Cycle %0d", PC_EX_WB);
        $display("IF : %h", instr);
        $display("ID : opcode=%b rd=%d rs1=%d rs2/imm=%d", id_opcode, id_rd, id_rs1, id_rs2imm);
        $display("EX : alu_result=%d wb_dest=%d", alu_result, wb_dest);
        $display("WB : reg[%0d]=%d", wb_dest, regfile[wb_dest]);
        $display("------------------------");
    end
end

endmodule
[6/27, 12:33 PM] Sravani: module testbench;
    reg clk, reset;
    pipeline_processor uut (.clk(clk), .reset(reset));

    initial begin
        clk = 0; reset = 1;
        #5 reset = 0;
        repeat (12) begin
            #5 clk = ~clk;
            #5 clk = ~clk;
        end
        $finish;
    end
endmodule
