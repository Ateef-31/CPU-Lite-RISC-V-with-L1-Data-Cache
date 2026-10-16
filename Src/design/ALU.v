`timescale 1ns / 1ps
`default_nettype none

module ALU (
    input wire [7:0] opcode,
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [4:0] shift_amt,
    output reg [31:0] result,
    output reg Z, N, C, V
);
    
    wire [32:0] add_res = {1'b0, A} + {1'b0, B};
    wire [32:0] sub_res = {1'b0, A} - {1'b0, B};
  //  wire [31:0] mul_A = (opcode == 8'h08) ? A : 32'd0;
  //  wire [31:0] mul_B = (opcode == 8'h08) ? B : 32'd0;
  //  wire [63:0] mul_res = $signed(mul_A) * $signed(mul_B);

    always @(*) begin
        // Default flag values
        Z = 1'b0; N = 1'b0; C = 1'b0; V = 1'b0;
        result = 32'd0;

        case(opcode)
            8'h06, 8'h16: begin // ADD, ADDI
                result = add_res[31:0];
                C = add_res[32];
                V = (A[31] == B[31]) && (result[31] != A[31]);
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h07, 8'h17, 8'h0C: begin // SUB, SUBI, CMP
                result = sub_res[31:0];
                C = !sub_res[32]; // C=1 means no borrow
                V = (A[31] != B[31]) && (result[31] != A[31]);
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h08: begin // MUL
                result = $signed(A) * $signed(B);
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h09, 8'h18: begin // AND, ANDI
                result = A & B;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h0A, 8'h19: begin // OR, ORI
                result = A | B;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h0B: begin // NOT
                result = ~A;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h10, 8'h1A: begin // XOR, XORI
                result = A ^ B;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h0D: begin // EQ
                result = (A == B) ? 32'd1 : 32'd0;
                Z = (result == 32'd0);
            end
            8'h11: begin // SHL
                result = A << shift_amt;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h12: begin // SHR
                result = A >> shift_amt;
                Z = (result == 32'd0);
                N = result[31];
            end
            8'h13: begin // SAR
                result = $signed(A) >>> shift_amt;
                Z = (result == 32'd0);
                N = result[31];
            end
            default: result = A; 
        endcase
    end
endmodule
