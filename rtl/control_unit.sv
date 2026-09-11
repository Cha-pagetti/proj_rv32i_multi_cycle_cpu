
module control_unit

    import rv32i_pkg::*;
(
    input  logic clk,
    input  logic rst_n,
    input  logic ready,             // from APB ready
    input  logic [31:0] instr_code, // current instruction 32bit code
    output logic [3:0] alu_control, // alu calculation selector
    output logic rf_we,             // reg file in cpu write enable
    output logic alu_src_sel,       // alu rs2 src 0 -> rd2 / 1 -> imm
    output logic bus_we,              // data memory (RAM) write enable
    output logic [2:0] d_inst_type, // S type: send ram instr type (SB,SH,SW)
    output logic [2:0] rf_src_sel,        // reg file wdata src 0 -> alu / 1 -> mem / 2 -> lui (big imm) / 3 -> auipc (pc, long jump destination) / 4 -> jal (pc, come back destination)
    output logic [2:0] jump,        // jump (one hot) / 01: conditional branch (b type), jal (pc += imm) / 10: jalr (pc = rs1 + imm)
    output logic pc_en,             // fetch
    output logic transfer           // to APB transfer 
);
    typedef enum logic [2:0] {
        FETCH, DECODE, EXECUTE, MEMORY, WB
    } process_e;

    logic [2:0] funct3;
    
    opcode_e opcode;
    assign opcode = opcode_e'(instr_code[6:0]);

    rv32i_instr_e rv32i_instr;
    assign rv32i_instr = rv32i_instr_e'({alu_control, opcode});

    assign funct3 = instr_code[14:12];

    process_e c_state, n_state;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        alu_control = 4'b0_000;
        alu_src_sel = 1'b0;
        rf_we = 1'b0;
        bus_we = 1'b0;
        d_inst_type = 3'b111; // init: non existed signal
        rf_src_sel = 3'b000;
        jump = 3'b000;
        pc_en = 1'b0;
        transfer = 1'b0;

        case (c_state)
            FETCH: begin
                //pc_en = 1'b1;
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    // opcode
            
                    // R type
                    OP_RTYPE: begin
                        rf_we = 1'b1;
                        // {funct7[5], funct3}
                        alu_control = {instr_code[30], funct3};
                        n_state = FETCH;
                        pc_en = 1'b1;
                    end

                    // S type
                    OP_STYPE: begin
                        alu_src_sel = 1'b1;
                        alu_control = 4'b0_000; // add for rs1 + imm
                        n_state = MEMORY;
                    end
            
                     // I type - register store
                     OP_ITYPE: begin
                         rf_we = 1'b1;       // store alu value in reg file
                         alu_src_sel = 1'b1; // alu src = imm
                         // srai, srli -> instr_code[30] == funct7[5]으로 구분
                         // 나머지는 funct7[5] == 0으로 처리 
                         alu_control = {
                             (funct3 == 3'b101)? instr_code[30] : 1'b0, 
                             funct3
                         };
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end

                     OP_ILTYPE: begin
                         alu_src_sel = 1'b1;     // alu src = imm
                         alu_control = 4'b0_000; // alu = add
                        n_state = MEMORY;
                     end

                     OP_BTYPE: begin
                         jump = 3'b001;           // pc = pc + imm
                         alu_control = {1'b0, funct3};
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end
                     
                     OP_UTYPE_LUI: begin
                         rf_we = 1'b1;
                         rf_src_sel = 3'b010;
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end

                     OP_UTYPE_AUIPC: begin
                         rf_we = 1'b1;           // register file write
                         rf_src_sel = 3'b011;    // rd = pc + imm
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end

                     OP_JTYPE: begin
                         rf_we = 1'b1;           // register file write
                         rf_src_sel = 3'b100;    // rd = pc + 4
                         jump = 3'b010;           // pc = pc + imm
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end

                     OP_JLTYPE: begin
                         rf_we = 1'b1;           // register file write
                         rf_src_sel = 3'b100;    // rd = pc + 4
                         jump = 3'b100;           // pc = rs1 + imm (alu result)
                         
                         alu_src_sel = 1'b1;     // alu result = rs1 + imm
                         alu_control = 4'b0_000; // add
                        n_state = FETCH;
                        pc_en = 1'b1;
                     end
                endcase
            end
            MEMORY: begin
                case (opcode)
                    OP_STYPE: begin
                        transfer = 1'b1;
                        bus_we = 1'b1;
                        d_inst_type = funct3;
                        if (ready) begin
                            n_state = FETCH;
                            pc_en = 1'b1;
                        end
                    end
                    OP_ILTYPE: begin
                        transfer = 1'b1;
                        d_inst_type = funct3;
                        n_state = WB;
                    end
                endcase
            end
            WB: begin
                rf_we = 1'b1;
                rf_src_sel = 3'b001;
                if (ready) begin
                    n_state = FETCH;
                    pc_en = 1'b1;
                end
            end
        endcase
    end
endmodule
