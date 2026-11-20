// =============================================================================
// pl_store_unit.sv
// Unidade de Store -- RV32I pipelined (estagio MEM)
//
// A memoria de dados tem leitura assincrona: durante o estagio MEM de um
// store, a palavra antiga do endereco ja esta disponivel (OldWord). Esta
// unidade monta a palavra nova trocando apenas os bytes escritos pela
// instrucao e mantendo os demais (leitura-modificacao-escrita no mesmo ciclo):
//
//   funct3 | instrucao | bytes escritos (ByteEn)
//   -------|-----------|-----------------------------------------------
//    000   |   SB      | 1 byte  : 0001 << AddrLow
//    001   |   SH      | 2 bytes : AddrLow[1]=0 -> 0011, =1 -> 1100
//    010   |   SW      | 4 bytes : 1111
//
//   NewWord = (OldWord & ~mascara) | (dado_replicado & mascara)
//
// O dado e replicado em todas as posicoes ({4{byte}} ou {2{meia}}), e a
// mascara escolhe qual copia entra na palavra.
// (acessos desalinhados de meia palavra/palavra nao sao tratados)
// =============================================================================

`timescale 1ns / 1ps

module pl_store_unit (
    input  logic [2:0]  Funct3,     // funct3 da instrucao no estagio MEM
    input  logic [1:0]  AddrLow,    // alu_result[1:0] (byte dentro da palavra)
    input  logic [31:0] StoreData,  // rs2 (apos forwarding)
    input  logic [31:0] OldWord,    // palavra atual da memoria nesse endereco
    output logic [31:0] NewWord,    // palavra a ser gravada
    output logic [3:0]  ByteEn      // bytes alterados (para depuracao)
);

    logic [31:0] data_rep;   // dado replicado nas posicoes possiveis
    logic [31:0] mask;       // 1 nos bits que serao escritos

    always_comb begin
        case (Funct3)
            3'b000: begin                                   // SB
                ByteEn   = 4'b0001 << AddrLow;
                data_rep = {4{StoreData[7:0]}};
            end
            3'b001: begin                                   // SH
                ByteEn   = AddrLow[1] ? 4'b1100 : 4'b0011;
                data_rep = {2{StoreData[15:0]}};
            end
            default: begin                                  // SW
                ByteEn   = 4'b1111;
                data_rep = StoreData;
            end
        endcase
    end

    // Expande cada bit de ByteEn para os 8 bits do byte correspondente
    assign mask = {{8{ByteEn[3]}}, {8{ByteEn[2]}}, {8{ByteEn[1]}}, {8{ByteEn[0]}}};

    assign NewWord = (OldWord & ~mask) | (data_rep & mask);

endmodule
