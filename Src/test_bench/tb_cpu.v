module tb_cpu();
 
    // Set to 0 to silence the per-cycle trace and only see PASS/FAIL lines.
    localparam VERBOSE_TRACE = 1;
 
    reg clk_150;
    reg clk_70;
    reg rst_fast_n;
    reg rst_slow_n;
 
    integer pass_count = 0;
    integer fail_count = 0;
 
    // ---------------- Clock generation ----------------
    initial begin
        clk_150 = 1'b0;
        forever #3.33 clk_150 = ~clk_150;
    end
 
    initial begin
        clk_70 = 1'b0;
        forever #7.14 clk_70 = ~clk_70;
    end
 
    // ---------------- DUT ----------------
    CPU_LITE_TOP dut (
        .clk_fast(clk_150),
        .clk_slow(clk_70),
        .rst_fast_n(rst_fast_n),
        .rst_slow_n(rst_slow_n)
    );
 
    // ---------------- HALT detection (clears itself on every reset) ----------------
    reg halt_detected;
    always @(posedge clk_150 or negedge rst_fast_n) begin
        if (!rst_fast_n)
            halt_detected <= 1'b0;
        else if (dut.core.opcode == 8'hFF && !halt_detected)
            halt_detected <= 1'b1;
    end
 
    // ---------------- Per-cycle trace (same fields as the original testbench) ----------------
    always @(posedge clk_150) begin
        if (VERBOSE_TRACE && rst_fast_n) begin
            $display(
                "T=%0t STATE=%0d PC=%03h INSTR=%08h OPCODE=%02h PSR=%01h R1=%08h R2=%08h R3=%08h R4=%08h R5=%08h R6=%08h ALU=%08h CACHE_REQ=%b CACHE_READY=%b",
                $time,
                dut.core.state,
                dut.core.pc_out,
                dut.core.instruction,
                dut.core.opcode,
                dut.core.psr,
                dut.core.rf_inst.registers[1],
                dut.core.rf_inst.registers[2],
                dut.core.rf_inst.registers[3],
                dut.core.rf_inst.registers[4],
                dut.core.rf_inst.registers[5],
                dut.core.rf_inst.registers[6],
                dut.core.alu_result,
                dut.core.cache_req,
                dut.core.cache_ready
            );
        end
    end
 
    // ---------------- Test infrastructure ----------------
 
    // Deposit one instruction word into program memory.
    task write_instr(input integer addr, input [31:0] val);
        begin
            dut.imem.program_memory[addr] = val;
        end
    endtask
 
    // Fill the whole instruction memory with HALT so any stray fetch
    // (e.g. a control-flow bug jumping somewhere unintended) halts
    // immediately instead of running into stale/unknown instructions.
    task clear_program_mem;
        integer k;
        begin
            for (k = 0; k < 4096; k = k + 1)
                dut.imem.program_memory[k] = 32'hFF000000;
        end
    endtask
 
    // Same reset pulse width as the original testbench (spans several
    // clk_70 edges too, so the CDC-domain logic resets cleanly).
    task do_reset;
        begin
            rst_fast_n = 1'b0;
            rst_slow_n = 1'b0;
            #50;
            rst_fast_n = 1'b1;
            rst_slow_n = 1'b1;
        end
    endtask
 
    // Run until HALT or timeout (timeout is in clk_150 cycles).
    task wait_for_halt(input integer timeout_cycles, output reg timed_out);
        integer cyc;
        begin
            cyc = 0;
            timed_out = 1'b0;
            while (!halt_detected && cyc < timeout_cycles) begin
                @(posedge clk_150);
                cyc = cyc + 1;
            end
            if (!halt_detected)
                timed_out = 1'b1;
        end
    endtask
 
    task check_equal(input [31:0] actual, input [31:0] expected, input [335:0] what);
    begin
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("  [PASS] %-42s got=0x%08h", what, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("  [FAIL] %-42s got=0x%08h expected=0x%08h", what, actual, expected);
        end
    end
endtask
 
    function [31:0] REG(input integer n);
        REG = dut.core.rf_inst.registers[n];
    endfunction
 
    // =====================================================================
    // TEST PROGRAMS
    // Instruction format: OPCODE[31:24] Rd[23:20] Rs1[19:16] Rs2[15:12] IMM12[11:0]
    // =====================================================================
 
    // TEST 1 (regression): sums data_mem[0x100..0x109] into mem[0x200].
    // Exercises LOAD_IMM, CMP, BGE, ADD, LOAD_IND, ADDI, JMP, STORE, HALT.
    
    task load_test1_array_sum;
        begin
            clear_program_mem;
            write_instr( 0, 32'h03100100); // LOAD_IMM R1,#0x100 (base addr)
            write_instr( 1, 32'h0320000a); // LOAD_IMM R2,#10    (count)
            write_instr( 2, 32'h03300000); // LOAD_IMM R3,#0     (sum)
            write_instr( 3, 32'h03400000); // LOAD_IMM R4,#0     (i)
            write_instr( 4, 32'h0c042000); // loop: CMP R4,R2
            write_instr( 5, 32'h2300000b); // BGE ->11
            write_instr( 6, 32'h06514000); // ADD R5,R1,R4
            write_instr( 7, 32'h02650000); // LOAD_IND R6,R5
            write_instr( 8, 32'h06336000); // ADD R3,R3,R6
            write_instr( 9, 32'h16440001); // ADDI R4,R4,#1
            write_instr(10, 32'h0e000004); // JMP ->4
            write_instr(11, 32'h04300200); // STORE R3 -> [0x200]
            write_instr(12, 32'hff000000); // HALT
        end
    endtask
 
    // TEST 2: ALU functional coverage - ADD, SUB, MUL, AND, OR, XOR, NOT,
    // SHL, SHR, SAR, ADDI, SUBI.
    task load_test2_alu;
        begin
            clear_program_mem;
            write_instr( 0, 32'h03100005); // R1 = 5
            write_instr( 1, 32'h03200003); // R2 = 3
            write_instr( 2, 32'h06312000); // R3  = ADD R1,R2   -> 8
            write_instr( 3, 32'h07412000); // R4  = SUB R1,R2   -> 2
            write_instr( 4, 32'h08512000); // R5  = MUL R1,R2   -> 15
            write_instr( 5, 32'h09612000); // R6  = AND R1,R2   -> 1
            write_instr( 6, 32'h0A712000); // R7  = OR  R1,R2   -> 7
            write_instr( 7, 32'h10812000); // R8  = XOR R1,R2   -> 6
            write_instr( 8, 32'h0B910000); // R9  = NOT R1      -> 0xFFFFFFFA
            write_instr( 9, 32'h03A00002); // R10 = 2 (shift amount)
            write_instr(10, 32'h11B1A000); // R11 = SHL R1,R10  -> 20
            write_instr(11, 32'h12C1A000); // R12 = SHR R1,R10  -> 1
            write_instr(12, 32'h13D9A000); // R13 = SAR R9,R10  -> 0xFFFFFFFE
            write_instr(13, 32'h16E1000A); // R14 = ADDI R1,#10 -> 15
            write_instr(14, 32'h17F10003); // R15 = SUBI R1,#3  -> 2
            write_instr(15, 32'hFF000000); // HALT
        end
    endtask
 
    // TEST 3: immediate logical ops - ANDI, ORI, XORI.
    task load_test3_imm_logic;
        begin
            clear_program_mem;
            write_instr(0, 32'h0310000F); // R1 = 0x0F
            write_instr(1, 32'h18210003); // R2 = ANDI R1,#0x003 -> 0x03
            write_instr(2, 32'h19310030); // R3 = ORI  R1,#0x030 -> 0x3F
            write_instr(3, 32'h1A4100FF); // R4 = XORI R1,#0x0FF -> 0xF0
            write_instr(4, 32'hFF000000); // HALT
        end
    endtask
 
    // TEST 4: control flow - CMP/EQ + BEQ/BNE/BLT/BGE/JMP/JMP_IF.
    // R9 is a "wrong path taken" sentinel: it must stay 0 the whole run,
    // and since unwritten memory now defaults to HALT (see
    // clear_program_mem), any wrong branch halts immediately with R9
    // set and the later "OK" markers left at 0 - both are caught below.
    task load_test4_control_flow;
        begin
            clear_program_mem;
            write_instr( 0, 32'h03100005); // R1 = 5
            write_instr( 1, 32'h03200005); // R2 = 5
            write_instr( 2, 32'h0C012000); // CMP R1,R2      (equal -> Z=1)
            write_instr( 3, 32'h20000006); // BEQ ->6                 (should be taken)
            write_instr( 4, 32'h03900EEE); // R9 = 0xEEE  (fail, must be skipped)
            write_instr( 5, 32'h0E000064); // JMP ->100   (dead end / immediate HALT)
            write_instr( 6, 32'h03300001); // R3 = 1      (BEQ-taken OK)
            write_instr( 7, 32'h03400003); // R4 = 3
            write_instr( 8, 32'h0C014000); // CMP R1,R4      (5 vs 3 -> Z=0)
            write_instr( 9, 32'h2100000C); // BNE ->12                (should be taken)
            write_instr(10, 32'h03900EEE); // R9 = 0xEEE  (fail)
            write_instr(11, 32'h0E000064); // JMP ->100
            write_instr(12, 32'h03500001); // R5 = 1      (BNE-taken OK)
            write_instr(13, 32'h0C041000); // CMP R4,R1      (3-5<0 -> N^V=1)
            write_instr(14, 32'h22000011); // BLT ->17                (should be taken)
            write_instr(15, 32'h03900EEE); // R9 = 0xEEE  (fail)
            write_instr(16, 32'h0E000064); // JMP ->100
            write_instr(17, 32'h03600001); // R6 = 1      (BLT-taken OK)
            write_instr(18, 32'h0C014000); // CMP R1,R4      (5-3>=0)
            write_instr(19, 32'h23000016); // BGE ->22                (should be taken)
            write_instr(20, 32'h03900EEE); // R9 = 0xEEE  (fail)
            write_instr(21, 32'h0E000064); // JMP ->100
            write_instr(22, 32'h03700001); // R7 = 1      (BGE-taken OK)
            write_instr(23, 32'h03A00000); // R10 = 0
            write_instr(24, 32'h0F0A001B); // JMP_IF R10 ->27  (R10==0, NOT taken)
            write_instr(25, 32'h03B00001); // R11 = 1     (fallthrough OK)
            write_instr(26, 32'h03A00001); // R10 = 1
            write_instr(27, 32'h0F0A001E); // JMP_IF R10 ->30  (R10!=0, taken)
            write_instr(28, 32'h03900EEE); // R9 = 0xEEE  (fail)
            write_instr(29, 32'h0E000064); // JMP ->100
            write_instr(30, 32'h03C00001); // R12 = 1     (JMP_IF-taken OK)
            write_instr(31, 32'h0E000021); // JMP ->33
            write_instr(32, 32'h03900EEE); // R9 = 0xEEE  (fail, never reached)
            write_instr(33, 32'h03D00001); // R13 = 1     (JMP OK)
            write_instr(34, 32'h0DE12000); // R14 = EQ R1,R2 (5==5) -> 1
            write_instr(35, 32'h0DF14000); // R15 = EQ R1,R4 (5==3) -> 0
            write_instr(36, 32'hFF000000); // HALT
        end
    endtask
 
    // TEST 5: memory addressing - direct LOAD and STORE_IND.
    task load_test5_mem_addressing;
        begin
            clear_program_mem;
            write_instr(0, 32'h01200104); // LOAD R2, [0x104]     -> preloaded value 5
            write_instr(1, 32'h03300007); // R3 = 7 (value to store)
            write_instr(2, 32'h03400210); // R4 = 0x210 (target address)
            write_instr(3, 32'h05304000); // STORE_IND R3 -> [R4]
            write_instr(4, 32'hFF000000); // HALT
        end
    endtask
 

    // TEST 6: Slow-memory read address sequencing / four-word cache-line fill.
    // Use distinct values so swapped, skipped, or duplicated burst words are
    // detected. The first LOAD misses; the next three LOADs should hit the
    // same four-word cache line and return the corresponding consecutive words.
    task load_test6_read_address_sequence;
        begin
            clear_program_mem;

            // Four consecutive word addresses, all within one 4-word line.
            write_instr(0, 32'h01100100); // LOAD R1, [0x100] -> A
            write_instr(1, 32'h01200101); // LOAD R2, [0x101] -> B
            write_instr(2, 32'h01300102); // LOAD R3, [0x102] -> C
            write_instr(3, 32'h01400103); // LOAD R4, [0x103] -> D
            write_instr(4, 32'hFF000000); // HALT
        end
    endtask

    // =====================================================================
    // TEST SEQUENCER
    // =====================================================================
    reg timed_out;
 
    initial begin
        rst_fast_n = 1'b0;
        rst_slow_n = 1'b0;
 
        // ---- TEST 1: regression - array sum ----
        $display("\n=== TEST 1: Array Sum (LOAD_IMM/CMP/BGE/ADD/LOAD_IND/ADDI/JMP/STORE/HALT) ===");
        load_test1_array_sum;
        do_reset;
        wait_for_halt(5000, timed_out);
        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            #2000; // let the CDC FIFOs / slow memory write settle
            $display("  Sum stored at 0x200 = %0d (0x%0h)", dut.dmem.ram[14'h0200], dut.dmem.ram[14'h0200]);
            check_equal(dut.dmem.ram[14'h0200], 32'd55, "sum(1..10) at mem[0x200]");
        end
 
        // ---- TEST 2: ALU ops ----
        $display("\n=== TEST 2: ALU Operations ===");
        load_test2_alu;
        do_reset;
        wait_for_halt(300, timed_out);
        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            check_equal(REG(3),  32'd8,        "ADD  R3=R1+R2");
            check_equal(REG(4),  32'd2,        "SUB  R4=R1-R2");
            check_equal(REG(5),  32'd15,       "MUL  R5=R1*R2");
            check_equal(REG(6),  32'd1,        "AND  R6=R1&R2");
            check_equal(REG(7),  32'd7,        "OR   R7=R1|R2");
            check_equal(REG(8),  32'd6,        "XOR  R8=R1^R2");
            check_equal(REG(9),  32'hFFFFFFFA, "NOT  R9=~R1");
            check_equal(REG(11), 32'd20,       "SHL  R11=R1<<2");
            check_equal(REG(12), 32'd1,        "SHR  R12=R1>>2");
            check_equal(REG(13), 32'hFFFFFFFE, "SAR  R13=R9>>>2");
            check_equal(REG(14), 32'd15,       "ADDI R14=R1+10");
            check_equal(REG(15), 32'd2,        "SUBI R15=R1-3");
        end
 
        // ---- TEST 3: Immediate logic ----
        $display("\n=== TEST 3: Immediate Logic (ANDI/ORI/XORI) ===");
        load_test3_imm_logic;
        do_reset;
        wait_for_halt(100, timed_out);
        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            check_equal(REG(2), 32'h00000003, "ANDI R2=R1&0x003");
            check_equal(REG(3), 32'h0000003F, "ORI  R3=R1|0x030");
            check_equal(REG(4), 32'h000000F0, "XORI R4=R1^0x0FF");
        end
 
        // ---- TEST 4: Control flow ----
        $display("\n=== TEST 4: Control Flow (CMP/EQ/BEQ/BNE/BLT/BGE/JMP/JMP_IF) ===");
        load_test4_control_flow;
        do_reset;
        wait_for_halt(1000, timed_out);
        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            check_equal(REG(3),  32'd1, "BEQ took correct branch");
            check_equal(REG(5),  32'd1, "BNE took correct branch");
            check_equal(REG(6),  32'd1, "BLT took correct branch");
            check_equal(REG(7),  32'd1, "BGE took correct branch");
            check_equal(REG(11), 32'd1, "JMP_IF not taken (cond=0) fell through");
            check_equal(REG(12), 32'd1, "JMP_IF taken (cond!=0)");
            check_equal(REG(13), 32'd1, "JMP unconditional");
            check_equal(REG(14), 32'd1, "EQ R1==R2 -> 1");
            check_equal(REG(15), 32'd0, "EQ R1==R4 -> 0");
            check_equal(REG(9),  32'd0, "sentinel: no wrong branch taken");
        end
        
 
        // ---- TEST 5: Memory addressing ----
        $display("\n=== TEST 5: Memory Addressing (LOAD direct / STORE_IND) ===");
        load_test5_mem_addressing;
        do_reset;
        wait_for_halt(300, timed_out);
        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            #2000; // let the CDC FIFOs / slow memory write settle
            check_equal(REG(2), 32'd5, "LOAD R2 <- mem[0x104]");
            check_equal(dut.dmem.ram[14'h0210], 32'd7, "STORE_IND mem[0x210] <- R3");
        end
 

        // ---- TEST 6: Slow-memory read address sequencing ----
        $display("\n=== TEST 6: Slow-Memory Read Address Sequencing ===");

        // Distinct values make address/order errors visible. These are word
        // addresses: 0x100, 0x101, 0x102, and 0x103 are one cache line.
        dut.dmem.ram[14'h0100] = 32'hA1000001;
        dut.dmem.ram[14'h0101] = 32'hB2000002;
        dut.dmem.ram[14'h0102] = 32'hC3000003;
        dut.dmem.ram[14'h0103] = 32'hD4000004;

        load_test6_read_address_sequence;
        do_reset;
        wait_for_halt(500, timed_out);

        if (timed_out) begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end else begin
            check_equal(REG(1), 32'hA1000001, "read burst word 0 from aligned base 0x100");
            check_equal(REG(2), 32'hB2000002, "read burst word 1 from address 0x101");
            check_equal(REG(3), 32'hC3000003, "read burst word 2 from address 0x102");
            check_equal(REG(4), 32'hD4000004, "read burst word 3 from address 0x103");
        end

        // ---- Summary ----
        $display("\n========================================");
        $display("TOTAL: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        $finish;
    end
 
    // Global safety net in case something hangs outside wait_for_halt's reach.
    initial begin
        #2000000;
        $display("========================================");
        $display("GLOBAL TIMEOUT: simulation did not complete in time");
        $display("========================================");
        $finish;
    end
 
endmodule
