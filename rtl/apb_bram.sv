module apb_bram (
    input  logic clk,
    input  logic p_sel,
    input  logic p_enable,
    input  logic p_write,
    input  logic [31:0] p_addr,
    input  logic [31:0] p_wdata,
    input  logic [2:0] d_inst_type,
    output logic [31:0] p_rdata,
    output logic p_ready
);

    logic [31:0] data_ram [0:127];

    logic [29:0] ram_addr;
    logic [1:0] byte_addr;

    assign ram_addr = p_addr[31:2];
    assign byte_addr = p_addr[1:0];
    assign p_ready = p_enable & p_sel;

    always_ff @(posedge clk) begin
        if (p_write & p_ready) begin
            case (d_inst_type)
                3'b000: begin
                    // SB: write 1 byte
                    data_ram[ram_addr][byte_addr*8 +: 8] <= p_wdata[7:0];
                end
                3'b001: begin
                    // SH: write 2 byte
                    data_ram[ram_addr][byte_addr[1]*16 +: 16] <= p_wdata[15:0];
                end
                3'b010: begin
                    // SW: write 4 byte
                    data_ram[ram_addr] <= p_wdata;
                end
                default: begin
                    data_ram[ram_addr] <= data_ram[ram_addr];
                end
            endcase
        end 
    end
    
    always_comb begin
        p_rdata = 32'dz;
        if (p_ready) begin
            case (d_inst_type)
                3'b000: begin
                    // LB: load 1 byte (sign extends)
                    p_rdata = { 
                        // sign extend
                        {24{data_ram[ram_addr][byte_addr*8 + 7]}}, 
                        data_ram[ram_addr][byte_addr*8 +: 8]
                    };
                end
                3'b001: begin
                    // LH: load 2 byte (sign extends)
                    p_rdata = {
                        {16{data_ram[ram_addr][byte_addr[1]*16 + 15]}},
                        data_ram[ram_addr][byte_addr[1]*16 +: 16]
                    };
                end
                3'b010: begin
                    // LW: load 4 byte
                    p_rdata = data_ram[ram_addr];
                end
                3'b100: begin
                    // LBU: load 1 byte (zero extends, unsigned)
                    p_rdata = {
                        24'b0, data_ram[ram_addr][byte_addr*8 +: 8]
                    };
                end
                3'b101: begin
                    // LHU: load 2 byte (zero extends, unsigned)
                    p_rdata <= {
                        16'b0, data_ram[ram_addr][byte_addr[1]*16 +: 16]
                    };
                end
            endcase
        end
    end
endmodule
