`default_nettype none
`timescale 1ns / 1ps
module ASYNCH_FIFO #(
    parameter DEPTH      = 8,
    parameter DATA_WIDTH = 4,
    parameter PTR_WIDTH  = 3
)(
    input wire wclk,
    input wire wrst_n,

    input wire rclk,
    input wire rrst_n,

    input wire w_en,
    input wire r_en,
    input wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,

    output wire full,
    output wire empty
);

    /*
     * Gray pointers
     */
    wire [PTR_WIDTH:0] g_wptr;
    wire [PTR_WIDTH:0] g_rptr;

    /*
     * Synchronized Gray pointers
     */
    wire [PTR_WIDTH:0] g_wptr_sync;
    wire [PTR_WIDTH:0] g_rptr_sync;

    /*
     * Binary pointers
     */
    wire [PTR_WIDTH:0] b_wptr;
    wire [PTR_WIDTH:0] b_rptr;

    /*
     * Actual memory enables
     */
    wire write_do;
    assign write_do = w_en && !full;
    /*
     * ------------------------------------------------
     * WRITE POINTER -> READ CLOCK DOMAIN
     * ------------------------------------------------
     */
    TWO_FLOP_SYNCHRONIZER #(
        .WIDTH(PTR_WIDTH)
    ) sync_wptr (
        .clk(rclk),
        .rst_n(rrst_n),
        .d_in(g_wptr),
        .d_out(g_wptr_sync)
    );

    /*
     * ------------------------------------------------
     * READ POINTER -> WRITE CLOCK DOMAIN
     * ------------------------------------------------
     */
    TWO_FLOP_SYNCHRONIZER #(
        .WIDTH(PTR_WIDTH)
    ) sync_rptr (
        .clk(wclk),
        .rst_n(wrst_n),
        .d_in(g_rptr),
        .d_out(g_rptr_sync)
    );

    /*
     * ------------------------------------------------
     * WRITE POINTER
     * ------------------------------------------------
     */
    WRITE_POINTER #(
        .PTR_WIDTH(PTR_WIDTH)
    ) wptr_h (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .w_en(w_en),
        .g_rptr_sync(g_rptr_sync),
        .b_wptr(b_wptr),
        .g_wptr(g_wptr),
        .full(full)
    );

    /*
     * ------------------------------------------------
     * READ POINTER
     * ------------------------------------------------
     */
    READ_POINTER #(
        .PTR_WIDTH(PTR_WIDTH)
    ) rptr_h (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .r_en(r_en),
        .g_wptr_sync(g_wptr_sync),
        .b_rptr(b_rptr),
        .g_rptr(g_rptr),
        .empty(empty)
    );

    /*
     * ------------------------------------------------
     * DUAL-CLOCK FIFO MEMORY
     * ------------------------------------------------
     */
        FIFOMEM #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) fifom (
        .wclk(wclk),
        .w_en(write_do),
        .b_wptr(b_wptr[PTR_WIDTH-1:0]),
        .b_rptr(b_rptr[PTR_WIDTH-1:0]),
        .data_in(data_in),
        .full(full),
        .data_out(data_out)
    );

endmodule
