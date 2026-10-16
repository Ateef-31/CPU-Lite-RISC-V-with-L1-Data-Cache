`timescale 1ns / 1ps
`default_nettype none
module READ_POINTER #(
    parameter PTR_WIDTH = 3
)(
    input wire rclk,
    input wire rrst_n,
    input wire r_en,
    input wire [PTR_WIDTH:0] g_wptr_sync,

    output reg [PTR_WIDTH:0] b_rptr,
    output reg [PTR_WIDTH:0] g_rptr,
    output reg empty
);

    reg [PTR_WIDTH:0] b_rptr_next;
    reg [PTR_WIDTH:0] g_rptr_next;
    reg rempty;

    always @(*) begin
        /* Hold pointer by default */
        b_rptr_next = b_rptr;

        /* Increment only when FIFO is not empty */
        if (r_en && !empty)
            b_rptr_next = b_rptr + 1'b1;

        /* Binary to Gray conversion */
        g_rptr_next = b_rptr_next ^ (b_rptr_next >> 1);

        /*
         * FIFO is empty when the NEXT read pointer
         * equals the synchronized write pointer.
         */
        rempty = (g_wptr_sync == g_rptr_next);
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            b_rptr <= {PTR_WIDTH+1{1'b0}};
            g_rptr <= {PTR_WIDTH+1{1'b0}};
            empty  <= 1'b1;
        end
        else begin
            b_rptr <= b_rptr_next;
            g_rptr <= g_rptr_next;
            empty <= rempty;
        end
    end
endmodule

