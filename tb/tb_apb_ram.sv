`timescale 1ns / 1ps

module tb_apb_ram;

    // 1. 신호 선언
    logic        clk;
    logic        rst_n;
    logic [ 2:0] itype;
    logic [31:0] pAddr;
    logic [31:0] pWdata;
    logic        pWrite;
    logic        pEnable;
    logic        pSel;
    logic [31:0] pRdata;
    logic        pReady;

    // 2. DUT (Device Under Test) 연결
    apb_ram #(
        .DEPTH(128)
    ) uut (
        .clk     (clk),
        .rst_n   (rst_n),
        .itype   (itype),
        .pAddr   (pAddr),
        .pWdata  (pWdata),
        .pWrite  (pWrite),
        .pEnable (pEnable),
        .pSel    (pSel),
        .pRdata  (pRdata),
        .pReady  (pReady)
        // pSlverr는 원본 코드에서 주석 처리되어 있으므로 연결하지 않음
    );

    // 3. 클럭 생성 (10ns 주기)
    always #5 clk = ~clk;

    // =========================================================================
    // APB Task 정의
    // =========================================================================
    task apb_write(input [31:0] addr, input [31:0] data, input [2:0] i_type);
        @(posedge clk);
        pSel    = 1'b1;
        pEnable = 1'b0;
        pWrite  = 1'b1;
        pAddr   = addr;
        pWdata  = data;
        itype   = i_type;
        
        @(posedge clk);
        pEnable = 1'b1;
        wait(pReady == 1'b1);
        
        @(posedge clk);
        pSel    = 1'b0;
        pEnable = 1'b0;
        pWrite  = 1'b0;
    endtask

    task apb_read(input [31:0] addr, input [2:0] i_type);
        @(posedge clk);
        pSel    = 1'b1;
        pEnable = 1'b0;
        pWrite  = 1'b0;
        pAddr   = addr;
        itype   = i_type;
        
        @(posedge clk);
        pEnable = 1'b1;
        wait(pReady == 1'b1);
        
        @(posedge clk);
        $display("[%0t] READ  | Addr: 0x%08X | Data: 0x%08X | Type: %3b", $time, addr, pRdata, i_type);
        pSel    = 1'b0;
        pEnable = 1'b0;
    endtask

    // =========================================================================
    // 시뮬레이션 시나리오
    // =========================================================================
    initial begin
        // 파형 덤프 (Makefile 설정인 wave.fsdb와 매칭)
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_apb_ram);

        // 초기화
        clk     = 0;
        rst_n   = 0;
        pSel    = 0;
        pEnable = 0;
        pWrite  = 0;
        pAddr   = 0;
        pWdata  = 0;
        itype   = 0;

        #15 rst_n = 1; // 리셋 해제
        #10;

        // 1. Word (4바이트) 테스트
        $display("--- Test 1: Word (SW / LW) ---");
        apb_write(32'h0000_0004, 32'hDEAD_BEEF, 3'b010); 
        apb_read (32'h0000_0004, 3'b010); // DEADBEEF 기대

        // 2. Byte (1바이트) 부호 확장 테스트
        $display("--- Test 2: Byte (SB / LB / LBU) ---");
        apb_write(32'h0000_0008, 32'h0000_0080, 3'b000); // 0x80 (음수) 기록
        apb_read (32'h0000_0008, 3'b000); // LB: FFFF_FF80 기대
        apb_read (32'h0000_0008, 3'b100); // LBU: 0000_0080 기대

        // 3. Half-word (2바이트) 부호 확장 테스트
        $display("--- Test 3: Half-word (SH / LH) ---");
        apb_write(32'h0000_000C, 32'h0000_8000, 3'b001); // 0x8000 (음수) 기록
        apb_read (32'h0000_000C, 3'b001); // LH: FFFF_8000 기대

        #50;
        $display("--- Simulation Finished ---");
        $finish;
    end

endmodule
