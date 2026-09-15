
`include "./rtl/define.svh"
`define SIMULATION

module datapath (
    input  logic clk,
    input  logic rst_n, // reset pc
    input  logic rf_we,
    input  logic alu_src_sel,
    input  logic pc_en,
    input  logic [2:0] jump,
    input  logic [2:0] rf_src_sel,
    input  logic [3:0] alu_control,
    input  logic [31:0] bus_rdata,
    input  logic [31:0] instr_code,
    output logic [31:0] instr_addr,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata
);

    logic [31:0] alu_result, w_rf_rdata0, w_rf_rdata1;
    logic [31:0] dec_rs1, dec_rs2, dec_imm;
    logic [31:0] imm_extend, alu_src_mux_out;
    logic [31:0] wb_mux_out;
    logic [31:0] pc_plus_4, pc_plus_offset, pc_next;
    logic [31:0] exe_alu, exe_pc_next, exe_rs2;

    logic [31:0] mem_bus_rdata;
    logic b_taken;

    assign bus_addr = exe_alu;
    assign bus_wdata = exe_rs2;
    assign instr_addr = exe_pc_next;

    // mem to wb
    register MEM2WB_BUS_RDATA (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(bus_rdata),
        .q(mem_bus_rdata)
    );

    // decode

    reg_file U_REG_FILE (
        .clk(clk),
        .rst_n(rst_n),
        .ra0(instr_code[19:15]),
        .ra1(instr_code[24:20]),
        .wa(instr_code[11:7]),
        .we(rf_we),
        .wdata(wb_mux_out),
        .rdata0(w_rf_rdata0),
        .rdata1(w_rf_rdata1)
    );

    imm_extender U_IMM_EXT (
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    // decode -> execute

    register DE2EXE_RS1 (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(w_rf_rdata0),
        .q(dec_rs1)
    );

    register DE2EXE_RS2 (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(w_rf_rdata1),
        .q(dec_rs2)
    );

    register DE2EXE_IMM (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(imm_extend),
        .q(dec_imm)
    );

    // execute

    mux_2x1 U_ALU_SRC_MUX (
        .mux_sel(alu_src_sel),
        .in0(dec_rs2),
        .in1(dec_imm),
        .mux_out(alu_src_mux_out)
    );

    alu U_ALU (
        .alu_control(alu_control),
        .rs1(dec_rs1),
        .rs2(alu_src_mux_out),
        .alu_result(alu_result),
        .b_taken(b_taken)
    );

    mux_5x1 U_WB_MUX (
        .mux_sel(rf_src_sel),
        .in0(alu_result),
        .in1(mem_bus_rdata),
        .in2(dec_imm),
        .in3(pc_plus_offset),
        .in4(pc_plus_4),
        .mux_out(wb_mux_out)
    );

    program_counter U_PC (
        .clk(clk),
        .rst_n(rst_n),
        .jump(jump),
        .pc(exe_pc_next),
        .b_taken(b_taken),
        .offset(dec_imm),
        .pc_4(pc_plus_4),
        .pc_offset(pc_plus_offset),
        .reg_offset(alu_result),
        .pc_next(pc_next)
    );

    // execute -> memory

    register EXE2MEM_ALU (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(alu_result),
        .q(exe_alu)
    );

    register EXE2MEM_RS2 (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .d_in(dec_rs2),
        .q(exe_rs2)
    );

    // execute -> fetch

    register EXE2FE_PC_NEXT (
        .clk(clk),
        .rst_n(rst_n),
        .enable(pc_en),
        .d_in(pc_next),
        .q(exe_pc_next)
    );


endmodule

module register (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic [31:0] d_in,
    output logic [31:0] q
);

    always_ff @(posedge clk) begin
        if (!rst_n) q <= 31'd0;
        else if (enable) q <= d_in;
    end

endmodule

module reg_file (
    input  logic clk,
    input  logic rst_n,
    input  logic [4:0] ra0,
    input  logic [4:0] ra1,
    input  logic [4:0] wa,
    input  logic we,
    input  logic [31:0] wdata,
    output logic [31:0] rdata0,
    output logic [31:0] rdata1
);

    logic [31:0] register_file [1:31];


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            `ifdef SIMULATION
                for (int i =1; i<32;i++)
                    register_file[i] = i;

                register_file[10] = 32'hffff_ffff;
                register_file[11] = 32'h8000_0000;
                register_file[12] = 32'hffff_fffd;
                register_file[13] = 32'hffff_fffa;
                register_file[14] = 32'h0000_0021;
           `endif
        end else begin
            if (we)
                register_file[wa] <= wdata;
        end
    end

    assign rdata0 = (ra0 == 0) ? 32'd0 : register_file[ra0];
    assign rdata1 = (ra1 == 0) ? 32'd0 : register_file[ra1];

endmodule

module alu (
    input  logic [3:0] alu_control,
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    output logic [31:0] alu_result,
    output logic        b_taken    // branch(1) or not(0)
);

    always_comb begin
        alu_result = 32'd0;
        case (alu_control)
            // {funct7[5], funct3}
            `ADD : alu_result = rs1 + rs2; // add
            `SUB : alu_result = rs1 - rs2; // sub
            `XOR : alu_result = rs1 ^ rs2; // xor
            `OR  : alu_result = rs1 | rs2; // or
            `AND : alu_result = rs1 & rs2; // and
            `SLL : alu_result = rs1 << rs2[4:0]; // sll
            `SRL : alu_result = rs1 >> rs2[4:0]; // srl
            `SRA : alu_result = $signed(rs1) >>> rs2[4:0]; // sra
            `SLT : alu_result = ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0; // slt
            `SLTU: alu_result = (rs1 < rs2) ? 32'd1 : 32'd0; // sltu
       endcase
    end

    always_comb begin
        b_taken = 0;
        case (alu_control)
            // funct3
            `BEQ : b_taken = rs1 == rs2; // beq
            `BNE : b_taken = rs1 != rs2; // bne
            `BLT : b_taken = $signed(rs1) <  $signed(rs2); // blt
            `BGE : b_taken = $signed(rs1) >= $signed(rs2); // bge
            `BLTU: b_taken = rs1 <  rs2; // bltu
            `BGEU: b_taken = rs1 >= rs2; // bgeu
        endcase
    end

endmodule

module mux_2x1 (
    input  logic mux_sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    output logic [31:0] mux_out
);

    assign mux_out = (mux_sel) ? in1 : in0;

endmodule

module mux_3x1_one_hot (
    input  logic [1:0] mux_sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    output logic [31:0] mux_out
);

    always_comb begin
        mux_out = in0;
        case (mux_sel)
            2'b00: mux_out = in0; // general (pc += 4)
            2'b01: mux_out = in1; // b typie, jal (pc += imm)
            2'b10: mux_out = in2; // jalr (pc = rs1 + imm)
        endcase
    end
endmodule

module mux_5x1 (
    input  logic [2:0] mux_sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    input  logic [31:0] in3,
    input  logic [31:0] in4,
    output logic [31:0] mux_out
);

    always_comb begin
        mux_out = in0;
        case (mux_sel)
            3'b000: mux_out = in0;
            3'b001: mux_out = in1;
            3'b010: mux_out = in2;
            3'b011: mux_out = in3;
            3'b100: mux_out = in4;
        endcase
    end

endmodule

module imm_extender

import rv32i_pkg::*;
(
    input  logic [31:0] instr_code,
    output logic [31:0] imm_extend
);
    // immediates always sign extends

    opcode_e opcode;

    // opcode_e' : casting operator
    assign opcode = opcode_e'(instr_code[6:0]);

    always_comb begin
        imm_extend = 32'd0;
        case (opcode)
            // s type: 12bit -> 32bit
            OP_STYPE : imm_extend = {
                {20{instr_code[31]}},
                instr_code[31:25],
                instr_code[11:7]
            };

            // i type: 12bit -> 32bit
           // OP_ITYPE : imm_extend = {
           //     {20{instr_code[31]}},
           //     ((instr_code[14:12] == 3'b101) || (instr_code[14:12] ==3'b001))
           //         // srli, srai, slli -> lower 5 bit shamt (imm)
           //         ? { {6{instr_code[24]}} ,instr_code[24:20]}
           //         // addi, slti, sltiu, xori, ori, andi, slli, stli, srai -> 11bit imm
           //         : instr_code[31:20]
           // };
						OP_ITYPE : imm_extend =
                ((instr_code[14:12] == 3'b101) || (instr_code[14:12] ==3'b001))
                    // srli, srai, slli -> lower 5 bit shamt (imm)
                    ? {27'b0, instr_code[24:20]}
										:	{{20{instr_code[31]}}, instr_code[31:20]};
                    // addi, slti, sltiu, xori, ori, andi, slli, stli, srai -> 11bit imm

            // il type: 12bit -> 32bit
            OP_ILTYPE : imm_extend = {
                {20{instr_code[31]}},
                instr_code[31:20]
            };

            // b type: 12 bit -> 32bit
            OP_BTYPE : imm_extend = {
                {19{instr_code[31]}},
                instr_code[31],
                instr_code[7],
                instr_code[30:25],
                instr_code[11:8],
                1'b0 // last bit -> 0, 2 byte adress
            };

            // u type: 20 bit -> 32 bit (zero padding)
            OP_UTYPE_LUI, OP_UTYPE_AUIPC : imm_extend = {
                instr_code[31:12],
                12'd0
            };

            // j type (jal): 20 -> 32bit
            OP_JTYPE : imm_extend = {
                {11{instr_code[31]}},
                instr_code[31],
                instr_code[19:12],
                instr_code[20],
                instr_code[30:21],
                1'b0
            };

            // jl type (jalr): 12 -> 32bit
            OP_JLTYPE: imm_extend = {
                {20{instr_code[31]}},
                instr_code[31:20]
            };
        endcase
    end

endmodule

module program_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic [2:0] jump,
    input  logic b_taken,
    input  logic [31:0] pc,
    input  logic [31:0] offset,
    input  logic [31:0] reg_offset,
    output logic [31:0] pc_4,
    output logic [31:0] pc_offset,
    output logic [31:0] pc_next
);
    //logic [31:0] register_pc;
    //logic [31:0] pc_next;
    logic [1:0] pc_srcsel;

    //assign pc = register_pc;
    assign pc_srcsel = {1'b0, (b_taken & jump[0])} | jump[2:1];
    assign pc_4 = pc + 4;
    assign pc_offset = pc + offset;

    //always_ff @(posedge clk) begin
    //    if (!rst_n) register_pc <= 0;
    //    else register_pc <= pc_next;
    //end

    mux_3x1_one_hot U_PC_IMM_PC4 (
        .mux_sel(pc_srcsel),
        .in0(pc_4),         // general
        .in1(pc_offset),       // b type, jal
        .in2(reg_offset),   // jalr
        .mux_out(pc_next)
    );

endmodule
