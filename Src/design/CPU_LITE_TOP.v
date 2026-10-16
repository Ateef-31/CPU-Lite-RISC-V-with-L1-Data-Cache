`timescale 1ns / 1ps
`default_nettype none

module CPU_LITE_TOP(
    input wire clk_fast,   // 150 MHz
    input wire clk_slow,   // 70 MHz

    input wire rst_fast_n, // Active-low reset for fast clock domain
    input wire rst_slow_n, // Active-low reset for slow clock domain

    // Wires - Program Memory
    input wire [31:0] inst_from_imem,
    output wire [11:0] pc_to_imem,

    // Wires for Data Memory
    output wire [13:0] mem_addr,
    output wire [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    output wire mem_wen
);

    // Wires - Cache to Core
    wire cache_req, cache_rw, cache_ready;
    wire [13:0] cache_addr;
    wire [31:0] cache_wdata, cache_rdata;

    // Wires - CDC Bridge
    wire cmd_w_en, cmd_full, cmd_r_en, cmd_empty;
    wire [46:0] cmd_data_in, cmd_data_out;

    wire rsp_w_en, rsp_full, rsp_r_en, rsp_empty;
    wire [31:0] rsp_data_in, rsp_data_out;


    // Program Memory - Fast Clock Domain
  /*  PROGRAM_MEMORY imem (
        .fast_clk(clk_fast),
        .reset_n(rst_fast_n),
        .program_counter_index(pc_to_imem),
        .instruction(inst_from_imem)
    );
*/

    // CPU Core - Fast Clock Domain
    CPU_CORE core (
        .clk_cpu(clk_fast),
        .reset_n(rst_fast_n),
        .instruction(inst_from_imem),
        .pc_out(pc_to_imem),

        .cache_ready(cache_ready),
        .cache_rdata(cache_rdata),

        .cache_req(cache_req),
        .cache_rw(cache_rw),
        .cache_addr(cache_addr),
        .cache_wdata(cache_wdata)
    );


    // L1 Data Cache - Fast Clock Domain
    L1_DATA_CACHE cache (
        .clk_cpu(clk_fast),
        .reset_n(rst_fast_n),

        .req_valid(cache_req),
        .req_rw(cache_rw),
        .req_addr(cache_addr),
        .req_wdata(cache_wdata),

        .ready(cache_ready),
        .rdata(cache_rdata),

        .cdc_cmd_en(cmd_w_en),
        .cdc_cmd_data(cmd_data_in),
        .cdc_cmd_full(cmd_full),

        .cdc_rsp_en(rsp_r_en),
        .cdc_rsp_data(rsp_data_out),
        .cdc_rsp_empty(rsp_empty)
    );


    // CDC Bridge - Separate Resets for Both Domains
    CDC_BRIDGE cdc (
        .clk_cpu(clk_fast),
        .rst_cpu_n(rst_fast_n),

        .clk_mem(clk_slow),
        .rst_mem_n(rst_slow_n),

        .cmd_w_en(cmd_w_en),
        .cmd_data_in(cmd_data_in),
        .cmd_full(cmd_full),

        .cmd_r_en(cmd_r_en),
        .cmd_data_out(cmd_data_out),
        .cmd_empty(cmd_empty),

        .rsp_w_en(rsp_w_en),
        .rsp_data_in(rsp_data_in),
        .rsp_full(rsp_full),

        .rsp_r_en(rsp_r_en),
        .rsp_data_out(rsp_data_out),
        .rsp_empty(rsp_empty)
    );


    // Slow Memory Controller - Slow Clock Domain
    SLOW_MEM_CONTROLLER mem_ctrl (
        .clk_mem(clk_slow),
        .rst_mem_n(rst_slow_n),

        .cmd_empty(cmd_empty),
        .cmd_data(cmd_data_out),
        .cmd_r_en(cmd_r_en),

        .rsp_full(rsp_full),
        .rsp_w_en(rsp_w_en),
        .rsp_data(rsp_data_in),

        .mem_wen(mem_wen),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata)
    );/*
    
    // Data Memory - Slow Clock Domain
    DATA_MEMORY dmem (
        .clk_mem(clk_slow),
        .rst_mem_n(rst_slow_n),

        .addr(mem_addr),
        .wdata(mem_wdata),
        .wen(mem_wen),
        .rdata(mem_rdata)
    );
*/
endmodule

