`timescale 1ns / 1ps
`default_nettype none

module PROGRAM_COUNTER #(
    parameter PC_WIDTH = 12
    )
    (
    input wire fast_clk,
    input wire resetn,
    input wire [1:0] pc_control,
    input wire [PC_WIDTH-1:0] target_address,
    output reg [PC_WIDTH-1:0] program_counter_index
    );
    
    localparam INCREMENT = 2'b00;
    localparam LOAD = 2'b01;
    
    always@(posedge fast_clk or negedge resetn) begin
    
    if(!resetn) begin
        program_counter_index <= {PC_WIDTH{1'b0}};
        end
    else begin
        case(pc_control) 
            INCREMENT:
                // LINT FIX: Changed + 1 (32-bit int) to + 12'd1
                program_counter_index <= program_counter_index + 12'd1;
            LOAD:
                program_counter_index <= target_address;
            default:
                program_counter_index <= program_counter_index;
        endcase
        end
    end
endmodule

