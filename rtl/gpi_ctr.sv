`timescale 1ns / 1ps

module gpi_ctr (
    input logic clk,
    input logic rst_n,
    input logic p_sel,
    input logic p_enable,
    input logic p_write,
    input logic [31:0] p_addr,
    input logic [31:0] p_wdata,
    output logic p_ready,
    output logic [31:0] p_rdata,

    input  logic [7:0] gpi_data,
    output logic [7:0] gpi_control
);

    logic [7:0] control_reg, control_next;
    logic [7:0] input_data, input_next;

    logic [5:0] gpi_addr;
    logic [1:0] byte_addr;

    assign gpi_addr = p_addr[7:2];
    assign byte_addr = p_addr[1:0];

    assign gpi_control = control_reg;
    assign p_rdata = {24'b0, input_data};

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } gpi_state_e;

    gpi_state_e c_state, n_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            c_state <= IDLE;
            control_reg <= 8'b0;
            input_data <= 8'b0;
        end else begin
            c_state <= n_state;
            control_reg <= control_next;
            input_data <= input_next;
        end
    end

    always_comb begin
        n_state = c_state;
        p_ready = 0;
        control_next = control_reg;
        input_next = input_data;

        case (c_state)
            IDLE: begin
                if (p_sel) n_state = SETUP;
            end
            SETUP: begin
                if (p_enable & p_sel) n_state = ACCESS;
                if (p_write & gpi_addr == 0) control_next = p_wdata[7:0];
            end
            ACCESS: begin
                p_ready = 1;
                n_state = IDLE;
                input_next = gpi_data;
            end
        endcase
    end
endmodule

module gpi_ip (
    input  logic [7:0] gpi_control,
    input  logic [7:0] switch_data,
    output logic [7:0] gpi_data
);

    assign gpi_data = gpi_control & switch_data;

endmodule

module apb_gpi_ex (
    input logic clk,
    input logic rst_n,
    input logic p_sel,
    input logic p_enable,
    input logic p_write,
    input logic [31:0] p_addr,
    input logic [31:0] p_wdata,
    output logic p_ready,
    output logic [31:0] p_rdata,

    input  logic [7:0] gpi_data,
    output logic [7:0] gpi_control
);
    localparam [7:0] GPI_CTR_ADDR = 8'h00;
    localparam [7:0] GPI_IDR_ADDR = 8'h04;

    logic [7:0] GPI_CTR;
    logic [7:0] GPI_IDR;

    assign p_ready = (p_enable & p_sel);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            GPI_CTR <= 8'h0;
        end else begin
            if (p_ready & p_write) begin
                if (p_addr[7:0] == GPI_CTR_ADDR)
                    GPI_CTR <= p_wdata;
            end
        end
    end

    assign p_rdata = (p_addr[7:0] == GPI_CTR_ADDR) ? {24'b0, GPI_CTR} :
                     (p_addr[7:0] == GPI_IDR_ADDR) ? {24'b0, GPI_IDR} :
                     32'hx;

    assign GPI_IDR = GPI_CTR & gpi_data;

endmodule
