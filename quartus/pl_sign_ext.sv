// =============================================================================
// pl_sign_ext.sv
// Extensao de Sinal de Imediatos -- RV32I pipelined (P&H secao 4.4)
//
// Formatos suportados:
//   I-type (lw, addi, ...) : imm[11:0]  = inst[31:20]
//   S-type (sw)  : imm[11:5]  = inst[31:25], imm[4:0] = inst[11:7]
//   B-type (beq) : imm[12]=inst[31], imm[11]=inst[7], imm[10:5]=inst[30:25],
//                  imm[4:1]=inst[11:8], imm[0]=0
//   U-type (lui, auipc) : imm[31:12] = inst[31:12], imm[11:0] = 0
//   J-type (jal)  : imm[20]=inst[31], imm[19:12]=inst[19:12], imm[11]=inst[20],
//                   imm[10:1]=inst[30:21], imm[0]=0
//   jalr usa o formato I (mesmo do lw/addi)
// =============================================================================

`timescale 1ns / 1ps

module pl_sign_ext (
    input  logic [31:0] Instr,
    output logic [31:0] ImmExt
);

    localparam LOAD   = 7'b0000011;
    localparam OP_IMM = 7'b0010011;  // I-type aritmetico/logico (addi, xori, slli...)
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam LUI    = 7'b0110111;  // U-type: load upper immediate
    localparam AUIPC  = 7'b0010111;  // U-type: add upper immediate to PC
    localparam JAL    = 7'b1101111;  // J-type: jump and link
    localparam JALR   = 7'b1100111;  // I-type: jump and link register

    always_comb begin
        case (Instr[6:0])
            LOAD,
            OP_IMM,
            JALR:   ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            STORE:  ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            BRANCH: ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                               Instr[30:25], Instr[11:8], 1'b0};

            LUI,
            AUIPC:  ImmExt = {Instr[31:12], 12'b0};

            JAL:    ImmExt = {{11{Instr[31]}}, Instr[31], Instr[19:12],
                               Instr[20], Instr[30:21], 1'b0};

            default: ImmExt = 32'b0;
        endcase
    end

endmodule
