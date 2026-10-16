`timescale 1ns / 1ps
`default_nettype none

module DATA_MEMORY (
    input wire clk_mem,
    input wire rst_mem_n,
    input wire [13:0] addr,
    input wire [31:0] wdata,
    input wire wen,
    output reg [31:0] rdata
);

    // 16K x 32 Data Memory[cite: 1]
    reg [31:0] ram [0:16383];

    // Hardcoded initialization to bypass Vivado file path issues
    initial begin
        // 1. Initialize entire memory to 0 to prevent 'x' propagation
        for (integer i = 0; i < 16384; i = i + 1) begin
            ram[i] = 32'd0;
        end
        
        // 2. Load the 10 data values starting at address 0x100
        ram[14'h0100] = 32'd1;
        ram[14'h0101] = 32'd2;
        ram[14'h0102] = 32'd3;
        ram[14'h0103] = 32'd4;
        ram[14'h0104] = 32'd5;
        ram[14'h0105] = 32'd6;
        ram[14'h0106] = 32'd7;
        ram[14'h0107] = 32'd8;
        ram[14'h0108] = 32'd9;
        ram[14'h0109] = 32'd10;
    end

    always @(posedge clk_mem or negedge rst_mem_n) begin
        if (!rst_mem_n) begin
            rdata <= 32'd0;
        end else begin
            if (wen) begin
                ram[addr] <= wdata;
            end
            rdata <= ram[addr]; // Synchronous read
        end
    end
endmodule
