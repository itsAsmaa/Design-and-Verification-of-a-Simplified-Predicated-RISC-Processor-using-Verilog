`timescale 1ns/1ps

module testbench;

    // ============================================================
    // Clock & Reset
    // ============================================================
    logic clk;
    logic reset;

    always #5 clk = ~clk;   // 100 MHz

    // ============================================================
    // DUT
    // ============================================================
    risc_processor dut (
        .clk(clk),
        .reset(reset)
    );

    // ============================================================
    // Reset sequence
    // ============================================================
    initial begin
        clk   = 0;
        reset = 1;
        #20;
        reset = 0;
    end

    // ============================================================
    // WAVEFORM DUMP 
    // ============================================================
    initial begin
        $dumpfile("waveform.vcd");

        // start dumping shortly after reset
        #10;

        // ====== CLOCK & CONTROL ======
        $dumpvars(0, clk);
        $dumpvars(0, reset);
        $dumpvars(0, dut.halted);

        // ====== FETCH STAGE ======
        $dumpvars(0, dut.pc);
        $dumpvars(0, dut.if_instr);
        $dumpvars(0, dut.IFID_instr);
        $dumpvars(0, dut.IFID_valid);

        // ====== DECODE / EXECUTE PIPE ======
        $dumpvars(0, dut.IDEX_valid);
        $dumpvars(0, dut.IDEX_rd);
        $dumpvars(0, dut.IDEX_rs);
        $dumpvars(0, dut.IDEX_rt);
        $dumpvars(0, dut.IDEX_rp);

        // ====== EXECUTE / MEMORY PIPE ======
        $dumpvars(0, dut.EXMEM_valid);
        $dumpvars(0, dut.EXMEM_rd);
        $dumpvars(0, dut.EXMEM_alu_result);
        $dumpvars(0, dut.EXMEM_mem_read);
        $dumpvars(0, dut.EXMEM_mem_write);

        // ====== MEMORY / WRITEBACK PIPE ======
        $dumpvars(0, dut.MEMWB_valid);
        $dumpvars(0, dut.MEMWB_rd);
        $dumpvars(0, dut.MEMWB_alu_result);
        $dumpvars(0, dut.MEMWB_mem_to_reg);

        // ====== HAZARD / CONTROL ======
        $dumpvars(0, dut.stall);
        $dumpvars(0, dut.flush);
        $dumpvars(0, dut.take_branch);
    end

    // ============================================================
    // STOP SIMULATION 
    // ============================================================
    int cycle;

    initial begin
        cycle = 0;

        forever begin
            @(posedge clk);
            cycle++;

            // stop after HALT + drain
            if (dut.halted && cycle > 20) begin
                $display("CPU halted, stopping simulation.");
                $finish;
            end

            // safety stop
            if (cycle == 50) begin
                $display("Max cycles reached.");
                $finish;
            end
        end
    end

endmodule
