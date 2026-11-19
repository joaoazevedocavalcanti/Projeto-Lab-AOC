#!/usr/bin/env bash
# Roda cada tests/*.asm (e o programa padrao modelsim/program.hex) no RTL com
# Icarus Verilog e compara o estado final com o simulador de referencia iss.py.
#
# Uso:  bash tests/run_tests.sh [dir_src]      (padrao: src/)
#       KEEP=1 bash tests/run_tests.sh         (mantem o diretorio de trabalho)
# Requer: Icarus Verilog 12 (no PATH ou em C:/iverilog/bin) e Python 3.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${1:-$ROOT/src}
export PATH=/c/iverilog/bin:$PATH
WORK=$(mktemp -d)
if [ -n "${KEEP:-}" ]; then echo "WORK=$WORK"; else trap 'rm -rf "$WORK"' EXIT; fi

# Copia do testbench compativel com iverilog:
#   void'($fgets(..)) -> if ($fgets(..)) ;   string -> reg   $stop -> $finish
sed -e "s/void'(\$fgets(gline, gfd));/if (\$fgets(gline, gfd)) ;/" \
    -e "s/void'(\$fgets(oline, ofd));/if (\$fgets(oline, ofd)) ;/" \
    -e 's/string  gline, oline;/reg [8*256-1:0] gline, oline;/' \
    -e 's/\$stop;/$finish;/' "$ROOT/src/pl_cpu_tb.sv" > "$WORK/tb.sv"

FILES="pl_pipe_pkg pl_alu pl_alu_ctrl pl_control pl_sign_ext pl_regfile pl_imem
       pl_dmem pl_hazard pl_forward pl_uart pl_mmio pl_datapath pl_cpu"
if ! iverilog -g2012 -o "$WORK/cpu.vvp" $(for f in $FILES; do echo "$SRC/$f.sv"; done) \
        "$WORK/tb.sv" 2> "$WORK/build.log"; then
    grep -v "sorry: constant selects" "$WORK/build.log"
    echo "BUILD FAILED"; exit 1
fi

pass=0; fail=0
run_case () {  # $1 = nome, $2 = diretorio com program.hex e data.hex
    local name=$1 dir=$2
    (cd "$dir" && vvp -n "$WORK/cpu.vvp" > sim.log 2>&1)
    grep '^FINAL' "$dir/output.txt" | grep -v 'xxxxxxxx' \
        | sed 's/0x\(.*\)/0x\U\1/' > "$dir/rtl.txt"
    python "$ROOT/tests/iss.py" "$dir/program.hex" "$dir/data.hex" \
        | tr -d '\r' > "$dir/ref.txt"
    if diff -q "$dir/ref.txt" "$dir/rtl.txt" > /dev/null; then
        echo "PASS  $name"; pass=$((pass+1))
    else
        echo "FAIL  $name   (< esperado pela ISA | > obtido no RTL)"
        diff "$dir/ref.txt" "$dir/rtl.txt" | grep '^[<>]' | sed 's/^/        /'
        fail=$((fail+1))
    fi
    grep -q "timeout" "$dir/sim.log" && echo "        (RTL: halt nao detectado -- timeout)"
}

# Programa padrao do projeto
mkdir -p "$WORK/default"
cp "$ROOT/modelsim/program.hex" "$ROOT/modelsim/data.hex" "$WORK/default/"
run_case "default (modelsim/program.hex)" "$WORK/default"

for asm in "$ROOT"/tests/*.asm; do
    n=$(basename "$asm" .asm); d="$WORK/$n"; mkdir -p "$d"
    if ! (cd "$d" && python "$ROOT/assembler/assembler.py" "$asm" > asm.log 2>&1); then
        echo "FAIL  $n (assembler)"; cat "$d/asm.log"; fail=$((fail+1)); continue
    fi
    echo 00000000 > "$d/data.hex"
    run_case "$n" "$d"
done
echo "---- $pass pass, $fail fail"
