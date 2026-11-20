// =============================================================================
// pl_load_unit.sv
// Unidade de Load -- RV32I pipelined (estagio MEM)
//
// Recebe a palavra de 32 bits lida da memoria (ou do MMIO) e entrega o valor
// que vai para o registrador, de acordo com o funct3 da instrucao de load:
//
//   funct3 | instrucao | dado entregue
//   -------|-----------|-----------------------------------------------
//    000   |   LB      | byte selecionado,       extensao de sinal
//    001   |   LH      | meia palavra selecionada, extensao de sinal
//    010   |   LW      | palavra inteira (sem alteracao)
//    100   |   LBU     | byte selecionado,       extensao com zeros
//    101   |   LHU     | meia palavra selecionada, extensao com zeros
//
// Selecao pelo endereco de byte (AddrLow = alu_result[1:0]):
//   byte : 00 -> [7:0]   01 -> [15:8]   10 -> [23:16]   11 -> [31:24]
//   meia : AddrLow[1] = 0 -> [15:0]     AddrLow[1] = 1 -> [31:16]
//   (acessos desalinhados de meia palavra/palavra nao sao tratados)
// =============================================================================

`timescale 1ns / 1ps

module pl_load_unit (
    input  logic [2:0]  Funct3,     // funct3 da instrucao no estagio MEM
    input  logic [1:0]  AddrLow,    // alu_result[1:0] (byte dentro da palavra)
    input  logic [31:0] ReadWord,   // palavra lida da memoria / MMIO
    output logic [31:0] LoadData    // valor final para o registrador
);

    logic [7:0]  byte_sel;   // byte escolhido pelo endereco
    logic [15:0] half_sel;   // meia palavra escolhida pelo endereco

    // Selecao do byte
    always_comb begin
        case (AddrLow)
            2'b00:   byte_sel = ReadWord[7:0];
            2'b01:   byte_sel = ReadWord[15:8];
            2'b10:   byte_sel = ReadWord[23:16];
            default: byte_sel = ReadWord[31:24];
        endcase
    end

    // Selecao da meia palavra
    assign half_sel = AddrLow[1] ? ReadWord[31:16] : ReadWord[15:0];

    // Extensao conforme a instrucao
    always_comb begin
        case (Funct3)
            3'b000:  LoadData = {{24{byte_sel[7]}},  byte_sel};   // LB
            3'b001:  LoadData = {{16{half_sel[15]}}, half_sel};   // LH
            3'b100:  LoadData = {24'b0, byte_sel};                // LBU
            3'b101:  LoadData = {16'b0, half_sel};                // LHU
            default: LoadData = ReadWord;                         // LW
        endcase
    end

endmodule
