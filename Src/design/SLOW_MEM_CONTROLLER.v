`timescale 1ns / 1ps
`default_nettype none

module SLOW_MEM_CONTROLLER (
    input wire clk_mem,
    input wire rst_mem_n,
    input wire cmd_empty,
    input wire [46:0] cmd_data,
    output reg cmd_r_en,
    input wire rsp_full,
    output reg rsp_w_en,
    output reg [31:0] rsp_data,
    output reg mem_wen,
    output reg [13:0] mem_addr,
    output reg [31:0] mem_wdata,
    input wire [31:0] mem_rdata
);

    localparam IDLE       = 2'd0;
    localparam WAIT_SRAM  = 2'd1;
    localparam READ_BURST = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] burst_count, burst_count_next;

    wire req_rw = cmd_data[46];
    wire [13:0] req_addr = cmd_data[45:32];
    wire [31:0] req_wdata = cmd_data[31:0];

    reg        cmd_r_en_next;
    reg        rsp_w_en_next;
    reg [31:0] rsp_data_next;
    reg        mem_wen_next;
    reg [13:0] mem_addr_next;
    reg [31:0] mem_wdata_next;

    always @(*) begin
        next_state       = state;
        cmd_r_en_next    = 1'b0;
        rsp_w_en_next    = 1'b0;
        rsp_data_next    = rsp_data;
        mem_wen_next     = 1'b0;
        mem_addr_next    = mem_addr;
        mem_wdata_next   = mem_wdata;
        burst_count_next = burst_count;

        case (state)
            IDLE: begin
                if (!cmd_empty && !cmd_r_en) begin
                    cmd_r_en_next = 1'b1;
                    if (req_rw) begin
                        mem_addr_next  = req_addr;
                        mem_wdata_next = req_wdata;
                        mem_wen_next   = 1'b1;
                        next_state     = IDLE;
                    end else begin
                        mem_addr_next    = {req_addr[13:2], 2'b00};
                        burst_count_next = 2'd0;
                        next_state       = WAIT_SRAM;
                    end
                end else begin
                    cmd_r_en_next = 1'b0;
                end
            end

            WAIT_SRAM: begin
                cmd_r_en_next = 1'b0;
                mem_addr_next = mem_addr + 14'd1;
                next_state    = READ_BURST;
            end

            READ_BURST: begin
                if (!rsp_full) begin
                    rsp_w_en_next = 1'b1;
                    rsp_data_next = mem_rdata;
                    if (burst_count == 2'd3) begin
                        next_state = IDLE;
                    end else begin
                        burst_count_next = burst_count + 2'd1;
                        mem_addr_next    = mem_addr + 14'd1;
                    end
                end
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk_mem or negedge rst_mem_n) begin
        if (!rst_mem_n) begin
            state       <= IDLE;
            burst_count <= 2'd0;
            cmd_r_en    <= 1'b0;
            rsp_w_en    <= 1'b0;
            rsp_data    <= 32'd0;
            mem_wen     <= 1'b0;
            mem_addr    <= 14'd0;
            mem_wdata   <= 32'd0;
        end else begin
            state       <= next_state;
            burst_count <= burst_count_next;
            cmd_r_en    <= cmd_r_en_next;
            rsp_w_en    <= rsp_w_en_next;
            rsp_data    <= rsp_data_next;
            mem_wen     <= mem_wen_next;
            mem_addr    <= mem_addr_next;
            mem_wdata   <= mem_wdata_next;
        end
    end

endmodule
