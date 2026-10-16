`timescale 1ns / 1ps
`default_nettype none

module TWO_FLOP_SYNCHRONIZER #(
    parameter WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire [WIDTH:0] d_in,
    output reg [WIDTH:0] d_out
);

    reg [WIDTH:0] sync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= {WIDTH+1{1'b0}};
            d_out <= {WIDTH+1{1'b0}};
        end else begin
            sync1 <= d_in;
            d_out <= sync1;
        end
    end
endmodule
