`include "uvm_macros.svh"
import uvm_pkg::*;

// ================================================================
// Interface
// ================================================================
interface rv32i_if(input logic clk);
    logic        rst_n;
    logic [31:0] instr;

    // DUT observation signals
    logic        rf_we;
    logic [31:0] x1_data;
    logic [31:0] x2_data;
    logic [31:0] rd3_data;

    // Driver-to-monitor sideband information (testbench only)
    logic        test_active;
    int          op;
    int          edge_id;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [11:0] imm;
endinterface

// ================================================================
// Sequence item
// ================================================================
class rv32i_seq_item extends uvm_sequence_item;
    rand int unsigned op;
    rand logic [31:0] rs1_value;
    rand logic [31:0] rs2_value;
    rand logic [11:0] imm;

    int          edge_id = -1;
    logic [31:0] instr;
    logic [31:0] actual;
    bit          writeback_seen;

    constraint c_op { op inside {[0:18]}; }

    `uvm_object_utils_begin(rv32i_seq_item)
        `uvm_field_int(op,             UVM_DEFAULT)
        `uvm_field_int(rs1_value,      UVM_HEX)
        `uvm_field_int(rs2_value,      UVM_HEX)
        `uvm_field_int(imm,            UVM_HEX)
        `uvm_field_int(edge_id,        UVM_DEFAULT)
        `uvm_field_int(instr,          UVM_HEX)
        `uvm_field_int(actual,         UVM_HEX)
        `uvm_field_int(writeback_seen, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="rv32i_seq_item");
        super.new(name);
    endfunction
endclass

// ================================================================
// Sequence: 80,000 tests, evenly distributed across 19 operations
// The first six occurrences of every operation are directed edges.
// The remaining occurrences retain randomized operands.
// ================================================================
class rv32i_sequence extends uvm_sequence #(rv32i_seq_item);
    `uvm_object_utils(rv32i_sequence)

    localparam int OPS   = 19;
    localparam int TESTS = 80000;

    function new(string name="rv32i_sequence");
        super.new(name);
    endfunction

    function void apply_edge(rv32i_seq_item item, int edge_idx);
        item.edge_id = edge_idx;

        if (item.op < 10) begin                 // R-type
            case (edge_idx)
                0: begin item.rs1_value=32'h00000000; item.rs2_value=32'h00000000; end
                1: begin item.rs1_value=32'h00000001; item.rs2_value=32'h00000001; end
                2: begin item.rs1_value=32'hffffffff; item.rs2_value=32'h00000001; end
                3: begin item.rs1_value=32'h80000000; item.rs2_value=32'hffffffff; end
                4: begin item.rs1_value=32'h7fffffff; item.rs2_value=32'h00000001; end
                5: begin // ordinary values, excluding the five special values
                    item.rs1_value=32'h13579bdf;
                    item.rs2_value=32'h2468ace0;
                end
            endcase
        end
        else if (item.op <= 15) begin           // ADDI through ANDI
            case (edge_idx)
                0: begin item.rs1_value=32'h00000000; item.imm=12'h000; end
                1: begin item.rs1_value=32'h00000001; item.imm=12'hfff; end // -1
                2: begin item.rs1_value=32'hffffffff; item.imm=12'h800; end // -2048
                3: begin item.rs1_value=32'h80000000; item.imm=12'h7ff; end // 2047
                4: begin item.rs1_value=32'h7fffffff; item.imm=12'h001; end
                5: begin item.rs1_value=32'h13579bdf; item.imm=12'h321; end
            endcase
        end
        else begin                              // SLLI, SRLI, SRAI
            case (edge_idx)
                0: begin item.rs1_value=32'h00000000; item.imm=12'd0;  end
                1: begin item.rs1_value=32'h00000001; item.imm=12'd1;  end
                2: begin item.rs1_value=32'hffffffff; item.imm=12'd15; end
                3: begin item.rs1_value=32'h80000000; item.imm=12'd16; end
                4: begin item.rs1_value=32'h7fffffff; item.imm=12'd31; end
                5: begin item.rs1_value=32'h13579bdf; item.imm=12'd9;  end
            endcase
        end
    endfunction

    virtual task body();
        rv32i_seq_item item;
        int occurrence[OPS];
        int op_sel;

        for (int n=0; n<TESTS; n++) begin
            op_sel = n % OPS;
            item = rv32i_seq_item::type_id::create($sformatf("item_%0d",n));
            start_item(item);
            if (!item.randomize() with { op == op_sel; })
                `uvm_fatal("SEQ", "randomize failed")

            if (occurrence[op_sel] < 6)
                apply_edge(item, occurrence[op_sel]);
            else
                item.edge_id = -1;

            occurrence[op_sel]++;
            finish_item(item);
        end
    endtask
endclass

// ================================================================
// Driver
// ================================================================
class rv32i_driver extends uvm_driver #(rv32i_seq_item);
    `uvm_component_utils(rv32i_driver)
    virtual rv32i_if vif;

    function new(string name="rv32i_driver", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rv32i_if)::get(this,"","vif",vif))
            `uvm_fatal("DRV", "cannot access virtual interface")
    endfunction

    function automatic logic [31:0] make_instr(
        int op, logic [11:0] imm
    );
        logic [2:0]  funct3;
        logic [6:0]  funct7;
        logic [11:0] enc_imm;

        funct3=0; funct7=0; enc_imm=imm;
        if (op < 10) begin
            case (op)
                0: funct3=3'b000;                                      // ADD
                1: begin funct3=3'b000; funct7=7'b0100000; end         // SUB
                2: funct3=3'b001;                                      // SLL
                3: funct3=3'b010;                                      // SLT
                4: funct3=3'b011;                                      // SLTU
                5: funct3=3'b100;                                      // XOR
                6: funct3=3'b101;                                      // SRL
                7: begin funct3=3'b101; funct7=7'b0100000; end         // SRA
                8: funct3=3'b110;                                      // OR
                9: funct3=3'b111;                                      // AND
            endcase
            return {funct7,5'd2,5'd1,funct3,5'd3,7'b0110011};
        end

        case (op)
            10: funct3=3'b000; // ADDI
            11: funct3=3'b010; // SLTI
            12: funct3=3'b011; // SLTIU
            13: funct3=3'b100; // XORI
            14: funct3=3'b110; // ORI
            15: funct3=3'b111; // ANDI
            16: funct3=3'b001; // SLLI
            17,18: funct3=3'b101; // SRLI/SRAI
        endcase
        if (op==16 || op==17) enc_imm={7'b0000000,imm[4:0]};
        if (op==18)           enc_imm={7'b0100000,imm[4:0]};
        return {enc_imm,5'd1,funct3,5'd3,7'b0010011};
    endfunction

    task automatic execute_writeback(
        logic [31:0] code, output bit seen
    );
        seen=0;
        @(negedge vif.clk);
        vif.instr=code;
        for (int cycle=0; cycle<8; cycle++) begin
            @(negedge vif.clk);
            if (vif.rf_we) begin
                seen=1;
                break;
            end
        end
    endtask

    task automatic load_constant(
        logic [4:0] rd, logic [31:0] value, output bit ok
    );
        logic [31:0] upper;
        logic [31:0] code;
        bit seen;

        upper=(value+32'h00000800)>>12;
        code={upper[19:0],rd,7'b0110111};       // LUI
        execute_writeback(code,seen);
        if (!seen) begin ok=0; return; end
        @(posedge vif.clk);
        #1;

        code={value[11:0],rd,3'b000,rd,7'b0010011}; // ADDI
        execute_writeback(code,seen);
        if (!seen) begin ok=0; return; end
        @(posedge vif.clk);
        #1;
        case (rd)
            5'd1: ok=(vif.x1_data===value);
            5'd2: ok=(vif.x2_data===value);
            default: ok=0;
        endcase
    endtask

    virtual task run_phase(uvm_phase phase);
        rv32i_seq_item item;
        bit ok1,ok2,seen;

        vif.test_active=0;
        vif.rst_n=0;
        vif.instr=32'h00000013;

        forever begin
            seq_item_port.get_next_item(item);

            @(negedge vif.clk);
            vif.rst_n=0;
            vif.instr=32'h00000013;
            repeat (2) @(posedge vif.clk);
            #1 vif.rst_n=1;

            load_constant(5'd1,item.rs1_value,ok1);
            load_constant(5'd2,item.rs2_value,ok2);

            item.instr=make_instr(item.op,item.imm);
            vif.op=item.op;
            vif.edge_id=item.edge_id;
            vif.rs1_value=item.rs1_value;
            vif.rs2_value=item.rs2_value;
            vif.imm=item.imm;
            vif.test_active=ok1 && ok2;

            execute_writeback(item.instr,seen);
            if (!seen)
                `uvm_error("DRV",$sformatf("op=%0d: no writeback",item.op))

            if (seen) begin
                @(posedge vif.clk);
                #2;
            end
            vif.test_active=0;
            seq_item_port.item_done();
        end
    endtask
endclass

// ================================================================
// Monitor: publishes only the target instruction write-back.
// Preload write-backs occur while test_active is zero.
// ================================================================
class rv32i_monitor extends uvm_monitor;
    `uvm_component_utils(rv32i_monitor)
    virtual rv32i_if vif;
    uvm_analysis_port #(rv32i_seq_item) send;

    function new(string name="rv32i_monitor", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rv32i_if)::get(this,"","vif",vif))
            `uvm_fatal("MON", "cannot access virtual interface")
        send=new("send",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        rv32i_seq_item item;
        forever begin
            @(posedge vif.clk);
            if (vif.test_active && vif.rf_we) begin
                #1;
                item=rv32i_seq_item::type_id::create("observed_item");
                item.op=vif.op;
                item.edge_id=vif.edge_id;
                item.rs1_value=vif.rs1_value;
                item.rs2_value=vif.rs2_value;
                item.imm=vif.imm;
                item.instr=vif.instr;
                item.actual=vif.rd3_data;
                item.writeback_seen=1;
                send.write(item);
            end
        end
    endtask
endclass

// ================================================================
// Agent
// ================================================================
class rv32i_agent extends uvm_agent;
    `uvm_component_utils(rv32i_agent)
    rv32i_driver drv;
    rv32i_monitor mon;
    uvm_sequencer #(rv32i_seq_item) sqr;

    function new(string name="rv32i_agent", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv=rv32i_driver::type_id::create("drv",this);
        mon=rv32i_monitor::type_id::create("mon",this);
        sqr=uvm_sequencer#(rv32i_seq_item)::type_id::create("sqr",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// ================================================================
// Scoreboard
// ================================================================
class rv32i_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(rv32i_scoreboard)
    localparam int OPS=19;
    localparam int EXPECTED_TOTAL=80000;

    uvm_analysis_imp #(rv32i_seq_item,rv32i_scoreboard) recv;
    int pass_count[OPS];
    int fail_count[OPS];
    bit edge_seen[OPS][6];

    function new(string name="rv32i_scoreboard", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv=new("recv",this);
    endfunction

    function automatic string op_name(int op);
        case (op)
            0:return "ADD";   1:return "SUB";  2:return "SLL";
            3:return "SLT";   4:return "SLTU"; 5:return "XOR";
            6:return "SRL";   7:return "SRA";  8:return "OR";
            9:return "AND";  10:return "ADDI"; 11:return "SLTI";
            12:return "SLTIU"; 13:return "XORI"; 14:return "ORI";
            15:return "ANDI"; 16:return "SLLI"; 17:return "SRLI";
            18:return "SRAI"; default:return "UNKNOWN";
        endcase
    endfunction

    function automatic logic [31:0] reference_result(rv32i_seq_item item);
        logic signed [31:0] simm;
        simm={{20{item.instr[31]}},item.instr[31:20]};
        case (item.op)
            0:return item.rs1_value+item.rs2_value;
            1:return item.rs1_value-item.rs2_value;
            2:return item.rs1_value<<item.rs2_value[4:0];
            3:return ($signed(item.rs1_value)<$signed(item.rs2_value));
            4:return (item.rs1_value<item.rs2_value);
            5:return item.rs1_value^item.rs2_value;
            6:return item.rs1_value>>item.rs2_value[4:0];
            7:return $signed(item.rs1_value)>>>item.rs2_value[4:0];
            8:return item.rs1_value|item.rs2_value;
            9:return item.rs1_value&item.rs2_value;
            10:return item.rs1_value+simm;
            11:return ($signed(item.rs1_value)<simm);
            12:return (item.rs1_value<$unsigned(simm));
            13:return item.rs1_value^simm;
            14:return item.rs1_value|simm;
            15:return item.rs1_value&simm;
            16:return item.rs1_value<<item.instr[24:20];
            17:return item.rs1_value>>item.instr[24:20];
            18:return $signed(item.rs1_value)>>>item.instr[24:20];
            default:return 32'hxxxxxxxx;
        endcase
    endfunction

    virtual function void write(rv32i_seq_item item);
        logic [31:0] expected;
        expected=reference_result(item);

        if (item.writeback_seen && item.actual===expected) begin
            pass_count[item.op]++;
            if (item.edge_id>=0 && item.edge_id<6)
                edge_seen[item.op][item.edge_id]=1;
        end
        else begin
            fail_count[item.op]++;
            `uvm_error("SCB",$sformatf(
                "%s rs1=%08h rs2=%08h imm=%03h expected=%08h actual=%08h",
                op_name(item.op),item.rs1_value,item.rs2_value,item.imm,
                expected,item.actual))
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        int total_pass=0;
        int total_fail=0;
        int total_edges=0;

        `uvm_info("SCB","\n========== R/I RANDOM + EDGE TEST RESULT ==========",UVM_NONE)
        `uvm_info("SCB","INSTR  CHECKED  PASS  FAIL  PASS_RATE  EDGE  STATUS",UVM_NONE)
        for (int op=0; op<OPS; op++) begin
            int checked;
            int edges=0;
            string status;
            checked=pass_count[op]+fail_count[op];
            for (int e=0;e<6;e++) if (edge_seen[op][e]) edges++;
            status=(fail_count[op]==0 && edges==6) ? "PASS" : "FAIL";
            `uvm_info("SCB",$sformatf(
                "%-6s %7d %5d %5d %9.1f%%   %d/6  %s",
                op_name(op),checked,pass_count[op],fail_count[op],
                checked ? 100.0*pass_count[op]/checked : 0.0,
                edges,status),UVM_NONE)
            total_pass+=pass_count[op];
            total_fail+=fail_count[op];
            total_edges+=edges;
        end
        `uvm_info("SCB",$sformatf(
            "TOTAL  %7d %5d %5d %9.1f%% %3d/114",
            total_pass+total_fail,total_pass,total_fail,
            (total_pass+total_fail) ? 100.0*total_pass/(total_pass+total_fail) : 0.0,
            total_edges),UVM_NONE)

        if (total_pass!=EXPECTED_TOTAL || total_fail!=0 || total_edges!=114)
            `uvm_error("SCB","random result or planned edge scenario failed")
        else
            `uvm_info("SCB","RESULT PASS: all checks and 114 edge scenarios passed",UVM_NONE)
    endfunction
endclass

// ================================================================
// Functional coverage
// ================================================================
class rv32i_coverage extends uvm_subscriber #(rv32i_seq_item);
    `uvm_component_utils(rv32i_coverage)
    rv32i_seq_item item;

    covergroup rv32i_cg;
        option.per_instance=1;

        cp_op: coverpoint item.op {
            bins r_type[]={[0:9]};
            bins i_type[]={[10:18]};
        }
        cp_rs1: coverpoint item.rs1_value {
            bins zero={32'h00000000};
            bins one={32'h00000001};
            bins minus_one={32'hffffffff};
            bins signed_min={32'h80000000};
            bins signed_max={32'h7fffffff};
            bins others=default;
        }
        cp_rs2: coverpoint item.rs2_value iff(item.op<10) {
            bins zero={32'h00000000};
            bins one={32'h00000001};
            bins minus_one={32'hffffffff};
            bins signed_min={32'h80000000};
            bins signed_max={32'h7fffffff};
            bins others=default;
        }
        cp_imm: coverpoint item.instr[31:20] iff(item.op>=10 && item.op<=15) {
            bins zero={12'h000};
            bins minus_one={12'hfff};
            bins signed_min={12'h800};
            bins signed_max={12'h7ff};
            bins others=default;
        }
        cp_shamt: coverpoint item.instr[24:20] iff(item.op>=16) {
            bins zero={0}; bins one={1}; bins middle_low={15};
            bins middle_high={16}; bins maximum={31}; bins others=default;
        }
        cp_edge: coverpoint item.edge_id iff(item.edge_id>=0) {
            bins planned[]={0,1,2,3,4,5};
        }
        cx_op_edge: cross cp_op,cp_edge;
    endgroup

    function new(string name="rv32i_coverage",uvm_component parent=null);
        super.new(name,parent);
        rv32i_cg=new();
    endfunction

    virtual function void write(rv32i_seq_item t);
        item=t;
        rv32i_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("COV",$sformatf(
            "Overall functional coverage = %.1f%%",rv32i_cg.get_coverage()),UVM_NONE)
        `uvm_info("COV",$sformatf(
            "Opcode coverage = %.1f%%",rv32i_cg.cp_op.get_coverage()),UVM_NONE)
        `uvm_info("COV",$sformatf(
            "Planned edge coverage = %.1f%%",rv32i_cg.cx_op_edge.get_coverage()),UVM_NONE)
    endfunction
endclass

// ================================================================
// Environment and test
// ================================================================
class rv32i_environment extends uvm_env;
    `uvm_component_utils(rv32i_environment)
    rv32i_agent      agt;
    rv32i_scoreboard scb;
    rv32i_coverage   cov;

    function new(string name="rv32i_environment",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt=rv32i_agent::type_id::create("agt",this);
        scb=rv32i_scoreboard::type_id::create("scb",this);
        cov=rv32i_coverage::type_id::create("cov",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.send.connect(scb.recv);
        agt.mon.send.connect(cov.analysis_export);
    endfunction
endclass

class rv32i_test extends uvm_test;
    `uvm_component_utils(rv32i_test)
    rv32i_sequence    seq;
    rv32i_environment env;

    function new(string name="rv32i_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seq=rv32i_sequence::type_id::create("seq");
        env=rv32i_environment::type_id::create("env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass

// ================================================================
// Top testbench
// ================================================================
module tb_rv32i_uvm_full;
    logic clk=0;
    always #5 clk=~clk;

    rv32i_if r_if(clk);

    rv32i_cpu dut (
        .clk(clk),
        .rst_n(r_if.rst_n),
        .ready(1'b1),
        .instr_code(r_if.instr),
        .bus_rdata(32'b0),
        .transfer(),
        .instr_addr(),
        .bus_addr(),
        .bus_wdata(),
        .bus_we(),
        .d_inst_type()
    );

    assign r_if.rf_we    = dut.rf_we;
    assign r_if.x1_data  = dut.U_DATAPATH.U_REG_FILE.register_file[1];
    assign r_if.x2_data  = dut.U_DATAPATH.U_REG_FILE.register_file[2];
    assign r_if.rd3_data = dut.U_DATAPATH.U_REG_FILE.register_file[3];

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0,tb_rv32i_uvm_full);
    end

    initial begin
        uvm_config_db#(virtual rv32i_if)::set(null,"*","vif",r_if);
        run_test("rv32i_test");
    end
endmodule

