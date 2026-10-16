`timescale 1ns / 1ps
`default_nettype none

module CDC_BRIDGE (
    input wire clk_cpu, input wire rst_cpu_n,
    input wire clk_mem, input wire rst_mem_n,
    
    // CPU Domain Signals (Command)
    input wire cmd_w_en,
    input wire [46:0] cmd_data_in,
    output wire cmd_full,
    
    // Memory Domain Signals (Command)
    input wire cmd_r_en,
    output wire [46:0] cmd_data_out,
    output wire cmd_empty,

    // Memory Domain Signals (Response)
    input wire rsp_w_en,
    input wire [31:0] rsp_data_in,
    output wire rsp_full,

    // CPU Domain Signals (Response)
    input wire rsp_r_en,
    output wire [31:0] rsp_data_out,
    output wire rsp_empty
);

    // Instantiate Command FIFO (Fast -> Slow)
    ASYNCH_FIFO #(.DEPTH(16), .DATA_WIDTH(47), .PTR_WIDTH(4)) cmd_fifo (
        .wclk(clk_cpu), .wrst_n(rst_cpu_n),
        .rclk(clk_mem), .rrst_n(rst_mem_n),
        .w_en(cmd_w_en), .r_en(cmd_r_en),
        .data_in(cmd_data_in), .data_out(cmd_data_out),
        .full(cmd_full), .empty(cmd_empty)
    );

    // Instantiate Response FIFO (Slow -> Fast)
    ASYNCH_FIFO #(.DEPTH(16), .DATA_WIDTH(32), .PTR_WIDTH(4)) rsp_fifo (
        .wclk(clk_mem), .wrst_n(rst_mem_n),
        .rclk(clk_cpu), .rrst_n(rst_cpu_n),
        .w_en(rsp_w_en), .r_en(rsp_r_en),
        .data_in(rsp_data_in), .data_out(rsp_data_out),
        .full(rsp_full), .empty(rsp_empty)
    );
endmodule
