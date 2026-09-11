// R type
`define ADD  4'b0000
`define SUB  4'b1000
`define SLL  4'b0001
`define SLT  4'b0010
`define SLTU 4'b0011
`define SRL  4'b0101
`define SRA  4'b1101
`define XOR  4'b0100
`define OR   4'b0110
`define AND  4'b0111

// B type
`define BEQ  4'b0000
`define BNE  4'b0001
`define BLT  4'b0100
`define BGE  4'b0101
`define BLTU 4'b0110
`define BGEU 4'b0111

// AUIPC, JAL -> branch
`define BRANCH 4'b0010
