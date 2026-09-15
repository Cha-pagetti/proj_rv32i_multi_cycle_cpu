
module tb_rv32i ();
    
    logic clk, rst;
    logic [11:0] sw, led;
    
    always #5 clk = ~clk;

    rv32i_top dut (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .led(led)
    );

    // initial begin
    //     $fsdbDumpfile("wave.fsdb");
    //     $fsdbDumpvars(0);
    // end

    initial begin
        clk = 0;
        rst = 1;
        sw = 12'h5a;
        led = 12'b0;
        #10;
        
        rst = 0;
        #500_000;
        
        $finish;
    end
endmodule
