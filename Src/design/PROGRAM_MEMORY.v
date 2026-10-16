`timescale 1ns/1ps
`default_nettype none

module PROGRAM_MEMORY #(
    parameter PC_WIDTH = 12,
    parameter INST_WIDTH = 32,
    parameter MEM_DEPTH = 1 << PC_WIDTH
)(
    input wire fast_clk,
    input wire reset_n,
    input wire [PC_WIDTH-1:0] program_counter_index,
    output reg [INST_WIDTH-1:0] instruction
);

    reg [INST_WIDTH-1:0] program_memory [0:MEM_DEPTH-1];
    initial begin
        $readmemh("inst_mem.mem", program_memory);
    end

    always @(posedge fast_clk or negedge reset_n) begin
        if (!reset_n) begin
            instruction <= {INST_WIDTH{1'b0}};
        end
        else begin
            instruction <= program_memory[program_counter_index];
        end
    end

endmodule
