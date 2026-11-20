// =============================================================================
// pl_branch_unit.sv
// Unidade de Decisao de Desvio -- RV32I pipelined (estagio EX)
//
// Compara os operandos do desvio (rs1 e rs2, ja com forwarding) de acordo
// com o funct3 da instrucao B-type e indica se o desvio deve ser tomado.
//
//   funct3 | instrucao | condicao
//   -------|-----------|------------------------------
//    000   |   BEQ     | rs1 == rs2
//    001   |   BNE     | rs1 != rs2
//    100   |   BLT     | rs1 <  rs2  (com sinal)
//    101   |   BGE     | rs1 >= rs2  (com sinal)
//    110   |   BLTU    | rs1 <  rs2  (sem sinal)
//    111   |   BGEU    | rs1 >= rs2  (sem sinal)
//
// A saida Taken so tem efeito quando a instrucao e um desvio (id_ex.branch);
// o datapath faz: pc_src = id_ex.branch && Taken
// =============================================================================

`timescale 1ns / 1ps

module pl_branch_unit (
    input  logic [2:0]  Funct3,   // funct3 da instrucao no estagio EX
    input  logic [31:0] SrcA,     // rs1 (apos forwarding)
    input  logic [31:0] SrcB,     // rs2 (apos forwarding)
    output logic        Taken     // 1 = condicao do desvio verdadeira
);

    always_comb begin
        case (Funct3)
            3'b000:  Taken = (SrcA == SrcB);                     // BEQ
            3'b001:  Taken = (SrcA != SrcB);                     // BNE
            3'b100:  Taken = ($signed(SrcA) <  $signed(SrcB));   // BLT
            3'b101:  Taken = ($signed(SrcA) >= $signed(SrcB));   // BGE
            3'b110:  Taken = (SrcA <  SrcB);                     // BLTU
            3'b111:  Taken = (SrcA >= SrcB);                     // BGEU
            default: Taken = 1'b0;                               // funct3 invalido
        endcase
    end

endmodule
