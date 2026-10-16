`timescale 1ns / 1ps
`default_nettype none

module INSTRUCTION_DECODER #(
    parameter INSTR_WIDTH = 32,
    parameter OPCODE_WIDTH = 8,
    parameter DEST_REG_WIDTH = 4,
    parameter SOURCE_REG_WIDTH = 4,
    parameter ADDR_WIDTH = 12
)(
    input wire [INSTR_WIDTH-1:0] instruction,

    // Instruction fields
    output wire [OPCODE_WIDTH-1:0] opcode,
    output wire [DEST_REG_WIDTH-1:0] Rd,
    output wire [SOURCE_REG_WIDTH-1:0] Rs1,
    output wire [SOURCE_REG_WIDTH-1:0] Rs2,

    // Immediate / direct address
    output wire [ADDR_WIDTH-1:0] imm12,

    // Extended immediate
    output wire [31:0] imm_zero_ext,
    output wire [31:0] imm_sign_ext
);

    // Fixed instruction fields
    assign opcode = instruction[31:24];
    assign Rd = instruction[23:20];
    assign Rs1 = instruction[19:16];
    assign Rs2 = instruction[15:12];
    assign imm12 = instruction[11:0];

    // Immediate extensions
    assign imm_zero_ext = {20'b0, instruction[11:0]};
    assign imm_sign_ext = {{20{instruction[11]}}, instruction[11:0]};
                              
endmodule
