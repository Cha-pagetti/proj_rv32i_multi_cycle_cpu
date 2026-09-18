module soc_top (
    input logic clk,
    input logic rst_n
);
    // 내부 연결용 신호 선언
    logic [31:0] instr_addr, instr_code, instr_code_reg;
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic [ 2:0] d_inst_type;
    logic transfer, bus_we, ready, fe2dec_en;

    // APB 버스 연결용 신호
    logic p_write, p_enable;
    logic [31:0] p_addr, p_wdata;
    logic p_sel0, p_ready0;
    logic [31:0] p_rdata0;

    // 1. 명령어 메모리 (ROM)
    instruction_rom U_ROM (
        .instr_addr(instr_addr),
        .instr_code(instr_code)
    );

    // [중요] 원본 Top 코드에 있던 Fetch to Decode 파이프라인 레지스터
    always_ff @(posedge clk) begin
        if (!rst_n) instr_code_reg <= 32'b0;
        else if (fe2dec_en) instr_code_reg <= instr_code;
    end

    // 2. 두뇌 (CPU)
    rv32i_cpu U_CPU (
        .clk(clk),
        .rst_n(rst_n),
        .ready(ready),
        .instr_code(instr_code_reg),
        .bus_rdata(bus_rdata),
        .transfer(transfer),
        .instr_addr(instr_addr),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_we(bus_we),
        .d_inst_type(d_inst_type),
        .fe2dec_en(fe2dec_en)
    );

    // 3. APB 번역기 (Requester)
    apb_requester U_APB_REQ (
        .clk(clk), .rst_n(rst_n),
        .transfer(transfer), .bus_we(bus_we),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .ready(ready), .bus_rdata(bus_rdata),
        
        .p_write(p_write), .p_enable(p_enable),
        .p_addr(p_addr), .p_wdata(p_wdata),
        .p_sel0(p_sel0), 
        // 미사용 슬롯은 비워둠 (모듈 내부에서 알아서 처리됨)
        .p_sel1(), .p_sel2(), .p_sel3(), .p_sel4(), .p_sel5(), .p_sel6(),
        
        // 미사용 입력 핀들은 시스템 먹통(Deadlock) 방지를 위해 강제로 막아둠
        .p_ready0(p_ready0), 
        .p_ready1(1'b1), .p_ready2(1'b1), .p_ready3(1'b1), .p_ready4(1'b1), .p_ready5(1'b1), .p_ready6(1'b1),
        .p_rdata0(p_rdata0), 
        .p_rdata1('0),   .p_rdata2('0),   .p_rdata3('0),   .p_rdata4('0),   .p_rdata5('0),   .p_rdata6('0)
    );

    // 4. 데이터 메모리 (RAM)
    apb_ram #(.DEPTH(128)) U_APB_RAM (
        .clk(clk), .rst_n(rst_n),
        .itype(d_inst_type),      // CPU에서 직접 날아온 사이드밴드 신호
        .pAddr(p_addr), .pWdata(p_wdata),
        .pWrite(p_write), .pEnable(p_enable), .pSel(p_sel0),
        .pRdata(p_rdata0), .pReady(p_ready0)
    );
endmodule