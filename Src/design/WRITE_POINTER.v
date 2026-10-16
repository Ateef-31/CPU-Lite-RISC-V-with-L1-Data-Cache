`timescale 1ns / 1ps
`default_nettype none
module WRITE_POINTER #(
    parameter PTR_WIDTH = 3
    )
    (
    input wire wclk,
    input wire wrst_n,
    input wire w_en,
    input wire [PTR_WIDTH:0] g_rptr_sync,

    output reg [PTR_WIDTH:0] b_wptr,
    output reg [PTR_WIDTH:0] g_wptr,
    output reg full
    );
    
    reg [PTR_WIDTH:0] b_wptr_next;
    reg [PTR_WIDTH:0] g_wptr_next;
    reg wfull;

     // Next-state logic
    always @(*) begin
        /* Hold pointer by default */
        b_wptr_next = b_wptr;

        /* Increment only when FIFO is not full */
        if (w_en && !full)
            b_wptr_next = b_wptr + 1'b1;

        /* Binary to Gray conversion */
        g_wptr_next = b_wptr_next ^ (b_wptr_next >> 1);

        /*
         * FIFO is full when the NEXT write pointer
         * equals the synchronized read pointer with
         * the two MSBs inverted.
         */
        wfull = (g_wptr_next ==
                {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                  g_rptr_sync[PTR_WIDTH-2:0]});
    end

    // Write-domain registers
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            b_wptr <= {PTR_WIDTH+1{1'b0}};
            g_wptr <= {PTR_WIDTH+1{1'b0}};
            full <= 1'b0;
        end
        else begin
            b_wptr <= b_wptr_next;
            g_wptr <= g_wptr_next;
            full <= wfull;
        end
    end
endmodule

