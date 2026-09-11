`ifndef RV32I_PKG
`define RV32I_PKG

// package for debug
// to probe type definition easily
package rv32i_pkg;

typedef enum logic [6:0] {
    OP_RTYPE = 7'b011_0011,
    OP_STYPE = 7'b010_0011,
    OP_ITYPE = 7'b001_0011,
    OP_ILTYPE = 7'b000_0011, // mem[rs + imm] => rd
    OP_BTYPE = 7'b110_0011,  // branch
    OP_UTYPE_LUI = 7'b011_0111,
    OP_UTYPE_AUIPC = 7'b001_0111,
    OP_JTYPE = 7'b110_1111,
    OP_JLTYPE = 7'b110_0111
} opcode_e;

// rv32i instr
typedef enum logic [10:0] {
    // funct7, funct3 + opcode
    
    // r type (op 011_0011)
    ADD  = 11'b0_000_011_0011,
    SUB  = 11'b1_000_011_0011,
    SLL  = 11'b0_001_011_0011,
    SLTU = 11'b0_011_011_0011,
    XOR  = 11'b0_100_011_0011,
    SRL  = 11'b0_101_011_0011,
    SRA  = 11'b1_101_011_0011,
    OR   = 11'b0_110_011_0011,
    AND  = 11'b0_111_011_0011,

    // s type
    //SB   = 11'b0_000_010_0011,
    //SH   = 11'b0_001_010_0011,
    //SW   = 11'b0_010_010_0011,
    SW   = 11'b0_000_010_0011,

    // b type (op 110_0011)
    BEQ  = 11'b0_000_110_0011,
    BNE  = 11'b0_001_110_0011,
    BLT  = 11'b0_100_110_0011,
    BGE  = 11'b0_101_110_0011,
    BLTU = 11'b0_110_110_0011,
    BGEU = 11'b0_111_110_0011,

    // i type
    ADDI = 11'b0_000_001_0011,
    SLTI = 11'b0_010_001_0011,
    SLTIU= 11'b0_011_001_0011,
    XORI = 11'b0_100_001_0011,
    ORI  = 11'b0_110_001_0011,
    ANDI = 11'b0_111_001_0011,
    SLLI = 11'b0_001_001_0011,
    SRLI = 11'b0_101_001_0011,
    SRAI = 11'b1_101_001_0011,

    // il type
    //LB   = 11'b0_000_000_0011,
    //LH   = 11'b0_001_000_0011,
    //LW   = 11'b0_010_000_0011,
    LW   = 11'b0_000_000_0011,

    LBU  = 11'b0_100_000_0011,
    LHU  = 11'b0_101_000_0011,

    // u type
    LUI  = 11'b0_000_011_0111,
    AUIPC= 11'b0_000_001_0111,

    // JAL (j type, 110_1111)
    JAL  = 11'b0_000_110_1111,

    // JALR (jl type, 110_0111)
    JALR = 11'b0_000_110_0111
} rv32i_instr_e;

endpackage

`endif
