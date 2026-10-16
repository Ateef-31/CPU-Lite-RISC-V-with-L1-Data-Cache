`timescale 1ns / 1ps
`default_nettype none

module REGISTER_FILE #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4,
    parameter NUM_REGS = 16
)(
    input wire fast_clk,
    input wire reset_n,

    // Read ports
    input wire [REG_ADDR_WIDTH-1:0] rs1_addr,
    input wire [REG_ADDR_WIDTH-1:0] rs2_addr,

    output wire [DATA_WIDTH-1:0] rs1_data,
    output wire [DATA_WIDTH-1:0] rs2_data,

    // Write port
    input wire [REG_ADDR_WIDTH-1:0] rd_addr,
    input wire [DATA_WIDTH-1:0] rd_data,
    input wire reg_write
);

    // 16 General Purpose registers, each 32 bits data width
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];

    integer i;

    // Reset and register write
   always @(posedge fast_clk or negedge reset_n) begin
    if (!reset_n) begin
        for (i = 0; i < NUM_REGS; i = i + 1)
            registers[i] <= {DATA_WIDTH{1'b0}};
    end
    else begin
        if (reg_write)
            registers[rd_addr] <= rd_data;
    end
end

// Asynchronous read ports
    
assign rs1_data = registers[rs1_addr];
assign rs2_data = registers[rs2_addr];

endmodule

