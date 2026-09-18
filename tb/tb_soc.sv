`timescale 1ns / 1ps

module tb_soc;
    logic clk;
    logic rst_n;

    // 만든 SoC 칩
    soc_top uut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // (10ns 주기)
    always #5 clk = ~clk;

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_soc);
        $fsdbDumpMDA(0, tb_soc); // CPU 내부 레지스터 배열까지 싹 다 뽑아내기 위해 필수!

        // 전원 켜기
        clk = 0;
        rst_n = 0;
        
        #15 rst_n = 1; // 리셋 해제, CPU 깨어남!

        // CPU가 1부터 10까지 덧셈 루프를 10번 돌고 메모리에 쓸 때까지 넉넉하게 대기
        #5000;
        
        $display("--- Full System Simulation Finished ---");
        $finish;
    end
endmodule