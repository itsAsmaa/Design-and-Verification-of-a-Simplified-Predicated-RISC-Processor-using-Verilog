# Predicated RISC Processor

A 32-bit pipelined RISC processor with predicated execution support, implemented in SystemVerilog.

## 📋 Overview

This project implements a complete 5-stage pipelined RISC processor featuring:

- **32-bit architecture** with 32 general-purpose registers
- **Predicated execution** for conditional instruction execution
- **Hardware forwarding** for data hazard mitigation
- **Comprehensive instruction set** covering arithmetic, logical, memory, and control flow operations
- **Full pipeline hazard handling** including detection, forwarding, and stalling

## 🏗️ Architecture

### Pipeline Stages

1. **IF (Instruction Fetch)** - Fetch instruction from instruction memory
2. **ID (Instruction Decode)** - Decode instruction and read registers
3. **EX (Execute)** - Perform ALU operations and predicate evaluation
4. **MEM (Memory Access)** - Access data memory for load/store operations
5. **WB (Write Back)** - Write results back to register file

### Register File

- **R0**: Hardwired to zero (constant 0)
- **R1-R29**: General-purpose registers
- **R30**: Program Counter (PC)
- **R31**: Return address register (for CALL instruction)

### Memory Organization

- **Instruction Memory**: 1024 words × 32 bits (word-addressable)
- **Data Memory**: 1024 words × 32 bits (word-addressable)

## 📝 Instruction Set Architecture (ISA)

### Instruction Formats

#### R-Type (Register Type)
```
[31:27]  [26:22]  [21:17]  [16:12]  [11:7]   [6:0]
Opcode   Rp       Rd       Rs       Rt       Unused
```

#### I-Type (Immediate Type)
```
[31:27]  [26:22]  [21:17]  [16:12]  [11:0]
Opcode   Rp       Rd       Rs       Immediate
```

#### J-Type (Jump Type)
```
[31:27]  [26:22]  [21:0]
Opcode   Rp       Offset
```

### Supported Instructions

| Instruction | Type | Opcode | Description |
|------------|------|--------|-------------|
| ADD | R | 0 | Rd = Rs + Rt (if Rp ≠ 0) |
| SUB | R | 1 | Rd = Rs - Rt (if Rp ≠ 0) |
| OR | R | 2 | Rd = Rs \| Rt (if Rp ≠ 0) |
| NOR | R | 3 | Rd = ~(Rs \| Rt) (if Rp ≠ 0) |
| AND | R | 4 | Rd = Rs & Rt (if Rp ≠ 0) |
| ADDI | I | 5 | Rd = Rs + SignExt(Imm) (if Rp ≠ 0) |
| ORI | I | 6 | Rd = Rs \| ZeroExt(Imm) (if Rp ≠ 0) |
| NORI | I | 7 | Rd = ~(Rs \| ZeroExt(Imm)) (if Rp ≠ 0) |
| ANDI | I | 8 | Rd = Rs & ZeroExt(Imm) (if Rp ≠ 0) |
| LW | I | 9 | Rd = Mem[Rs + SignExt(Imm)] (if Rp ≠ 0) |
| SW | I | 10 | Mem[Rs + SignExt(Imm)] = Rd (if Rp ≠ 0) |
| J | J | 11 | PC = PC + SignExt(Offset) (if Rp ≠ 0) |
| CALL | J | 12 | R31 = PC+1, PC = PC + SignExt(Offset) (if Rp ≠ 0) |
| JR | R | 13 | PC = Rs (if Rp ≠ 0) |

## 🎯 Predicated Execution

Every instruction includes a predicate register field (Rp):

- **Rp = R0**: Instruction executes unconditionally
- **Rp ≠ R0 and Rp content = 0**: Instruction is nullified (no operation)
- **Rp ≠ R0 and Rp content ≠ 0**: Instruction executes normally

This mechanism allows for conditional execution without branches, reducing pipeline stalls.

## 🔧 Hazard Handling

### Data Hazards

**Forwarding (Data Bypassing)**
- Full forwarding from EX/MEM and MEM/WB stages
- Priority-based selection (EX/MEM has highest priority)
- Supports forwarding for Rs, Rt, Rp, and Rd registers

**Load-Use Hazard Detection**
- Automatic detection when instruction depends on load data
- Mandatory 1-cycle pipeline stall
- Ensures memory data availability before use

### Control Hazards

**Branch/Jump Handling**
- Branch resolution in EX stage
- Pipeline flush for IF/ID and ID/EX stages
- 2-cycle branch penalty
- Predicate evaluation before branch decision

## 📁 Project Structure

```
project/
├── rtl/
│   └── design.sv                          # Main processor RTL
├── testbench/
│   ├── testbench.sv                       # Comprehensive testbench
│   └── waveform_testbench.sv              # Single-test waveform generation
├── test_programs/
│   ├── test_call.hex                      # CALL/JR instruction test
│   ├── test_consecutive_hazards.hex       # RAW hazard forwarding test
│   ├── test_jump.hex                      # Jump instruction test
│   ├── test_load_use_hazard.hex           # Load-use hazard test
│   ├── test_logical_rtype.hex             # Logical operations test
│   ├── test_memory_offset.hex             # Memory offset addressing test
│   └── test_predicated_memory.hex         # Predicated execution test
└── docs/
    └── ENCS4370_project2_report.pdf       # Complete design report
```

## 🚀 Getting Started

### Prerequisites

- SystemVerilog simulator (ModelSim, Vivado, or EDA Playground)
- Basic understanding of computer architecture and Verilog

### Running Simulations

1. **Prepare test program**: Copy one of the test hex files to `program.hex`
   ```bash
   cp test_programs/test_logical_rtype.hex program.hex
   ```

2. **Run simulation**: Load `design.sv` and `testbench.sv` in your simulator

3. **View results**: Check simulation output for register and memory values

### Example Test Program

```assembly
ADDI R1, R0, 0xAA, R0    // R1 = 170
ADDI R2, R0, 0x55, R0    // R2 = 85
OR   R3, R1, R2, R0      // R3 = 255
AND  R4, R1, R2, R0      // R4 = 0
NOR  R5, R1, R2, R0      // R5 = 0xFFFFFF00
HALT
```

## ✅ Verification

The processor has been verified with 7 comprehensive test programs covering:

- ✓ Arithmetic and logical operations
- ✓ Load-use hazard detection and stalling
- ✓ Memory operations with offset addressing
- ✓ Jump and branch instructions
- ✓ Function calls and returns (CALL/JR)
- ✓ Predicated execution
- ✓ Consecutive data hazards with forwarding

All tests pass with correct register and memory values.

## 📊 Performance Metrics

| Test Case | Instructions | Cycles | Stalls | CPI |
|-----------|-------------|--------|--------|-----|
| Arithmetic/Logical | 6 | 10 | 1 | 1.67 |
| Load-Use Hazard | 6 | 11 | 2 | 1.83 |
| Memory Offset | 8 | 11 | 0 | 1.38 |
| Jump Instruction | 6 | 9 | 0 | 1.50 |
| CALL/JR | 6 | 13 | 0 | 2.17 |
| Predicated Execution | 8 | 13 | 2 | 1.63 |
| Consecutive Hazards | 6 | 13 | 4 | 2.17 |

## 🎓 Design Decisions

### Pipeline Architecture
Standard 5-stage RISC design balancing complexity and performance. Allows multiple instructions in flight while keeping control logic manageable.

### Forwarding Implementation
Full forwarding with priority-based selection minimizes stalls for most data hazards. EX/MEM has priority as it contains the most recent data.

### Load-Use Hazard
Mandatory 1-cycle stall as memory data is not available until MEM stage, making forwarding impossible. Stalling is simpler than advanced scheduling.

### Branch Resolution
Resolved in EX stage to allow predicate evaluation before branch decision. Accepts 2-cycle penalty for simpler control logic.

### Word Addressing
PC increments by 1, not 4. Each address points to one 32-bit word, simplifying addressing logic.

## 🤝 Contributors

**Group Members:**
- **Asma'a Abdalrahman Fares** (1210084) - Datapath design, ALU, register file
- **Aya Abdalrahman Fares** (1222654) - Control unit, hazard detection, predication logic
- **Baker Mustafa Shalabi** (1231050) - Testbench development, verification

**Instructor:** Dr. Ahmad Afaneh  
**Course:** ENCS4370 - Computer Architecture  
**Institution:** Faculty of Engineering and Technology, Electrical and Computer Engineering Department

## 📄 License

This project was developed as part of an academic course at Birzeit University.

## 🔗 References

- Patterson & Hennessy, *Computer Organization and Design*
- Harris & Harris, *Digital Design and Computer Architecture*
- Course materials from ENCS4370

## 📧 Contact

For questions or issues, please contact the project team members or course instructor.
