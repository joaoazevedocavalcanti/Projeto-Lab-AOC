"""
Simulador de referencia RV32I (nivel de ISA, sem pipeline).

Uso: python iss.py program.hex [data.hex]
Imprime o estado final dos registradores e das 16 primeiras palavras da dmem
no mesmo formato "FINAL ..." usado pelo testbench (pl_cpu_tb.sv), para
comparacao direta com a saida da simulacao do RTL.

Para ao encontrar `beq x0,x0,0` (halt).
"""
import sys

M = 0xFFFFFFFF


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def load_hex(path, n=256):
    mem = [0] * n
    try:
        with open(path) as f:
            words = [l.strip() for l in f if l.strip()]
    except FileNotFoundError:
        return mem
    for i, w in enumerate(words[:n]):
        mem[i] = int(w, 16)
    return mem


def run(imem, dmem, max_steps=10000):
    x = [0] * 32
    pc = 0

    def rb(a):
        return (dmem[(a >> 2) & 0xFF] >> (8 * (a & 3))) & 0xFF

    def wb(a, v):
        i, s = (a >> 2) & 0xFF, 8 * (a & 3)
        dmem[i] = (dmem[i] & ~(0xFF << s) & M) | ((v & 0xFF) << s)

    for _ in range(max_steps):
        ins = imem[(pc >> 2) & 0xFF]
        if ins == 0x00000063:  # beq x0,x0,0 -> halt
            return x, dmem
        op = ins & 0x7F
        rd = (ins >> 7) & 31
        f3 = (ins >> 12) & 7
        rs1 = (ins >> 15) & 31
        rs2 = (ins >> 20) & 31
        f7 = ins >> 25
        a, b = x[rs1], x[rs2]
        sa, sb = sx(a, 32), sx(b, 32)
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
        imm_b = sx(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) |
                   (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
        imm_u = ins & 0xFFFFF000
        imm_j = sx(((ins >> 31) << 20) | (((ins >> 12) & 0xFF) << 12) |
                   (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
        npc = pc + 4
        res = None

        def alu(f3, a, b, alt):
            sa, sb = sx(a, 32), sx(b, 32)
            sh = b & 31
            return {
                0: (a - b) if alt else (a + b),
                1: a << sh,
                2: int(sa < sb),
                3: int(a < b),
                4: a ^ b,
                5: (sa >> sh) if alt else (a >> sh),
                6: a | b,
                7: a & b,
            }[f3] & M

        if op == 0b0110011:
            res = alu(f3, a, b, f7 == 0b0100000)
        elif op == 0b0010011:
            res = alu(f3, a, imm_i & M, f3 == 5 and f7 == 0b0100000)
        elif op == 0b0000011:
            ad = (a + imm_i) & M
            if f3 == 0: res = sx(rb(ad), 8) & M
            elif f3 == 1: res = sx(rb(ad) | rb(ad + 1) << 8, 16) & M
            elif f3 == 2: res = dmem[(ad >> 2) & 0xFF]
            elif f3 == 4: res = rb(ad)
            elif f3 == 5: res = rb(ad) | rb(ad + 1) << 8
        elif op == 0b0100011:
            ad = (a + imm_s) & M
            n = {0: 1, 1: 2, 2: 4}[f3]
            for k in range(n):
                wb(ad + k, b >> (8 * k))
        elif op == 0b1100011:
            take = {0: a == b, 1: a != b, 4: sa < sb, 5: sa >= sb,
                    6: a < b, 7: a >= b}[f3]
            if take:
                npc = pc + imm_b
        elif op == 0b1101111:
            res, npc = pc + 4, pc + imm_j
        elif op == 0b1100111:
            res, npc = pc + 4, (a + imm_i) & ~1
        elif op == 0b0110111:
            res = imm_u
        elif op == 0b0010111:
            res = (pc + imm_u) & M
        else:
            raise ValueError(f"opcode desconhecido 0x{ins:08X} em pc=0x{pc:X}")
        if res is not None and rd:
            x[rd] = res & M
        pc = npc & M
    raise RuntimeError("timeout: halt nao encontrado")


if __name__ == "__main__":
    imem = load_hex(sys.argv[1])
    dmem = load_hex(sys.argv[2]) if len(sys.argv) > 2 else [0] * 256
    x, dmem = run(imem, dmem)
    for i in range(1, 32):
        if x[i]:
            print(f"FINAL REG {i:2d} = 0x{x[i]:08X}")
    for i in range(16):
        if dmem[i]:
            print(f"FINAL MEM[{i:3d}] = 0x{dmem[i]:08X}")
