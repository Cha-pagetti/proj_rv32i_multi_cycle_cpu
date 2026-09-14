`timescale 1ns / 1ps

module gpo_ctr(
    input logic clk,
    input logic rst_n,
    input logic p_sel,
    input logic p_enable,
    input logic p_write,
    input logic [31:0] p_addr,
    input logic [31:0] p_wdata,
    output logic [7:0] gpo_data,
    output logic p_ready
);
    localparam [7:0] GPO_CTR_ADDR = 0;
    localparam [7:0] GPO_ODR_ADDR = 1;

    logic [7:0] control_reg, control_next;
    logic [7:0] output_data, output_next;

    logic [5:0] gpo_addr;
    logic [1:0] byte_addr;

    assign gpo_addr = p_addr[7:2];
    assign byte_addr = p_addr[1:0];

    assign p_ready = p_sel & p_enable;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            control_reg <= 8'b0;
            output_data <= 8'b0;
        end else if (p_sel & p_enable & p_write) begin
            case (gpo_addr)
                GPO_CTR_ADDR: control_reg <= p_wdata[7:0];
                GPO_ODR_ADDR: output_data <= p_wdata[7:0];
            endcase
        end
    end

endmodule
