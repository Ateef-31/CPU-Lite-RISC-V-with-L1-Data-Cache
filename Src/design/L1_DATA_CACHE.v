`timescale 1ns / 1ps
`default_nettype none

module L1_DATA_CACHE (
    input wire clk_cpu,
    input wire reset_n,
    input wire req_valid,
    input wire req_rw,
    input wire [13:0] req_addr,
    input wire [31:0] req_wdata,
    output reg ready,
    output reg [31:0] rdata,
    output reg cdc_cmd_en,
    output reg [46:0] cdc_cmd_data,
    input wire cdc_cmd_full,
    output reg cdc_rsp_en,
    input wire [31:0] cdc_rsp_data,
    input wire cdc_rsp_empty
);

    // 8 cache lines
    // 4 words per line
    // 32 bits per word = 128 bits per line

    reg [127:0] cache_data [0:7];

    // 14-bit word address:
    // [13:5] = tag   : 9 bits
    // [4:2]  = index : 3 bits
    // [1:0]  = word offset : 2 bits

    reg [8:0] cache_tag [0:7];
    reg       cache_valid[0:7];

    wire [1:0] offset = req_addr[1:0];
    wire [2:0] index  = req_addr[4:2];
    wire [8:0] tag    = req_addr[13:5];

    wire hit = cache_valid[index] &&
               (cache_tag[index] == tag);

    localparam IDLE            = 2'd0;
    localparam READ_FILL       = 2'd1;
    localparam READ_FILL_DONE  = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] fill_count, fill_count_next;
    reg [127:0] fill_buffer, fill_buffer_next;
    integer i;

    reg        ready_next;
    reg [31:0] rdata_next;
    reg        cdc_cmd_en_next;
    reg [46:0] cdc_cmd_data_next;
    reg        cdc_rsp_en_next;

    reg         cache_data_wr_en;
    reg [127:0] cache_data_wr_val;
    reg         cache_tag_wr_en;
    reg         cache_valid_wr_en;

    // ---------------------------------------------------------
    // COMBINATIONAL  next-state and next-output logic
    // ---------------------------------------------------------
    always @(*) begin
        next_state        = state;
        ready_next        = 1'b0;
        rdata_next        = rdata;
        cdc_cmd_en_next   = 1'b0;
        cdc_cmd_data_next = cdc_cmd_data;
        cdc_rsp_en_next   = 1'b0;
        fill_count_next   = fill_count;
        fill_buffer_next  = fill_buffer;

        cache_data_wr_en  = 1'b0;
        cache_data_wr_val = cache_data[index];
        cache_tag_wr_en   = 1'b0;
        cache_valid_wr_en = 1'b0;

        case (state)
            IDLE: begin
                if (req_valid) begin
                    if (req_rw) begin
                        if (!cdc_cmd_full) begin
                            cdc_cmd_data_next = {1'b1, req_addr, req_wdata};
                            cdc_cmd_en_next   = 1'b1;
                            if (hit) begin
                                cache_data_wr_en = 1'b1;
                                case (offset)
                                    2'b00: cache_data_wr_val = {cache_data[index][127:32], req_wdata};
                                    2'b01: cache_data_wr_val = {cache_data[index][127:64], req_wdata, cache_data[index][31:0]};
                                    2'b10: cache_data_wr_val = {cache_data[index][127:96], req_wdata, cache_data[index][63:0]};
                                    2'b11: cache_data_wr_val = {req_wdata, cache_data[index][95:0]};
                                    default: cache_data_wr_val = cache_data[index];
                                endcase
                            end
                            ready_next = 1'b1;
                        end
                    end else begin
                        if (hit) begin
                            case (offset)
                                2'b00: rdata_next = cache_data[index][31:0];
                                2'b01: rdata_next = cache_data[index][63:32];
                                2'b10: rdata_next = cache_data[index][95:64];
                                2'b11: rdata_next = cache_data[index][127:96];
                                default: rdata_next = 32'd0;
                            endcase
                            ready_next = 1'b1;
                        end else begin
                            if (!cdc_cmd_full) begin
                                cdc_cmd_data_next = {1'b0, req_addr[13:2], 2'b00, 32'd0};
                                cdc_cmd_en_next   = 1'b1;
                                fill_count_next   = 2'd0;
                                next_state        = READ_FILL;
                            end
                        end
                    end
                end
            end

            READ_FILL: begin
                if (!cdc_rsp_empty && !cdc_rsp_en) begin
                    case (fill_count)
                        2'd0: fill_buffer_next = {fill_buffer[127:32], cdc_rsp_data};
                        2'd1: fill_buffer_next = {fill_buffer[127:64], cdc_rsp_data, fill_buffer[31:0]};
                        2'd2: fill_buffer_next = {fill_buffer[127:96], cdc_rsp_data, fill_buffer[63:0]};
                        2'd3: fill_buffer_next = {cdc_rsp_data, fill_buffer[95:0]};
                        default: fill_buffer_next = fill_buffer;
                    endcase
                    cdc_rsp_en_next = 1'b1;
                    if (fill_count == 2'd3)
                        next_state = READ_FILL_DONE;
                    else
                        fill_count_next = fill_count + 2'd1;
                end else begin
                    cdc_rsp_en_next = 1'b0;
                end
            end

            READ_FILL_DONE: begin
                cdc_rsp_en_next   = 1'b0;
                cache_data_wr_en  = 1'b1;
                cache_data_wr_val = fill_buffer;
                cache_tag_wr_en   = 1'b1;
                cache_valid_wr_en = 1'b1;
                case (offset)
                    2'b00: rdata_next = fill_buffer[31:0];
                    2'b01: rdata_next = fill_buffer[63:32];
                    2'b10: rdata_next = fill_buffer[95:64];
                    2'b11: rdata_next = fill_buffer[127:96];
                    default: rdata_next = 32'd0;
                endcase
                next_state = IDLE;
                ready_next = 1'b1;
            end

            default: next_state = IDLE;
        endcase
    end

    // ---------------------------------------------------------
    // CONTROL FLOPS legitimate async reset
    // ---------------------------------------------------------
    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            state        <= IDLE;
            ready        <= 1'b0;
            rdata        <= 32'd0;
            cdc_cmd_en   <= 1'b0;
            cdc_cmd_data <= 47'd0;
            cdc_rsp_en   <= 1'b0;
            fill_count   <= 2'd0;
            fill_buffer  <= 128'd0;
        end else begin
            state        <= next_state;
            ready        <= ready_next;
            rdata        <= rdata_next;
            cdc_cmd_en   <= cdc_cmd_en_next;
            cdc_cmd_data <= cdc_cmd_data_next;
            cdc_rsp_en   <= cdc_rsp_en_next;
            fill_count   <= fill_count_next;
            fill_buffer  <= fill_buffer_next;
        end
    end

    // ---------------------------------------------------------
    // CACHE_VALID ARRAY  real flops, legitimately needs reset
    // ---------------------------------------------------------
    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < 8; i = i + 1)
                cache_valid[i] <= 1'b0;
        end else if (cache_valid_wr_en) begin
            cache_valid[index] <= 1'b1;
        end
    end

    // ---------------------------------------------------------
    // CACHE_DATA MEMORY ARRAY  no reset, enable-only
    // ---------------------------------------------------------
    always @(posedge clk_cpu) begin
        if (cache_data_wr_en)
            cache_data[index] <= cache_data_wr_val;
    end

    // ---------------------------------------------------------
    // CACHE_TAG MEMORY ARRAY  no reset, enable-only
    // ---------------------------------------------------------
    always @(posedge clk_cpu) begin
        if (cache_tag_wr_en)
            cache_tag[index] <= tag;
    end

endmodule
