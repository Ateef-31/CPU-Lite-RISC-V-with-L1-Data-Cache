`timescale 1ns / 1ps
`default_nettype none

module FIFOMEM #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 4,
    parameter PTR_WIDTH  = 3
)(
    input wire wclk,
    input wire w_en,
    input wire [PTR_WIDTH-1:0] b_wptr,
    input wire [PTR_WIDTH-1:0] b_rptr,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire full,
    output wire [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // WRITE CLOCK DOMAIN
    always @(posedge wclk) begin
        if (w_en && !full)
            mem[b_wptr] <= data_in;
    end

    assign data_out = mem[b_rptr];

endmodule
