
module tb_rv32i ();
    
    logic clk, rst_n;
    
    always #5 clk = ~clk;

    rv32i_top dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0);
    end

    initial begin
        clk = 0;
        rst_n = 0;
        #10;
        
        rst_n = 1;
        #500_000;
        
        $finish;
    end
endmodule
