`timescale 1ns / 1ps
// cpu + rom
module rv32i_top (
    input logic clk,
    input logic rst,
    input logic [11:0] sw,
    output logic [11:0] led
);

    logic [31:0] instr_code, instr_code_reg, instr_addr;
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic [2:0] d_inst_type;
    logic bus_we, ready, transfer;
    logic rst_n;

    assign rst_n = ~rst;
    assign led[11:8] = sw[11:8];

    // apb interface
    // 0: RAM
    // 1: GPI
    // 2: GPO
    // 3: GPIO
    // 4: FND
    // 5: UART
    logic p_write;
    logic p_enable;
    logic [31:0] p_addr;
    logic [31:0] p_wdata;
    logic p_sel0, p_sel1, p_sel2, p_sel3, p_sel4, p_sel5, p_sel6;
    logic p_ready0, p_ready1, p_ready2, p_ready3, p_ready4, p_ready5, p_ready6;
    logic [31:0]
        p_rdata0, p_rdata1, p_rdata2, p_rdata3, p_rdata4, p_rdata5, p_rdata6;
    logic [7:0] gpi_control, gpi_data;
    logic fe2dec_en;

    instruction_rom U_ROM (
        .instr_code(instr_code),
        .*
    );

    // instruction_rom U_ROM (
    //     .*
    // );

    // fetch to decode
    register FE2DEC_INST (
        .clk(clk),
        .rst_n(rst_n),
        .enable(fe2dec_en),
        .d_in(instr_code),
        .q(instr_code_reg)
    );

    rv32i_cpu U_CPU (
        .instr_code(instr_code_reg),
        .fe2dec_en(fe2dec_en),
        .*
    );

    // rv32i_cpu U_CPU (
    //     .*
    // );

    apb_requester U_APB_REQ (.*);

    apb_bram U_APB_RAM_COM (
        .p_sel  (p_sel0),
        .p_rdata(p_rdata0),
        .p_ready(p_ready0),
        .*
    );

    gpi_ctr U_GPI_CNTL (
        .p_sel  (p_sel1),
        .p_rdata(p_rdata1),
        .p_ready(p_ready1),
        .*
    );

    gpi_ip U_GPI_IP (
        .switch_data(sw[7:0]),
        .*
    );

    gpo_ctr U_GPO_CNTL (
        .p_sel(p_sel2),
        .gpo_data(led[7:0]),
        .p_ready(p_ready2),
        .*
    );

endmodule

// cpu
module rv32i_cpu (
    input logic clk,
    input logic rst_n,
    input logic ready,  // from apb
    input logic [31:0] instr_code,
    input logic [31:0] bus_rdata,
    output logic transfer,  // to apb
    output logic [31:0] instr_addr,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic bus_we,
    output logic [2:0] d_inst_type,
    output logic fe2dec_en
);
    logic [3:0] alu_control;
    logic rf_we, alu_src_sel, pc_en;
    logic [2:0] rf_src_sel;
    logic [2:0] jump;
    logic dec2exe_en, exe2mem_en, mem2wb_en;

    control_unit U_CNTL_UNIT (.*);

    datapath U_DATAPATH (.*);

endmodule

// cpu
// module rv32i_cpu (
//     input  logic clk,
//     input  logic rst_n,
//     input  logic [31:0] instr_code,
//     input  logic [31:0] bus_rdata,
//     output logic [31:0] instr_addr,
//     output logic [31:0] bus_addr,
//     output logic [31:0] bus_wdata,
//     output logic transfer,
//     output logic bus_we,
//     output logic [2:0] d_inst_type
// );
//     logic [3:0] alu_control;
//     logic rf_we, alu_src_sel;
//     logic [2:0] rf_src_sel;
//     logic [1:0] jump;

//     single_control_unit U_CNTL_UNIT (
//         .*
//     );
    
//     single_datapath U_DATAPATH (
//         .*
//     ); 

// endmodule
