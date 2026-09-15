// RAM ( Slave + data RAM )
module apb_ram #(               
    parameter int DEPTH = 128
)(        
    input  logic        clk,
    input  logic        rst_n,
    input  logic [ 2:0] itype,  // funct3
    input  logic [31:0] pAddr,
    input  logic [31:0] pWdata,
    input  logic        pWrite,
    input  logic        pEnable,
    input  logic        pSel,
    output logic [31:0] pRdata,
    output logic        pReady
    // output logic        pSlverr

);
    

    logic [31:0] data_ram[0:DEPTH - 1];

    logic [ 6:0] ram_addr;              // for Expressing 128
    logic [ 1:0] byte_addr;
    
    assign ram_addr  = pAddr[8:2];      // Word (4B) -> 2bit slicing of 9 bit (512)
    assign byte_addr = pAddr[1:0];
    assign pReady    = pEnable & pSel;

    // Write phase
    always_ff @(posedge clk) begin
        if (pWrite & pReady) begin
            case(itype)
                3'b000: begin
                    // SB : Write 1 byte        // [시작점 +: 폭]
                    data_ram[ram_addr][byte_addr*8 +: 8] <= pWdata[7:0];
                end

                3'b001: begin
                    // SH : Write 2byte
                    // data_ram[ram_addr][byte_addr*16 +: 16] <= pWdata[15:0];
                    if (byte_addr[1] == 1'b0) begin
                        // Low 16bit Write
                        data_ram[ram_addr][15:0] <= pWdata[15:0];
                    end
                    else begin
                        // High 16bit Write
                        data_ram[ram_addr][31:16] <= pWdata[15:0];
                    end
                end

                3'b010: begin
                    // SW : Write 4byte
                    data_ram[ram_addr] <= pWdata;
                end
            endcase
        end
    end


    // Read phase
    always_comb begin
        pRdata = 32'dz;
        if (pSel) begin
            case(itype) 
                3'b000: begin
                    // LB: Load 1byte (sign extends)
                    pRdata = {
                        // sign extention
                        {24{data_ram[ram_addr][byte_addr*8 + 7]}}, 
                        data_ram[ram_addr][byte_addr*8 +: 8] 
                    };
                end

                3'b001: begin
                    // LH : Load 2byte (sign extention)
                    pRdata = {
                        {16{data_ram[ram_addr][byte_addr[1]*16 + 15]}},
                        data_ram[ram_addr][byte_addr[1]*16 +: 16]
                    };
                end

                3'b010: begin
                    // LW : Load 4byte
                    pRdata = data_ram[ram_addr];
                end

                3'b100: begin
                    // LBU: Load 1byte (zero extends, unsigned)
                    pRdata = { 24'b0, data_ram[ram_addr][byte_addr*8 +: 8] };
                    end
            endcase
        end
    end
endmodule

    
//module apb_slave (
//    input logic        pWrite,
//    input logic [31:0] pWdata,
//    input logic [ 2:0] itype
//);
//
//endmodule
    
