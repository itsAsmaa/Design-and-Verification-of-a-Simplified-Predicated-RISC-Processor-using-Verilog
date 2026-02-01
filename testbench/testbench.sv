`timescale 1ns / 1ps

module tb_risc_processor;

    // Clock and Reset
    logic clk;
    logic reset;
    
    // Instantiate the processor
    risc_processor dut (
        .clk(clk),
        .reset(reset)
    );
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test control variables
    integer test_num;
    integer cycle_count;
    integer max_cycles;
    string test_name;
    
    // Task to load a test program
    task load_program(input string filename);
        begin
            $display("\n========================================");
            $display("Loading program: %s", filename);
            $display("========================================");
            $readmemh(filename, dut.inst_memory);
        end
    endtask
    
    // Task to reset the processor
    task reset_processor();
        begin
            reset = 1;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
            @(posedge clk);
            cycle_count = 0;
            $display("Processor reset complete at time %0t", $time);
        end
    endtask
    
    // Task to run until halt or timeout
    task run_until_halt(input integer timeout);
        begin
            max_cycles = timeout;
            
            while (!dut.halted && cycle_count < max_cycles) begin
                @(posedge clk);
                cycle_count++;
                
                // Display pipeline state every cycle
                if (cycle_count <= 20 || dut.halted) begin
                    $display("\n--- Cycle %0d (Time: %0t ns) ---", cycle_count, $time);
                    display_pipeline_state();
                end
            end
            
            if (dut.halted) begin
                $display("\n========================================");
                $display("Program halted after %0d cycles", cycle_count);
                $display("========================================");
            end else begin
                $display("\n========================================");
                $display("WARNING: Timeout after %0d cycles!", max_cycles);
                $display("========================================");
            end
        end
    endtask
    
    // Task to display pipeline state
    task display_pipeline_state();
        begin
            $display("PC: %0d | Halted: %0b | Stall: %0b | Flush: %0b", 
                     dut.pc, dut.halted, dut.stall, dut.flush);
            
            // IF Stage
            if (dut.IFID_valid)
                $display("  IF/ID: PC=%0d, Instr=0x%08h", dut.IFID_pc, dut.IFID_instr);
            else
                $display("  IF/ID: [BUBBLE]");
            
            // ID Stage
            if (dut.IDEX_valid) begin
                $display("  ID/EX: PC=%0d, Op=%0d, Rd=R%0d, Rs=R%0d(0x%08h), Rt=R%0d(0x%08h), Rp=R%0d(%0d)", 
                         dut.IDEX_pc, dut.IDEX_opcode, dut.IDEX_rd, 
                         dut.IDEX_rs, dut.IDEX_rs_data, 
                         dut.IDEX_rt, dut.IDEX_rt_data,
                         dut.IDEX_rp, dut.IDEX_rp_data);
            end else
                $display("  ID/EX: [BUBBLE]");
            
            // EX Stage
            if (dut.EXMEM_valid) begin
                $display("  EX/MEM: ALU=0x%08h, Rd=R%0d, MemR=%0b, MemW=%0b, Pred=%0b", 
                         dut.EXMEM_alu_result, dut.EXMEM_rd, 
                         dut.EXMEM_mem_read, dut.EXMEM_mem_write, 
                         dut.EXMEM_predicate_pass);
            end else
                $display("  EX/MEM: [BUBBLE]");
            
            // MEM Stage
            if (dut.MEMWB_valid) begin
                $display("  MEM/WB: ALU=0x%08h, MemData=0x%08h, Rd=R%0d, RegW=%0b", 
                         dut.MEMWB_alu_result, dut.MEMWB_mem_data, 
                         dut.MEMWB_rd, dut.MEMWB_reg_write);
            end else
                $display("  MEM/WB: [BUBBLE]");
        end
    endtask
    
    // Task to display register file contents
    task display_registers();
        integer i;
        begin
            $display("\n========================================");
            $display("Register File Contents:");
            $display("========================================");
            for (i = 0; i < 32; i = i + 4) begin
                $display("R%02d=0x%08h  R%02d=0x%08h  R%02d=0x%08h  R%02d=0x%08h", 
                         i, dut.registers[i], 
                         i+1, dut.registers[i+1], 
                         i+2, dut.registers[i+2], 
                         i+3, dut.registers[i+3]);
            end
            $display("========================================\n");
        end
    endtask
    
    // Task to display specific memory locations
    task display_memory(input integer start_addr, input integer count);
        integer i;
        begin
            $display("\n========================================");
            $display("Data Memory Contents [%0d:%0d]:", start_addr, start_addr + count - 1);
            $display("========================================");
            for (i = 0; i < count; i++) begin
                $display("Mem[%0d] = 0x%08h (%0d)", 
                         start_addr + i, 
                         dut.data_memory[start_addr + i],
                         dut.data_memory[start_addr + i]);
            end
            $display("========================================\n");
        end
    endtask
    
    // Task to check register value
    task check_register(input integer reg_num, input logic [31:0] expected_value, input string msg);
        begin
            if (dut.registers[reg_num] === expected_value) begin
                $display("✓ PASS: %s - R%0d = 0x%08h (expected 0x%08h)", 
                         msg, reg_num, dut.registers[reg_num], expected_value);
            end else begin
                $display("✗ FAIL: %s - R%0d = 0x%08h (expected 0x%08h)", 
                         msg, reg_num, dut.registers[reg_num], expected_value);
            end
        end
    endtask
    
    // Task to check memory value
    task check_memory(input integer addr, input logic [31:0] expected_value, input string msg);
        begin
            if (dut.data_memory[addr] === expected_value) begin
                $display("✓ PASS: %s - Mem[%0d] = 0x%08h (expected 0x%08h)", 
                         msg, addr, dut.data_memory[addr], expected_value);
            end else begin
                $display("✗ FAIL: %s - Mem[%0d] = 0x%08h (expected 0x%08h)", 
                         msg, addr, dut.data_memory[addr], expected_value);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("           RISC PROCESSOR VERIFICATION TESTBENCH");
        $display("================================================================================");
        $display("Start Time: %0t", $time);
        
        // Initialize
        reset = 0;
        test_num = 0;
        
        // ====================================================================
        // TEST 1: Logical R-Type Instructions
        // ====================================================================
        test_num = 1;
        test_name = "Logical R-Type Instructions";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_logical_rtype.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        
        $display("\nExpected Results:");
        check_register(1, 32'h000000AA, "R1 = 0xAA");
        check_register(2, 32'h00000055, "R2 = 0x55");
        check_register(3, 32'h000000FF, "R3 = R1 OR R2");
        check_register(4, 32'h00000000, "R4 = R1 AND R2");
        check_register(5, 32'hFFFFFF00, "R5 = NOR(R1, R2)");
        
        // ====================================================================
        // TEST 2: Load-Use Hazard
        // ====================================================================
        test_num = 2;
        test_name = "Load-Use Hazard Detection";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_load_use_hazard.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        display_memory(10, 1);
        
        $display("\nExpected Results:");
        check_register(1, 32'd10, "R1 = 10 (address)");
        check_register(2, 32'd42, "R2 = 42 (data)");
        check_register(3, 32'd42, "R3 = Mem[10]");
        check_register(4, 32'd50, "R4 = R3 + 8 (tests forwarding)");
        check_memory(10, 32'd42, "Mem[10] stored correctly");
        
        // ====================================================================
        // TEST 3: Memory with Offset Addressing
        // ====================================================================
        test_num = 3;
        test_name = "Memory Offset Addressing";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_memory_offset.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        display_memory(10, 6);
        
        $display("\nExpected Results:");
        check_register(1, 32'd10, "R1 = 10 (base address)");
        check_register(2, 32'd100, "R2 = 100");
        check_register(3, 32'd200, "R3 = 200");
        check_register(4, 32'd100, "R4 = Mem[10]");
        check_register(5, 32'd200, "R5 = Mem[15]");
        check_memory(10, 32'd100, "Mem[10] = 100");
        check_memory(15, 32'd200, "Mem[15] = 200");
        
        // ====================================================================
        // TEST 4: Jump Instruction
        // ====================================================================
        test_num = 4;
        test_name = "Jump Instruction";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_jump.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        
        $display("\nExpected Results:");
        check_register(1, 32'd0, "R1 = 0 (instructions skipped)");
        check_register(2, 32'd20, "R2 = 20 (after jump)");
        
        // ====================================================================
        // TEST 5: CALL and JR (Function Call/Return)
        // ====================================================================
        test_num = 5;
        test_name = "CALL and JR Instructions";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_call.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        
        $display("\nExpected Results:");
        check_register(1, 32'd5, "R1 = 5");
        check_register(31, 32'd2, "R31 = 2 (return address)");
        check_register(3, 32'd50, "R3 = 50 (function executed)");
        check_register(2, 32'd20, "R2 = 20 (returned successfully)");
        
        // ====================================================================
        // TEST 6: Predicated Execution
        // ====================================================================
        test_num = 6;
        test_name = "Predicated Execution";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_predicated_memory.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        display_memory(0, 10);
        
        $display("\nExpected Results:");
        check_register(1, 32'd1, "R1 = 1 (true predicate)");
        check_register(2, 32'd0, "R2 = 0 initially (will be loaded)");
        check_register(4, 32'd50, "R4 = 50 (predicated ADDI executed)");
        $display("Note: SW with R2=0 predicate should NOT execute");
        
        // ====================================================================
        // TEST 7: Consecutive Hazards (Forwarding Test)
        // ====================================================================
        test_num = 7;
        test_name = "Consecutive RAW Hazards";
        $display("\n\n");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        
        load_program("test_consecutive_hazards.hex");
        reset_processor();
        run_until_halt(50);
        display_registers();
        
        $display("\nExpected Results:");
        check_register(1, 32'd5, "R1 = 5");
        check_register(2, 32'd8, "R2 = R1 + 3 = 8");
        check_register(3, 32'd11, "R3 = R2 + 3 = 11");
        check_register(4, 32'd14, "R4 = R3 + 3 = 14");
        check_register(5, 32'd17, "R5 = R4 + 3 = 17");
        
        // ====================================================================
        // Test Summary
        // ====================================================================
        $display("\n\n");
        $display("================================================================================");
        $display("                          TEST SUMMARY");
        $display("================================================================================");
        $display("All tests completed!");
        $display("End Time: %0t", $time);
        $display("================================================================================");
        $display("\n");
        
        // Finish simulation
        #100;
        $finish;
    end
    
    // Waveform dumping for viewing in simulator
    initial begin
        $dumpfile("risc_processor.vcd");
        $dumpvars(0, tb_risc_processor);
    end
    
    // Timeout watchdog
    initial begin
        #1000000; // 1ms timeout
        $display("\n================================================================================");
        $display("ERROR: SIMULATION TIMEOUT!");
        $display("================================================================================\n");
        $finish;
    end

endmodule