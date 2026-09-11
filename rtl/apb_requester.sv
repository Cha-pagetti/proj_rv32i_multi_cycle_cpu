

module apb_requester(
    input  logic clk,
    input  logic rst_n,
    input  logic transfer,
    input  logic bus_we,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic ready,
    output logic [31:0] bus_rdata,

    // apb interface
    // 0: RAM
    // 1: GPI
    // 2: GPO
    // 3: GPIO
    // 4: FND
    // 5: UART
    output logic p_write,
    output logic p_enable,
    output logic [31:0] p_addr,
    output logic [31:0] p_wdata,
    output logic p_sel0,
    output logic p_sel1,
    output logic p_sel2,
    output logic p_sel3,
    output logic p_sel4,
    output logic p_sel5,
    output logic p_sel6,
    input  logic p_ready0,
    input  logic p_ready1,
    input  logic p_ready2,
    input  logic p_ready3,
    input  logic p_ready4,
    input  logic p_ready5,
    input  logic p_ready6,
    input  logic [31:0] p_rdata0,
    input  logic [31:0] p_rdata1,
    input  logic [31:0] p_rdata2,
    input  logic [31:0] p_rdata3,
    input  logic [31:0] p_rdata4,
    input  logic [31:0] p_rdata5,
    input  logic [31:0] p_rdata6
);

    typedef enum logic [1:0] {
        IDLE, SETUP, ACCESS
    } apb_state_e;

    apb_state_e c_state, n_state;
    logic [3:0] selected_p;

    address_decoder U_P_ADDR_DEC (
        .addr(bus_addr),
        .psel(selected_p)
    );

    apb_mux U_MUX_P_READY (
        .mux_sel(selected_p),
        .in0(p_ready0),
        .in1(p_ready1),
        .in2(p_ready2),
        .in3(p_ready3),
        .in4(p_ready4),
        .in5(p_ready5),
        .in6(p_ready6),
        .mux_out(ready)
    );

    apb_mux U_MUX_P_RDATA (
        .mux_sel(selected_p),
        .in0(p_rdata0),
        .in1(p_rdata1),
        .in2(p_rdata2),
        .in3(p_rdata3),
        .in4(p_rdata4),
        .in5(p_rdata5),
        .in6(p_rdata6),
        .mux_out(bus_rdata)
    );

    assign p_addr = {4'b0000, bus_addr[27:0]};
    assign p_wdata = bus_wdata;
    assign p_write = bus_we;

    always_ff @(posedge clk) begin
        if (!rst_n) c_state <= IDLE;
        else c_state <= n_state;
    end

    always_comb begin
        n_state = c_state;
        p_sel0 = 0;
        p_sel1 = 0;
        p_sel2 = 0;
        p_sel3 = 0;
        p_sel4 = 0;
        p_sel5 = 0;
        p_sel6 = 0;
        p_enable = 0;

        case (c_state)
            IDLE: begin
                if (transfer) n_state = SETUP;
            end
            SETUP: begin
                case (selected_p)
                    4'h0: p_sel0 = 1'b1;
                    4'h1: p_sel1 = 1'b1;
                    4'h2: p_sel2 = 1'b1;
                    4'h3: p_sel3 = 1'b1;
                    4'h4: p_sel4 = 1'b1;
                    4'h5: p_sel5 = 1'b1;
                    4'h6: p_sel6 = 1'b1;
                endcase
                n_state = ACCESS;
            end
            ACCESS: begin
                case (selected_p)
                    4'h0: p_sel0 = 1'b1;
                    4'h1: p_sel1 = 1'b1;
                    4'h2: p_sel2 = 1'b1;
                    4'h3: p_sel3 = 1'b1;
                    4'h4: p_sel4 = 1'b1;
                    4'h5: p_sel5 = 1'b1;
                    4'h6: p_sel6 = 1'b1;
                endcase
                p_enable = 1'b1;
                if (ready) n_state = IDLE;
            end
        endcase
    end
endmodule



module apb_mux (
    input  logic [3:0]  mux_sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    input  logic [31:0] in3,
    input  logic [31:0] in4,
    input  logic [31:0] in5,
    input  logic [31:0] in6,
    output logic [31:0] mux_out
);

    always_comb begin
        mux_out = in0;
        case (mux_sel)
            4'h0: mux_out = in0;
            4'h1: mux_out = in1;
            4'h2: mux_out = in2;
            4'h3: mux_out = in3;
            4'h4: mux_out = in4;
            4'h5: mux_out = in5;
            4'h6: mux_out = in6;
        endcase
    end

endmodule

module address_decoder(
    //input  logic enable,
    input  logic [31:0] addr,
    output logic [3:0] psel
);

    //always_comb begin
    //    psel = 0;
    //    case (addr[31:28])
    //        4'h1: psel = 0;
    //        4'h2: psel = adder[11:8] + 1'b1;
    //    endcase
    //end

    always_comb begin
        psel = 0;
        case (addr[31:28])
            4'h1: psel = 0;
            4'h2: begin
                case (addr[11:8])
                    4'h0: psel = 1;
                    4'h1: psel = 2;
                    4'h2: psel = 3;
                    4'h3: psel = 4;
                    4'h4: psel = 5;
                    4'h5: psel = 6;
                endcase
            end
        endcase
    end

endmodule
