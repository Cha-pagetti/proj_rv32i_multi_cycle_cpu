
// 128 word ram, word address
module data_memory (
    input  logic clk,
    input  logic d_we,
    input  logic [31:0] d_addr,
    input  logic [31:0] d_wdata,
    input  logic [2:0] d_inst_type,
    output logic [31:0] d_rdata
);

    logic [31:0] data_ram [0:127];

    logic [6:0] ram_addr;
    logic [1:0] byte_addr;

    assign ram_addr = d_addr[8:2];
    assign byte_addr = d_addr[1:0];

    always_ff @(posedge clk) begin
        if (d_we) begin
            case (d_inst_type)
                3'b000: begin
                    // SB: write 1 byte
                    data_ram[ram_addr][byte_addr*8 +: 8] <= d_wdata[7:0];
                end
                3'b001: begin
                    // SH: write 2 byte
                    data_ram[ram_addr][byte_addr[1]*16 +: 16] <= d_wdata[15:0];
                end
                3'b010: begin
                    // SW: write 4 byte
                    data_ram[ram_addr] <= d_wdata;
                end
                default: begin
                    data_ram[ram_addr] <= data_ram[ram_addr];
                end
            endcase
        end 
    end
    
    always_comb begin
        d_rdata = 32'dx;
        case (d_inst_type)
            3'b000: begin
                // LB: load 1 byte (sign extends)
                d_rdata = { 
                    // sign extend
                    {24{data_ram[ram_addr][byte_addr*8 + 7]}}, 
                    data_ram[ram_addr][byte_addr*8 +: 8]
                };
            end
            3'b001: begin
                // LH: load 2 byte (sign extends)
                d_rdata = {
                    {16{data_ram[ram_addr][byte_addr[1]*16 + 15]}},
                    data_ram[ram_addr][byte_addr[1]*16 +: 16]
                };
            end
            3'b010: begin
                // LW: load 4 byte
                d_rdata = data_ram[ram_addr];
            end
            3'b100: begin
                // LBU: load 1 byte (zero extends, unsigned)
                d_rdata = {
                    24'b0, data_ram[ram_addr][byte_addr*8 +: 8]
                };
            end
            3'b101: begin
                // LHU: load 2 byte (zero extends, unsigned)
                d_rdata <= {
                    16'b0, data_ram[ram_addr][byte_addr[1]*16 +: 16]
                };
            end
        endcase
    end
endmodule
