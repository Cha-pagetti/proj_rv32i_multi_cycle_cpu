//`timescale 1ns / 1ps

module tb_integration;

    // =========================================================================
    // 1. 시스템 신호 선언
    // =========================================================================
    logic clk;
    logic rst_n;

    // CPU(TB) <-> Requester 간의 인터페이스 신호
    logic        cpu_transfer;
    logic        cpu_bus_we;
    logic [31:0] cpu_bus_addr;
    logic [31:0] cpu_bus_wdata;
    logic [ 2:0] cpu_itype;       // CPU에서 RAM으로 직행하는 신호
    logic        cpu_ready;
    logic [31:0] cpu_bus_rdata;

    // Requester <-> RAM 간의 APB 버스 신호
    logic        p_write;
    logic        p_enable;
    logic [31:0] p_addr;
    logic [31:0] p_wdata;
    logic        p_sel0, p_sel1, p_sel2, p_sel3, p_sel4, p_sel5, p_sel6;
    
    logic        p_ready0;
    logic [31:0] p_rdata0;

    // =========================================================================
    // 2. 모듈 인스턴스화 (통합 연결)
    // =========================================================================
    
    // [Master] APB Requester
    apb_requester u_requester (
        .clk        (clk),
        .rst_n      (rst_n),
        .transfer   (cpu_transfer),
        .bus_we     (cpu_bus_we),
        .bus_addr   (cpu_bus_addr),
        .bus_wdata  (cpu_bus_wdata),
        .ready      (cpu_ready),
        .bus_rdata  (cpu_bus_rdata),
        
        // APB 출력
        .p_write    (p_write),
        .p_enable   (p_enable),
        .p_addr     (p_addr),
        .p_wdata    (p_wdata),
        .p_sel0     (p_sel0), 
        .p_sel1(p_sel1), .p_sel2(p_sel2), .p_sel3(p_sel3), 
        .p_sel4(p_sel4), .p_sel5(p_sel5), .p_sel6(p_sel6),
        
        // APB 입력 (사용하지 않는 Peripheral은 ready=1, rdata=0으로 묶음)
        .p_ready0   (p_ready0),
        .p_ready1   (1'b1), .p_ready2   (1'b1), .p_ready3   (1'b1),
        .p_ready4   (1'b1), .p_ready5   (1'b1), .p_ready6   (1'b1),
        .p_rdata0   (p_rdata0),
        .p_rdata1   ('0),   .p_rdata2   ('0),   .p_rdata3   ('0),
        .p_rdata4   ('0),   .p_rdata5   ('0),   .p_rdata6   ('0)
    );

    // [Slave 0] APB RAM
    apb_ram #(.DEPTH(128)) u_ram (
        .clk        (clk),
        .rst_n      (rst_n),
        .itype      (cpu_itype),  // CPU에서 직접 전달됨!
        .pAddr      (p_addr),
        .pWdata     (p_wdata),
        .pWrite     (p_write),
        .pEnable    (p_enable),
        .pSel       (p_sel0),     // Address Decoder가 0x1000_xxxx를 보고 켬
        .pRdata     (p_rdata0),
        .pReady     (p_ready0)
    );


    // =========================================================================
    // 3. 클럭 생성 및 CPU 행동 모사(Task) - Race Condition 수정 완료!
    // =========================================================================
    always #5 clk = ~clk;

    // CPU가 메모리에 데이터를 쓰는 행동을 흉내 내는 Task
    task cpu_write(input [31:0] addr, input [31:0] data, input [2:0] itype);
        @(posedge clk);
        cpu_transfer  <= 1'b1;  // '=' 대신 '<=' 사용!
        cpu_bus_we    <= 1'b1;
        cpu_bus_addr  <= addr;
        cpu_bus_wdata <= data;
        cpu_itype     <= itype;

        // Requester가 APB 통신을 다 끝내고 ready를 줄 때까지 기다림
        wait(cpu_ready == 1'b1);
        @(posedge clk);

        // 통신 완료 후 신호 내림
        cpu_transfer  <= 1'b0;
        cpu_bus_we    <= 1'b0;
    endtask

    // CPU가 메모리에서 데이터를 읽는 행동을 흉내 내는 Task
    task cpu_read(input [31:0] addr, input [2:0] itype);
        @(posedge clk);
        cpu_transfer  <= 1'b1;
        cpu_bus_we    <= 1'b0;
        cpu_bus_addr  <= addr;
        cpu_itype     <= itype;

        wait(cpu_ready == 1'b1);
        @(posedge clk);

        $display("[%0t] CPU READ | Addr: 0x%08X | Data: 0x%08X", $time, addr, cpu_bus_rdata);

        cpu_transfer  <= 1'b0;
    endtask

//    // =========================================================================
//    // 3. 클럭 생성 및 CPU 행동 모사(Task)
//    // =========================================================================
//    always #5 clk = ~clk;
//
//    // CPU가 메모리에 데이터를 쓰는 행동을 흉내 내는 Task
//    task cpu_write(input [31:0] addr, input [31:0] data, input [2:0] itype);
//        @(posedge clk);
//        cpu_transfer  = 1'b1;
//        cpu_bus_we    = 1'b1;
//        cpu_bus_addr  = addr;
//        cpu_bus_wdata = data;
//        cpu_itype     = itype;
//        
//        // Requester가 APB 통신을 다 끝내고 ready를 줄 때까지 기다림
//        do begin
//            @(posedge clk);
//        end while (cpu_ready == 1'b0);
//        
//        // 통신 완료 후 신호 내림
//        cpu_transfer  = 1'b0;
//        cpu_bus_we    = 1'b0;
//    endtask
//
//    // CPU가 메모리에서 데이터를 읽는 행동을 흉내 내는 Task
//    task cpu_read(input [31:0] addr, input [2:0] itype);
//        @(posedge clk);
//        cpu_transfer  = 1'b1;
//        cpu_bus_we    = 1'b0;
//        cpu_bus_addr  = addr;
//        cpu_itype     = itype;
//        
//        do begin
//            @(posedge clk);
//        end while (cpu_ready == 1'b0);
//        
//        $display("[%0t] CPU READ | Addr: 0x%08X | Data: 0x%08X", $time, addr, cpu_bus_rdata);
//        
//        cpu_transfer  = 1'b0;
//    endtask

    // =========================================================================
    // 4. 메인 시나리오 (C 코드 검증)
    // =========================================================================
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_integration);

        // 초기화
        clk           = 0;
        rst_n         = 0;
        cpu_transfer  = 0;
        cpu_bus_we    = 0;
        cpu_bus_addr  = 0;
        cpu_bus_wdata = 0;
        cpu_itype     = 0;

        #15 rst_n = 1; 
        #10;

        $display("---------------------------------------------------");
        $display(" Start C-Code Assembly Integration Test");
        $display("---------------------------------------------------");

        // [목표 시나리오 실행] *(unsigned int*) 0x10000000 = 0x12345678;
        // 1. SW(3'b010) 명령어로 0x1000_0000 주소에 0x1234_5678 쓰기
        cpu_write(32'h1000_0000, 32'h1234_5678, 3'b010); 
        
        // 2. 잘 써졌는지 LW(3'b010) 명령어로 읽어보기
        cpu_read(32'h1000_0000, 3'b010);

        #50;
        $display("---------------------------------------------------");
        $display(" Test Finished");
        $finish;
    end

endmodule
