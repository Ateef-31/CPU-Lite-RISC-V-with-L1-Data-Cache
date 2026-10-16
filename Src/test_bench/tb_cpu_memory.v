`timescale 1ns / 1ps

module tb_cpu_memory();

    localparam VERBOSE_TRACE = 1;

    reg clk_150;
    reg clk_70;
    reg rst_fast_n;
    reg rst_slow_n;
    reg timed_out;

    integer pass_count = 0;
    integer fail_count = 0;

    initial begin
        clk_150 = 1'b0;
        forever #3.33 clk_150 = ~clk_150;
    end

    initial begin
        clk_70 = 1'b0;
        forever #7.14 clk_70 = ~clk_70;
    end

    CPU_LITE_TOP dut (
        .clk_fast(clk_150),
        .clk_slow(clk_70),
        .rst_fast_n(rst_fast_n),
        .rst_slow_n(rst_slow_n)
    );

    reg halt_detected;
    always @(posedge clk_150 or negedge rst_fast_n) begin
        if (!rst_fast_n)
            halt_detected <= 1'b0;
        else if (dut.core.opcode == 8'hFF && !halt_detected)
            halt_detected <= 1'b1;
    end

    integer lat_cnt;
    integer lat_n;
    integer lat_log [0:15];

        always @(posedge clk_150) begin
        if (!rst_fast_n) begin
            lat_cnt = 0;
            lat_n   = 0;
        end else if (dut.core.cache_ready) begin
            lat_log[lat_n] = lat_cnt;
            lat_n   = lat_n + 1;
            lat_cnt = 0;
        end else if (dut.core.cache_req) begin
            lat_cnt = lat_cnt + 1;
        end
    end

    always @(posedge clk_150) begin
        if (VERBOSE_TRACE && rst_fast_n) begin
            $display(
                "T=%0t STATE=%0d PC=%03h INSTR=%08h OPCODE=%02h R1=%08h R2=%08h R3=%08h R4=%08h R5=%08h CACHE_REQ=%b CACHE_READY=%b",
                $time,
                dut.core.state,
                dut.core.pc_out,
                dut.core.instruction,
                dut.core.opcode,
                dut.core.rf_inst.registers[1],
                dut.core.rf_inst.registers[2],
                dut.core.rf_inst.registers[3],
                dut.core.rf_inst.registers[4],
                dut.core.rf_inst.registers[5],
                dut.core.cache_req,
                dut.core.cache_ready
            );
        end
    end

    task write_instr(input integer addr, input [31:0] val);
        begin
            dut.imem.program_memory[addr] = val;
        end
    endtask

    task clear_program_mem;
        integer k;
        begin
            for (k = 0; k < 4096; k = k + 1)
                dut.imem.program_memory[k] = 32'hFF000000;
        end
    endtask

    task do_reset;
        begin
            rst_fast_n = 1'b0;
            rst_slow_n = 1'b0;
            #50;
            rst_fast_n = 1'b1;
            rst_slow_n = 1'b1;
        end
    endtask

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

    task report_timeout;
        begin
            fail_count = fail_count + 1;
            $display("  [FAIL] TIMEOUT waiting for HALT");
        end
    endtask

    function [31:0] REG(input integer n);
        REG = dut.core.rf_inst.registers[n];
    endfunction

    task load_test1_load_miss;
        begin
            clear_program_mem;
            write_instr(0, 32'h01100100);
            write_instr(1, 32'hFF000000);
        end
    endtask

    task load_test2_load_hit;
        begin
            clear_program_mem;
            write_instr(0, 32'h01100100);
            write_instr(1, 32'h01200101);
            write_instr(2, 32'h01300100);
            write_instr(3, 32'h01400103);
            write_instr(4, 32'hFF000000);
        end
    endtask

    task load_test3_store_hit;
        begin
            clear_program_mem;
            write_instr(0, 32'h01100100);
            write_instr(1, 32'h035000AB);
            write_instr(2, 32'h04500100);
            write_instr(3, 32'h01200100);
            write_instr(4, 32'h01300101);
            write_instr(5, 32'hFF000000);
        end
    endtask

    task load_test4_store_miss;
        begin
            clear_program_mem;
            write_instr(0, 32'h035000CD);
            write_instr(1, 32'h04500310);
            write_instr(2, 32'h01200310);
            write_instr(3, 32'h01300311);
            write_instr(4, 32'hFF000000);
        end
    endtask

    initial begin
        rst_fast_n = 1'b0;
        rst_slow_n = 1'b0;

        $display("\n=== TEST 1: Load Miss ===");
        dut.dmem.ram[14'h0100] = 32'hA1000001;
        load_test1_load_miss;
        do_reset;
        wait_for_halt(500, timed_out);
        if (timed_out) report_timeout;
        else begin
            check_equal(REG(1), 32'hA1000001, "LOAD miss R1 <- mem[0x100]");
            $display("  miss latency = %0d cycles", lat_log[0]);
        end

        $display("\n=== TEST 2: Load Hit ===");
        dut.dmem.ram[14'h0100] = 32'hA1000001;
        dut.dmem.ram[14'h0101] = 32'hB2000002;
        dut.dmem.ram[14'h0102] = 32'hC3000003;
        dut.dmem.ram[14'h0103] = 32'hD4000004;
        load_test2_load_hit;
        do_reset;
        wait_for_halt(500, timed_out);
        if (timed_out) report_timeout;
        else begin
            check_equal(REG(1), 32'hA1000001, "LOAD miss  R1 <- mem[0x100]");
            check_equal(REG(2), 32'hB2000002, "LOAD hit   R2 <- mem[0x101]");
            check_equal(REG(3), 32'hA1000001, "LOAD hit   R3 <- mem[0x100]");
            check_equal(REG(4), 32'hD4000004, "LOAD hit   R4 <- mem[0x103]");
            $display("  latencies: miss=%0d hit1=%0d hit2=%0d hit3=%0d",
                     lat_log[0], lat_log[1], lat_log[2], lat_log[3]);
            check_equal(lat_log[1] < lat_log[0], 32'd1, "hit latency < miss latency");
        end

        $display("\n=== TEST 3: Store Hit ===");
        dut.dmem.ram[14'h0100] = 32'hA1000001;
        dut.dmem.ram[14'h0101] = 32'hB2000002;
        dut.dmem.ram[14'h0102] = 32'hC3000003;
        dut.dmem.ram[14'h0103] = 32'hD4000004;
        load_test3_store_hit;
        do_reset;
        wait_for_halt(500, timed_out);
        if (timed_out) report_timeout;
        else begin
            #2000;
            check_equal(dut.dmem.ram[14'h0100], 32'h000000AB, "STORE hit write-through mem[0x100]");
            check_equal(REG(2), 32'h000000AB, "LOAD after STORE hit R2 (cache updated)");
            check_equal(REG(3), 32'hB2000002, "neighbor word 0x101 unchanged");
            check_equal(dut.dmem.ram[14'h0101], 32'hB2000002, "mem[0x101] unchanged");
        end

        $display("\n=== TEST 4: Store Miss ===");
        dut.dmem.ram[14'h0310] = 32'h11111111;
        dut.dmem.ram[14'h0311] = 32'h22222222;
        load_test4_store_miss;
        do_reset;
        wait_for_halt(500, timed_out);
        if (timed_out) report_timeout;
        else begin
            #2000;
            check_equal(dut.dmem.ram[14'h0310], 32'h000000CD, "STORE miss write-through mem[0x310]");
            check_equal(REG(2), 32'h000000CD, "LOAD after STORE miss R2");
            check_equal(REG(3), 32'h22222222, "LOAD hit after fill R3 <- mem[0x311]");
            $display("  latencies: store=%0d load_miss=%0d load_hit=%0d",
                     lat_log[0], lat_log[1], lat_log[2]);
            check_equal(lat_log[1] > lat_log[2], 32'd1, "no-allocate: load after store still missed");
        end

        $display("\n========================================");
        $display("TOTAL: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

    initial begin
        #2000000;
        $display("GLOBAL TIMEOUT: simulation did not complete in time");
        $finish;
    end

endmodule
