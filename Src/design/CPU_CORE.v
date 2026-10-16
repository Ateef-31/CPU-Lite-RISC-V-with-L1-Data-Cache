`timescale 1ns / 1ps
`default_nettype none

module CPU_CORE (
    input wire clk_cpu,
    input wire reset_n,

    // Instruction memory
    input wire [31:0] instruction, // 32 bit Instruction from Program Memory
    output wire [11:0] pc_out, // Goes to the Program Memory to get the 32 bit instruction

    // L1 cache interface
    input wire cache_ready,
    input wire [31:0] cache_rdata, // Data read back from the Cache
    output reg cache_req, // Used for Memory state for LOAD and STORE Operations
    output reg cache_rw,    // Request the Cache to Write(1) or Read(0)
    output reg [13:0] cache_addr,   // 14 Bit address {00,imm2} as the data memory address width is 14 bit 
    output reg [31:0] cache_wdata   // Data to be written to the Cache on cache_rw = 1
);

    // 5 Stages of CPU core
    localparam FETCH = 3'd0;
    localparam DECODE = 3'd1;
    localparam EXECUTE = 3'd2;
    localparam MEMORY = 3'd3;
    localparam WRITEBACK = 3'd4;

    reg [2:0] state , next_state;
    reg [31:0] instruction_reg; // Used to Break the critical Path in Timing 

    // PC CONTROL
    //
    // 00 = increment
    // 01 = load target
    // 10 = hold
    // ============================================================

    localparam PC_INC  = 2'b00; // Normal Instruction
    localparam PC_LOAD = 2'b01; // When Branch or JMP Instruction comes then Loading the target address value
    localparam PC_HOLD = 2'b10; // Default case Hold the PC value

    reg [1:0]  pc_control; //used to control the program counter value
    reg [11:0] pc_target; // Used when JMP or any Branch OPCODE is used

    // INSTRUCTION FIELDS
    wire [7:0] opcode;  // instruction[31:24] 8bit opcode 
    wire [3:0] Rd;      // instruction[23:20] Data Register
    wire [3:0] Rs1;     // instruction[19:16] Source register 1
    wire [3:0] Rs2;     // instruction[15:12] Source register 2
    wire [11:0] imm12;  // instruction[11:0]  12 bit address

    wire [31:0] imm_zero_ext; // Used by LOAD_IMM OPCODE 03
    wire [31:0] imm_sign_ext; // Used for ADDI and SUBI OPCODE 16 , 17

    // REGISTER FILE
    /*
     * STORE:
     *   STORE     Rd, ADDR
     *   STORE_IND Rd, Rs2
     * For STORE instructions, Rd is the source data register.
     */
     // STORE AND STORE_IND keep their Data Register in Rd so port 1 is redirected to Rd
     // OPCODE 04 and 05 are used by STORE AND STORE_IND
    wire [3:0] rf_rs1_addr = (opcode == 8'h04 || opcode == 8'h05) ? Rd : Rs1;
        
    wire [3:0] rf_rs2_addr = Rs2; // STORE_IND address register is Rs2

    reg rf_write; //request to write to the register file 
    reg [31:0] rd_data_in; // data to be written in the register file

    wire [31:0] rs1_data;   // 32 Bit Data from the Source Register 1
    wire [31:0] rs2_data;   // 32 Bit Data from the Source Register 2

    // ALU Operation inputs and outputs
    reg [31:0] alu_A;
    reg [31:0] alu_B;

    wire [31:0] alu_result; // ALU Final Result after operation
    wire Z,N,C,V; // PSR Flags to update Based on ALU Operation

    // PSR
    // PSR[0] = Z
    // PSR[1] = N
    // PSR[2] = C
    // PSR[3] = V

    reg [3:0] psr; // To hold the values of the Flags
    
    // PROGRAM COUNTER
    PROGRAM_COUNTER #(
        .PC_WIDTH(12)
    ) pc_inst (
        .fast_clk(clk_cpu),
        .resetn(reset_n),
        .pc_control(pc_control),
        .target_address(pc_target),
        .program_counter_index(pc_out)
    );

    // INSTRUCTION DECODER

    INSTRUCTION_DECODER dec_inst (
        .instruction(instruction_reg),
        .opcode(opcode),
        .Rd(Rd),
        .Rs1(Rs1),
        .Rs2(Rs2),
        .imm12(imm12),
        .imm_zero_ext(imm_zero_ext),
        .imm_sign_ext(imm_sign_ext)
    );

    // REGISTER FILE
    REGISTER_FILE #(
        .DATA_WIDTH(32),
        .REG_ADDR_WIDTH(4),
        .NUM_REGS(16)
    ) rf_inst (
        .fast_clk(clk_cpu),
        .reset_n(reset_n),
        
        .rs1_addr(rf_rs1_addr), // Source Register 1 address 4 bits
        .rs2_addr(rf_rs2_addr), // Source Register 2 address 4 bits

        .rs1_data(rs1_data),    // 32 Bit Data present Source Register 1 Address 
        .rs2_data(rs2_data),    // 32 Bit Data present Source Register 2 Address

        .rd_addr(Rd),           // Can be used as Both Destination Register and Data Source Register
                                // LOAD , LOAD_IND, LOAD_IMM uses Rd as Destination Register
                                //For STORE,STORE_IND the value at Rd will be stored in the Address Location
        .rd_data(rd_data_in),
        .reg_write(rf_write)
    );

    // ALU

    ALU alu_inst (
        .opcode(opcode),
        .A(alu_A),
        .B(alu_B),
        .shift_amt(rs2_data[4:0]), // [4:0] Bits of RS2 Data
        .result(alu_result),
        .Z(Z),
        .N(N),
        .C(C),
        .V(V)
    );
    
    always @(posedge clk_cpu or negedge reset_n) begin
        if(!reset_n) begin
            instruction_reg <= 32'b0;
            end
        else begin     
        instruction_reg <= instruction; // Used to Break the critical Path in Timing 
     end
  end

    // SEQUENTIAL STATE + PSR

    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            state <= FETCH;
            psr <= 4'd0;
        end
        else begin
            state <= next_state;
            /*
             * Update PSR only during EXECUTE.
             * alu_A / alu_B / alu_result are combinational.
             * At the EXECUTE clock edge, these correspond to
             * the current instruction.
             */
             if (state == EXECUTE) begin
                case (opcode)
                    // Z N C V
                    8'h06,    // ADD
                    8'h07,    // SUB
                    8'h0C,    // CMP
                    8'h16,    // ADDI
                    8'h17:    // SUBI
                        psr <= {V, C, N, Z};

                    // Z N update Operations

                    8'h08,    // MUL
                    8'h09,    // AND
                    8'h0A,    // OR
                    8'h0B,    // NOT
                    8'h10,    // XOR
                    8'h11,    // SHL
                    8'h12,    // SHR
                    8'h13,    // SAR
                    8'h18,    // ANDI
                    8'h19,    // ORI
                    8'h1A:    // XORI
                        psr <= {psr[3:2], N, Z};

                    // Z only
                    8'h0D: begin // EQ
                        psr <= {psr[3:1], Z};
                    end
                    default: begin
                        // No PSR update
                        psr <= psr;
                    end
                endcase
            end
        end
    end

    // COMBINATIONAL CONTROL

    always @(*) begin
        // DEFAULT VALUES
        next_state  = state;

        pc_control  = PC_HOLD;
        pc_target   = 12'd0;

        rf_write    = 1'b0; // Write to Register if 1 else Read From the Register
        rd_data_in  = 32'd0; // Data written to the register

        cache_req   = 1'b0;
        cache_rw    = 1'b0;
        cache_addr  = 14'd0;
        cache_wdata = 32'd0;

        // --------------------------------------------------------
        // ALU OPERANDS
        // Otherwise ADDI works in EXECUTE but fails in WRITEBACK
        // because alu_B would return to rs2_data.
        // --------------------------------------------------------

        alu_A = rs1_data;
        case (opcode)

            // Immediate arithmetic uses Sign extended address for ADDI and SUBI
            // Fields Used by ANDI and SUBI are Rd,Rs1,IMM which is sign extended
            8'h16,    // ADDI
            8'h17:    // SUBI
                alu_B = imm_sign_ext;
            // Immediate logical uses Zero extended address for ANDI and ORI and XORI
            8'h18,    // ANDI
            8'h19,    // ORI
            8'h1A:    // XORI
                alu_B = imm_zero_ext;
            default:
                alu_B = rs2_data; // Default value of alu_B is from rs2_data for 
        endcase
        // FSM
        case (state)
            // FETCH
            FETCH: begin
                //instruction_reg = instruction;
                next_state = DECODE;
            end
            // DECODE
            DECODE: begin
                next_state = EXECUTE;
            end
            // EXECUTE
            EXECUTE: begin
                // BRANCH / JUMP
                if (
                    // JMP
                    (opcode == 8'h0E) ||

                    // JMP_IF
                    ((opcode == 8'h0F) && (rs1_data != 32'd0)) ||

                    // BEQ
                    ((opcode == 8'h20) && psr[0]) ||

                    // BNE
                    ((opcode == 8'h21) && !psr[0]) ||

                    // BLT: N ^ V
                    ((opcode == 8'h22) &&
                     (psr[1] ^ psr[3])) ||
                     
                    // BGE: !(N ^ V)
                    ((opcode == 8'h23) &&
                     !(psr[1] ^ psr[3]))
                     
                ) begin

                    pc_control = PC_LOAD;
                    pc_target  = imm12;

                    next_state = FETCH;
                end

                // LOAD / STORE
                else if (
                    (opcode == 8'h01) ||  // LOAD
                    (opcode == 8'h02) ||  // LOAD_IND
                    (opcode == 8'h04) ||  // STORE
                    (opcode == 8'h05)     // STORE_IND
                ) begin
                    next_state = MEMORY;
                end
                // HALT
                else if (opcode == 8'hFF) begin
                    next_state = EXECUTE;
                end
                // ALU / REGISTER WRITEBACK INSTRUCTION
                else begin
                    next_state = WRITEBACK;
                end
            end
            // MEMORY
            MEMORY: begin
                // Keep request asserted until cache acknowledges.
                cache_req = ~cache_ready;
                // Address generation
                if (opcode == 8'h01 || opcode == 8'h04) begin
                    // LOAD / STORE direct address
                    // 12-bit direct address -> 14-bit cache address
                    cache_addr = {2'b00, imm12};
                end
                else if (opcode == 8'h02) begin
                    // LOAD_IND
                    cache_addr = rs1_data[13:0];
                end

                else if (opcode == 8'h05) begin
                    // STORE_IND
                    cache_addr = rs2_data[13:0];
                end
                // Read / write control
                if (opcode == 8'h04 || opcode == 8'h05) begin
                    // STORE
                    cache_rw    = 1'b1;
                    // Rd is the source register for STORE.
                    cache_wdata = rs1_data;
                end
                else begin
                    // LOAD
                    cache_rw    = 1'b0;
                end
                // Cache response
                if (cache_ready) begin
                    // LOAD
                    if (opcode == 8'h01 || opcode == 8'h02) begin
                        next_state = WRITEBACK;
                    end
                    // STORE
                    else begin
                        pc_control = PC_INC;
                        next_state = FETCH;
                    end
                end
            end
            // WRITEBACK
            WRITEBACK: begin
                // Register write enable
                if (
                    
                    (opcode == 8'h01) || // LOAD
                    (opcode == 8'h02) || // LOAD_IND

                    // LOAD_IMM
                    (opcode == 8'h03) ||

                    // ADD
                    (opcode == 8'h06) ||

                    // SUB
                    (opcode == 8'h07) ||

                    // MUL
                    (opcode == 8'h08) ||

                    // AND
                    (opcode == 8'h09) ||

                    // OR
                    (opcode == 8'h0A) ||

                    // NOT
                    (opcode == 8'h0B) ||

                    // EQ
                    (opcode == 8'h0D) ||

                    // XOR
                    (opcode == 8'h10) ||

                    // SHL
                    (opcode == 8'h11) ||

                    // SHR
                    (opcode == 8'h12) ||

                    // SAR
                    (opcode == 8'h13) ||

                    // ADDI
                    (opcode == 8'h16) ||

                    // SUBI
                    (opcode == 8'h17) ||

                    // ANDI
                    (opcode == 8'h18) ||

                    // ORI
                    (opcode == 8'h19) ||

                    // XORI
                    (opcode == 8'h1A)
                ) begin
                    rf_write = 1'b1;
                end
                else begin
                    rf_write = 1'b0;
                end
                // Writeback data mux
                if (opcode == 8'h01 || opcode == 8'h02) begin
                    // LOAD
                    rd_data_in = cache_rdata;
                end
                else if (opcode == 8'h03) begin
                    // LOAD_IMM
                    rd_data_in = imm_zero_ext;
                end
                else begin
                    // ALU instructions
                    rd_data_in = alu_result;
                end
                // Next sequential instruction
                pc_control = PC_INC;
                next_state = FETCH;
            end
            default: begin
                next_state = FETCH;
            end
        endcase
    end
endmodule

