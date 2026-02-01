module risc_processor (
    input logic clk,
    input logic reset
);

    // ========================================================================
    // Pipeline Registers
    // ========================================================================
    
    // IF/ID Pipeline Register
    logic [31:0] IFID_instr, IFID_pc;
    logic IFID_valid;
    
    // ID/EX Pipeline Register
    logic [31:0] IDEX_pc, IDEX_rs_data, IDEX_rt_data, IDEX_rp_data, IDEX_rd_data;
    logic [31:0] IDEX_imm;
    logic [4:0] IDEX_rd, IDEX_opcode, IDEX_rs, IDEX_rt, IDEX_rp;
    logic IDEX_reg_write, IDEX_mem_read, IDEX_mem_write, IDEX_mem_to_reg;
    logic [3:0] IDEX_alu_op;
    logic IDEX_alu_src, IDEX_is_jump, IDEX_is_call, IDEX_is_jr;
    logic IDEX_is_halt;
    logic IDEX_valid;
    
    // EX/MEM Pipeline Register
    logic [31:0] EXMEM_alu_result, EXMEM_write_data, EXMEM_pc;
    logic [4:0] EXMEM_rd;
    logic EXMEM_reg_write, EXMEM_mem_read, EXMEM_mem_write, EXMEM_mem_to_reg;
    logic EXMEM_predicate_pass;
    logic EXMEM_is_halt;
    logic EXMEM_valid;
    
    // MEM/WB Pipeline Register
    logic [31:0] MEMWB_alu_result, MEMWB_mem_data;
    logic [4:0] MEMWB_rd;
    logic MEMWB_reg_write, MEMWB_mem_to_reg;
    logic MEMWB_is_halt;
    logic MEMWB_valid;
    
    // ========================================================================
    // Processor State
    // ========================================================================
    logic [31:0] pc;
    logic [31:0] registers [0:31];
    (* ram_style = "block" *) logic [31:0] inst_memory [0:1023];
    (* ram_style = "block" *) logic [31:0] data_memory [0:1023];
    
    logic halted;
    
    // ========================================================================
    // Instruction Memory Initialization
    // ========================================================================
    initial begin
        $readmemh("program.hex", inst_memory);
    end

    // Control Signals
    logic stall;
    logic flush; 
    logic take_branch;
    logic [31:0] branch_target;

    // ========================================================================
    // Stage 1: Instruction Fetch (IF)
    // ========================================================================
    logic [31:0] if_instr, if_pc;
    
    always_comb begin
        if_pc = pc;
        if_instr = (pc < 1024) ? inst_memory[pc] : 32'h0;
    end
    
    // ========================================================================
    // Stage 2: Instruction Decode (ID)
    // ========================================================================
    logic [4:0] id_opcode, id_rp, id_rd, id_rs, id_rt;
    logic [31:0] id_imm, id_offset;
    logic [31:0] id_rs_data, id_rt_data, id_rp_data, id_rd_data;
    
    // Decode instruction fields (MATCHES SPEC EXACTLY)
    always_comb begin
        id_opcode = IFID_instr[31:27]; // opcode
        id_rp     = IFID_instr[26:22]; // predicate register
        id_rd     = IFID_instr[21:17]; // destination register
        id_rs     = IFID_instr[16:12]; // source register 1
        id_rt     = IFID_instr[11:7];  // source register 2

        // Immediate (12-bit)
        if (id_opcode == 5'd6 || id_opcode == 5'd7 || id_opcode == 5'd8) begin
            // ORI / NORI / ANDI → zero-extend
            id_imm = {20'b0, IFID_instr[11:0]};
        end else begin
            // ADDI / LW / SW / J / CALL → sign-extend
            id_imm = {{20{IFID_instr[11]}}, IFID_instr[11:0]};
        end

        // Jump / CALL offset (signed)
        id_offset = {{20{IFID_instr[11]}}, IFID_instr[11:0]};
    end
    
    // Register file read with Forwarding Logic
    logic [31:0] id_rs_forward, id_rt_forward, id_rp_forward, id_rd_forward;
    
    always_comb begin
        // 1. Read from Register File
        id_rs_forward = registers[id_rs];
        id_rt_forward = registers[id_rt];
        id_rp_forward = registers[id_rp];
        id_rd_forward = registers[id_rd];
        
        // 2. Forward from EX/MEM stage (highest priority - most recent)
        if (EXMEM_reg_write && EXMEM_valid && EXMEM_predicate_pass && EXMEM_rd != 0) begin
            // For loads, forward the memory data; for others, forward ALU result
            logic [31:0] exmem_forward_data;
            if (EXMEM_mem_read)
                exmem_forward_data = data_memory[EXMEM_alu_result];
            else
                exmem_forward_data = EXMEM_alu_result;
            
            if (EXMEM_rd == id_rs) id_rs_forward = exmem_forward_data;
            if (EXMEM_rd == id_rt) id_rt_forward = exmem_forward_data;
            if (EXMEM_rd == id_rp) id_rp_forward = exmem_forward_data;
            if (EXMEM_rd == id_rd) id_rd_forward = exmem_forward_data;
        end
        
        // 3. Forward from MEM/WB stage (lower priority)
        if (MEMWB_reg_write && MEMWB_valid && MEMWB_rd != 0) begin
            if (MEMWB_rd == id_rs && !(EXMEM_reg_write && EXMEM_valid && EXMEM_predicate_pass && EXMEM_rd == id_rs))
                id_rs_forward = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
            if (MEMWB_rd == id_rt && !(EXMEM_reg_write && EXMEM_valid && EXMEM_predicate_pass && EXMEM_rd == id_rt))
                id_rt_forward = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
            if (MEMWB_rd == id_rp && !(EXMEM_reg_write && EXMEM_valid && EXMEM_predicate_pass && EXMEM_rd == id_rp))
                id_rp_forward = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
            if (MEMWB_rd == id_rd && !(EXMEM_reg_write && EXMEM_valid && EXMEM_predicate_pass && EXMEM_rd == id_rd))
                id_rd_forward = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
        end
        
        // Final assignment
        id_rs_data = id_rs_forward;
        id_rt_data = id_rt_forward;
        id_rp_data = id_rp_forward;
        id_rd_data = id_rd_forward;
    end
    
    // Control signal generation
    logic id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    logic [3:0] id_alu_op;
    logic id_alu_src, id_is_jump, id_is_call, id_is_jr;
    logic id_is_halt;
    
    always_comb begin
        // Defaults
        id_reg_write = 0; id_mem_read = 0; id_mem_write = 0; id_mem_to_reg = 0;
        id_alu_op = 4'd0; id_alu_src = 0;
        id_is_jump = 0; id_is_call = 0; id_is_jr = 0;
        id_is_halt = 0;
        
        case (id_opcode)
            5'd0: begin id_reg_write = 1; id_alu_op = 4'd0; end // ADD
            5'd1: begin id_reg_write = 1; id_alu_op = 4'd1; end // SUB
            5'd2: begin id_reg_write = 1; id_alu_op = 4'd2; end // OR
            5'd3: begin id_reg_write = 1; id_alu_op = 4'd3; end // NOR
            5'd4: begin id_reg_write = 1; id_alu_op = 4'd4; end // AND
            5'd5: begin id_reg_write = 1; id_alu_op = 4'd0; id_alu_src = 1; end // ADDI
            5'd6: begin id_reg_write = 1; id_alu_op = 4'd2; id_alu_src = 1; end // ORI
            5'd7: begin id_reg_write = 1; id_alu_op = 4'd3; id_alu_src = 1; end // NORI
            5'd8: begin id_reg_write = 1; id_alu_op = 4'd4; id_alu_src = 1; end // ANDI (CORRECTED)
            5'd9: begin // LW (CORRECTED)
                id_reg_write = 1; id_mem_read = 1; id_mem_to_reg = 1;
                id_alu_op = 4'd0; id_alu_src = 1;
            end
            5'd10: begin // SW (CORRECTED)
                id_mem_write = 1; id_alu_op = 4'd0; id_alu_src = 1;
            end
            5'd11: id_is_jump = 1; // J (CORRECTED)
            5'd12: begin id_is_call = 1; id_reg_write = 1; end // CALL (CORRECTED)
            5'd13: id_is_jr = 1; // JR (CORRECTED)
            5'd14: id_is_halt = 1; // HALT (CORRECTED)
            default: ; // NOP
        endcase
    end
    
    // Hazard detection - Stall for register dependencies
    always_comb begin
        stall = 0;
        
        // Priority 1: Always stall for load-use hazards (need extra cycle for memory)
        if (IDEX_mem_read && IDEX_valid && IDEX_rd != 0) begin
            if ((IDEX_rd == id_rs && id_rs != 0) || 
                (IDEX_rd == id_rt && id_rt != 0) || 
                (IDEX_rd == id_rd && id_rd != 0) ||
                (IDEX_rd == id_rp && id_rp != 0))
                stall = 1;
        end
        
        // Priority 2: Stall for other register write dependencies (can forward from EX/MEM)
        else if (IDEX_reg_write && IDEX_valid && IDEX_rd != 0) begin
            if ((IDEX_rd == id_rs && id_rs != 0) || 
                (IDEX_rd == id_rt && id_rt != 0) || 
                (IDEX_rd == id_rd && id_rd != 0) ||
                (IDEX_rd == id_rp && id_rp != 0))
                stall = 1;
        end
    end
    
    // ========================================================================
    // Stage 3: Execute (EX)
    // ========================================================================
    logic [31:0] ex_alu_in1, ex_alu_in2, ex_alu_result;
    logic ex_predicate_pass;
    
    always_comb begin
        ex_alu_in1 = IDEX_rs_data;
        ex_alu_in2 = IDEX_alu_src ? IDEX_imm : IDEX_rt_data;
        
        // ALU operation
        case (IDEX_alu_op)
            4'd0: ex_alu_result = ex_alu_in1 + ex_alu_in2; // ADD
            4'd1: ex_alu_result = ex_alu_in1 - ex_alu_in2; // SUB
            4'd2: ex_alu_result = ex_alu_in1 | ex_alu_in2; // OR
            4'd3: ex_alu_result = ~(ex_alu_in1 | ex_alu_in2); // NOR
            4'd4: ex_alu_result = ex_alu_in1 & ex_alu_in2; // AND
            default: ex_alu_result = 0;
        endcase
        
        // Predication Logic: R0 predicate means always execute
        if (IDEX_rp == 5'd0)
            ex_predicate_pass = 1;
        else
            ex_predicate_pass = (IDEX_rp_data != 0);
    end
    
    // Branch Logic
    always_comb begin
        take_branch = 0;
        branch_target = 0;
        flush = 0;
        
        if (IDEX_valid && ex_predicate_pass) begin
            if (IDEX_is_jump || IDEX_is_call) begin
                branch_target = IDEX_pc + IDEX_imm; 
                take_branch = 1;
                flush = 1;
            end else if (IDEX_is_jr) begin
                branch_target = IDEX_rs_data; 
                take_branch = 1;
                flush = 1;
            end
        end
    end
    
    // ========================================================================
    // Stage 4: Memory Access (MEM)
    // ========================================================================
    logic [31:0] mem_read_data;
    
    always_comb begin
        mem_read_data = 0;
        if (EXMEM_mem_read && EXMEM_predicate_pass && EXMEM_valid)
            mem_read_data = data_memory[EXMEM_alu_result];
    end
    
    // ========================================================================
    // Stage 5: Write Back (WB)
    // ========================================================================
    logic [31:0] wb_write_data;
    
    always_comb begin
        wb_write_data = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
    end
    
    // Sequential Logic - Pipeline Operation
    // ========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all pipeline stages
            halted <= 0;
            IFID_valid <= 0;
            IFID_instr <= 0;
            IFID_pc <= 0;
            IDEX_valid <= 0;
            EXMEM_valid <= 0;
            MEMWB_valid <= 0;
            pc <= 0;

            // Initialize registers
            for (int i = 0; i < 32; i++) registers[i] <= 0;
            for (int i = 0; i < 1024; i++) data_memory[i] <= 0;

        end else if (!halted) begin
            // ----------------------------------------------------------------
            // WB Stage - Register Writeback
            // ----------------------------------------------------------------
            if (MEMWB_valid && MEMWB_reg_write && MEMWB_rd != 0 && MEMWB_rd != 30) begin
                registers[MEMWB_rd] <= wb_write_data;
            end

            // Check for HALT at WB stage
            if (MEMWB_valid && MEMWB_is_halt) begin
                halted <= 1;
            end

            // Hardwired registers (always enforced)
            registers[0]  <= 32'h0;   // R0 = 0
            registers[30] <= pc;      // R30 = current PC

            // ----------------------------------------------------------------
            // MEM Stage - Memory Write
            // ----------------------------------------------------------------
            if (EXMEM_mem_write && EXMEM_predicate_pass && EXMEM_valid) begin
                data_memory[EXMEM_alu_result] <= EXMEM_write_data;
            end
            
            // Pipeline Update: MEM -> WB
            MEMWB_alu_result <= EXMEM_alu_result;
            MEMWB_mem_data   <= mem_read_data;
            MEMWB_rd         <= EXMEM_rd;
            MEMWB_reg_write  <= EXMEM_reg_write && EXMEM_predicate_pass;
            MEMWB_mem_to_reg <= EXMEM_mem_to_reg;
            MEMWB_is_halt    <= EXMEM_is_halt;
            MEMWB_valid      <= EXMEM_valid;
            
            // ----------------------------------------------------------------
            // EX Stage - ALU and Branch Resolution
            // ----------------------------------------------------------------
            // Pipeline Update: EX -> MEM
            EXMEM_alu_result     <= ex_alu_result;
            EXMEM_write_data     <= IDEX_rd_data; // For SW: use Rd data
            EXMEM_pc             <= IDEX_pc;
            EXMEM_rd             <= IDEX_is_call ? 5'd31 : IDEX_rd;
            EXMEM_reg_write      <= IDEX_reg_write;
            EXMEM_mem_read       <= IDEX_mem_read;
            EXMEM_mem_write      <= IDEX_mem_write;
            EXMEM_mem_to_reg     <= IDEX_mem_to_reg;
            EXMEM_predicate_pass <= ex_predicate_pass;
            EXMEM_is_halt        <= IDEX_is_halt;
            EXMEM_valid          <= IDEX_valid;
            
            // Handle CALL return address (PC+1)
            if (IDEX_is_call && ex_predicate_pass && IDEX_valid) begin
                EXMEM_alu_result <= IDEX_pc + 1;
            end
            
            // ----------------------------------------------------------------
            // ID Stage - Decode and Register Read
            // ----------------------------------------------------------------
            if (flush) begin
                // Flush IF/ID stage on branch
                IDEX_valid <= 0;
            end else if (stall) begin
                // Insert bubble on load-use hazard
                IDEX_valid <= 0;
            end else begin
                // Normal Operation: ID -> EX
                IDEX_pc          <= IFID_pc;
                IDEX_rs_data     <= id_rs_data;
                IDEX_rt_data     <= id_rt_data;
                IDEX_rp_data     <= id_rp_data;
                IDEX_rd_data     <= id_rd_data;
                IDEX_imm         <= id_imm;
                IDEX_rd          <= id_rd;
                IDEX_opcode      <= id_opcode;
                IDEX_rs          <= id_rs;
                IDEX_rt          <= id_rt;
                IDEX_rp          <= id_rp;
                IDEX_reg_write   <= id_reg_write;
                IDEX_mem_read    <= id_mem_read;
                IDEX_mem_write   <= id_mem_write;
                IDEX_mem_to_reg  <= id_mem_to_reg;
                IDEX_alu_op      <= id_alu_op;
                IDEX_alu_src     <= id_alu_src;
                IDEX_is_jump     <= id_is_jump;
                IDEX_is_call     <= id_is_call;
                IDEX_is_jr       <= id_is_jr;
                IDEX_is_halt     <= id_is_halt;
                IDEX_valid       <= IFID_valid;
            end

            // ----------------------------------------------------------------
            // IF Stage - Instruction Fetch and PC Update
            // ----------------------------------------------------------------
            if (take_branch) begin
                // Branch taken: update PC and flush IF/ID
                pc <= branch_target;
                IFID_valid <= 0;
            end else if (stall) begin
                // Stall: keep PC and IF/ID register unchanged
                // Don't increment PC, keep fetching same instruction
            end else begin
                // Normal operation: fetch next instruction
                pc <= pc + 1;
                IFID_instr <= if_instr;
                IFID_pc <= if_pc;
                IFID_valid <= 1;
            end
        end
        // When halted, all pipeline registers retain their values (no updates)
    end

endmodule