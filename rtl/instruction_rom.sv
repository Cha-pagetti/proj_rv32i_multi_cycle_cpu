// not for real memory (for simulation)
module instruction_rom (
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);
 
    // 16 word instr rom
    logic [31:0] instr_rom [0:127]; // rom 200

    //initial begin
        // addi
        // instr_rom[0] = 32'h0281_8293;
        // instr_rom[1] = 32'h0023_8413;
        //// add
        //instr_rom[0] = 32'h0041_82b3; // add x5, x3, x4; : x4 + x3 = x5
        //instr_rom[1] = 32'h00B5_82B3;
        //// sub
        //instr_rom[2] = 32'h4043_82B3;
        //instr_rom[3] = 32'h4072_02B3;
        //// xor  
        //instr_rom[4] = 32'h003342B3;
        //// or
        //instr_rom[5] = 32'h003362B3;
        //// and
        //instr_rom[6] = 32'h003372B3;
        //// sll
        //instr_rom[7] = 32'h004192B3;
        //instr_rom[8] = 32'h004512B3;
        //// srl
        //instr_rom[9] = 32'h002452B3;
        //instr_rom[10] = 32'h004552B3;
        //// sra
        //instr_rom[11] = 32'h402452B3;
        //instr_rom[12] = 32'h404552B3;
        //// slt
        //instr_rom[13] = 32'h0041A2B3;
        //instr_rom[14] = 32'h003222B3;
        //instr_rom[15] = 32'h00C1A2B3;
        //#160;
        //// sltu
        //instr_rom[0] = 32'h0041B2B3;
        //instr_rom[1] = 32'h003232B3;
        //instr_rom[2] = 32'h00C1B2B3;
        //// sw
        //instr_rom[3] = 32'h00302023;
        // instr_rom[4] = 32'h00A4A0A3;
        //// sh
        //instr_rom[5] = 32'h00E21323;
        //instr_rom[6] = 32'h00E191A3;
        //// sb
        //instr_rom[7] = 32'h00E302A3;
        //instr_rom[8] = 32'h00E101A3;
        // LW
        // instr_rom[5] = 32'h0014A283;
        // instr_rom[6] = 32'hfe629ce3; 
        // LUI
        //instr_rom[0] = 32'h123452b7;
        // AUIPC
        // JAL
        // JALR
    //end
    
initial begin
        // 기존: $readmemh("rom_code_gpio.mem", instr_rom, 0, 120);
        $readmemh("rom_code_apb_ram.mem", instr_rom); 
    end

    // remain addr calc (pc = pc + 4)
    // but 1 addr -> 4 byte?
    // to access 4 byte
    // prev version: need pc+:4
    // current version: need pc (just 1)
    assign instr_code = instr_rom[instr_addr[31:2]]; 
endmodule

