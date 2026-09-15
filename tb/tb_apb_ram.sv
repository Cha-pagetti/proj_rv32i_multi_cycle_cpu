`timescale 1ns / 1ps
//==============================================================================
// tb_apb_ram : APB bus verification environment for the RAM completer
//
//   make apb        compile + run + self check
//   make apb_wave   same, then open Verdi on wave.fsdb
//
// The testbench never drives the APB bus itself. It lets the CPU execute the
// store/load program in rtl/rom_code_ram_apb.mem and passively verifies the
// resulting APB traffic with three independent components:
//
//   1. PROTOCOL CHECKER - SVA properties for the IDLE/SETUP/ACCESS handshake
//   2. MONITOR          - prints every completed transfer as a readable table
//   3. SCOREBOARD       - shadow copy of the RAM, compares every load
//==============================================================================
module tb_apb_ram ();

    localparam int TIMEOUT_NS = 20_000;
    localparam int EXP_WRITES = 3;  // sw x1,12(x2) / sw x8,8(x2) / sw x14,0(x15)
    localparam int EXP_READS  = 2;  // lw x1,12(x2) / lw x8,8(x2)

    logic clk, rst;
    logic [11:0] sw;
    logic [11:0] led;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------
    rv32i_top dut (
        .clk(clk),
        .rst(rst),
        .sw (sw),
        .led(led)
    );

    //--------------------------------------------------------------------------
    // APB signals of the RAM completer (completer 0)
    //--------------------------------------------------------------------------
    wire        p_write     = dut.p_write;
    wire        p_enable    = dut.p_enable;
    wire [31:0] p_addr      = dut.p_addr;
    wire [31:0] p_wdata     = dut.p_wdata;
    wire        p_sel0      = dut.p_sel0;
    wire        p_ready0    = dut.p_ready0;
    wire [31:0] p_rdata0    = dut.p_rdata0;
    wire [ 2:0] d_inst_type = dut.d_inst_type;

    // one completed APB transfer = ACCESS phase sampled with PREADY high
    wire        beat        = p_sel0 & p_enable & p_ready0;

    // how many completers are selected right now (must never exceed 1)
    wire [ 2:0] nsel        = dut.p_sel0 + dut.p_sel1 + dut.p_sel2 + dut.p_sel3
                            + dut.p_sel4 + dut.p_sel5 + dut.p_sel6;

    //--------------------------------------------------------------------------
    // clock / reset
    //--------------------------------------------------------------------------
    always #5 clk = ~clk;   // 100 MHz

    initial begin
        clk = 0;
        rst = 1;
        sw  = 12'h05a;
        #12;
        rst = 0;
    end

    initial begin
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("wave.fsdb");
            $fsdbDumpvars(0, tb_apb_ram);
            $fsdbDumpMDA(0, dut.U_APB_RAM_COM);  // unpacked data_ram array
        end
    end

    //==========================================================================
    // 1. PROTOCOL CHECKER
    //==========================================================================
    default disable iff (rst);

    // A transfer starts in SETUP: PSEL rises while PENABLE is still low.
    A_SETUP_NO_ENABLE : assert property (@(posedge clk)
        $rose(p_sel0) |-> !p_enable)
        else $error("[APB] PENABLE asserted during SETUP phase");

    // SETUP lasts exactly one cycle, so PENABLE rises on the very next edge.
    A_ENABLE_AFTER_SETUP : assert property (@(posedge clk)
        $rose(p_sel0) |=> p_enable)
        else $error("[APB] PENABLE did not follow PSEL after one cycle");

    // PADDR / PWRITE / PWDATA must not move while a transfer is in flight.
    A_ADDR_STABLE : assert property (@(posedge clk)
        (p_sel0 && !beat) |=> $stable(p_addr))
        else $error("[APB] PADDR changed mid transfer");

    A_WRITE_STABLE : assert property (@(posedge clk)
        (p_sel0 && !beat) |=> $stable(p_write))
        else $error("[APB] PWRITE changed mid transfer");

    A_WDATA_STABLE : assert property (@(posedge clk)
        (p_sel0 && p_write && !beat) |=> $stable(p_wdata))
        else $error("[APB] PWDATA changed mid transfer");

    // PENABLE drops for at least one cycle once PREADY completed the transfer.
    A_ENABLE_DROPS : assert property (@(posedge clk)
        beat |=> !p_enable)
        else $error("[APB] PENABLE stayed high after PREADY");

    // PREADY is only meaningful while the completer is selected and enabled.
    A_READY_QUALIFIED : assert property (@(posedge clk)
        p_ready0 |-> (p_sel0 && p_enable))
        else $error("[APB] PREADY asserted outside the ACCESS phase");

    // Exactly one completer may be selected at any time.
    A_ONE_HOT_SEL : assert property (@(posedge clk)
        nsel <= 1)
        else $error("[APB] %0d completers selected at the same time", nsel);

    //==========================================================================
    // 2. SCOREBOARD - shadow RAM, byte accurate
    //==========================================================================
    logic [31:0] ref_mem [0:127];
    int          n_write, n_read, n_error;

    // sampling registers for the monitor (module scope: always blocks are static)
    logic [ 6:0] mon_word;
    logic [ 1:0] mon_byte;
    logic [31:0] mon_exp;

    function automatic string type_name(bit is_write, logic [2:0] t);
        case ({is_write, t})
            4'b1_000: return "SB ";
            4'b1_001: return "SH ";
            4'b1_010: return "SW ";
            4'b0_000: return "LB ";
            4'b0_001: return "LH ";
            4'b0_010: return "LW ";
            4'b0_100: return "LBU";
            4'b0_101: return "LHU";
            default : return "?? ";
        endcase
    endfunction

    // expected read data, mirroring the sign/zero extension in apb_bram.sv
    function automatic logic [31:0] ref_rdata(logic [6:0] w, logic [1:0] b,
                                              logic [2:0] t);
        case (t)
            3'b000 : return {{24{ref_mem[w][b*8 + 7]}},      ref_mem[w][b*8 +: 8]};
            3'b001 : return {{16{ref_mem[w][b[1]*16 + 15]}}, ref_mem[w][b[1]*16 +: 16]};
            3'b010 : return ref_mem[w];
            3'b100 : return {24'b0, ref_mem[w][b*8 +: 8]};
            3'b101 : return {16'b0, ref_mem[w][b[1]*16 +: 16]};
            default: return 32'hx;
        endcase
    endfunction

    //==========================================================================
    // 3. MONITOR - log and check every completed transfer
    //==========================================================================
    always @(posedge clk) begin
        if (!rst && beat) begin
            mon_word = p_addr[8:2];
            mon_byte = p_addr[1:0];

            if (p_write) begin
                n_write = n_write + 1;
                $display("%7t | %0d | %s | WRITE | 0x%08h (word %3d, byte %0d) | 0x%08h",
                         $time, n_write + n_read, type_name(1, d_inst_type),
                         p_addr, mon_word, mon_byte, p_wdata);
                // apply the same byte semantics the DUT applies
                case (d_inst_type)
                    3'b000 : ref_mem[mon_word][mon_byte*8      +:  8] = p_wdata[7:0];
                    3'b001 : ref_mem[mon_word][mon_byte[1]*16  +: 16] = p_wdata[15:0];
                    3'b010 : ref_mem[mon_word]                        = p_wdata;
                    default: ;
                endcase
            end
            else begin
                mon_exp = ref_rdata(mon_word, mon_byte, d_inst_type);
                n_read  = n_read + 1;
                $display("%7t | %0d | %s | READ  | 0x%08h (word %3d, byte %0d) | 0x%08h  exp 0x%08h  %s",
                         $time, n_write + n_read, type_name(0, d_inst_type),
                         p_addr, mon_word, mon_byte, p_rdata0, mon_exp,
                         (p_rdata0 === mon_exp) ? "PASS" : "*** FAIL ***");
                if (p_rdata0 !== mon_exp) begin
                    n_error = n_error + 1;
                    $error("[SCOREBOARD] load mismatch at 0x%08h: got 0x%08h, expected 0x%08h",
                           p_addr, p_rdata0, mon_exp);
                end
            end
        end
    end

    //==========================================================================
    // end of test
    //==========================================================================
    task automatic dump_ram();
        $display("");
        $display("---- apb_bram contents (non-X words) --------------------------");
        for (int i = 0; i < 128; i++) begin
            if (^dut.U_APB_RAM_COM.data_ram[i] !== 1'bx)
                $display("  data_ram[%3d]  paddr 0x%08h = 0x%08h",
                         i, i * 4, dut.U_APB_RAM_COM.data_ram[i]);
        end
        $display("---------------------------------------------------------------");
    endtask

    initial begin
        $display("");
        $display("================= APB RAM verification ========================");
        $display("   time | # | typ | dir   | address                 | data");
        $display("---------------------------------------------------------------");

        wait (rst == 0);
        // run until the program has issued every RAM access we expect
        wait (n_write >= EXP_WRITES && n_read >= EXP_READS);
        repeat (20) @(posedge clk);

        dump_ram();
        $display("");
        $display("writes = %0d   reads = %0d   errors = %0d", n_write, n_read, n_error);
        if (n_error == 0) $display(">>>>>>>>>>>>>>>>>  TEST PASSED  <<<<<<<<<<<<<<<<<");
        else              $display(">>>>>>>>>>>>>>>>>  TEST FAILED  <<<<<<<<<<<<<<<<<");
        $display("===============================================================");
        $finish;
    end

    // safety net so the run always terminates
    initial begin
        #TIMEOUT_NS;
        dump_ram();
        $display("");
        $display("*** TIMEOUT after %0d ns - writes %0d/%0d, reads %0d/%0d",
                 TIMEOUT_NS, n_write, EXP_WRITES, n_read, EXP_READS);
        $display(">>>>>>>>>>>>>>>>>  TEST FAILED  <<<<<<<<<<<<<<<<<");
        $display("===============================================================");
        $finish;
    end

endmodule
