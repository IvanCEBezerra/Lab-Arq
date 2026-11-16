# Etapa 3 — implementação e validação

## O que foi feito

- **BNE, BLT, BGE, BLTU, BGEU:** o estágio EX usa `funct3` para escolher a condição de desvio. Compara os operandos após o forwarding, distinguindo comparações com sinal (`BLT`/`BGE`) e sem sinal (`BLTU`/`BGEU`). O BEQ existente e o descarte das duas instruções mais novas em um desvio tomado foram preservados.
- **JAL e JALR:** `pl_sign_ext.sv` gera o imediato J; o alvo de JAL é `PC + imediato` e o de JALR é `(rs1 com forwarding + imediato) & ~1`. Ambos gravam `PC+4` em `rd` e descartam as duas instruções seguintes ao salto.
- **LB, LH, LBU, LHU, SB e SH:** a leitura seleciona byte ou meia-palavra pelo deslocamento no endereço e faz extensão de sinal (LB/LH) ou de zeros (LBU/LHU). A escrita usa máscara por byte na RAM, preservando os outros bytes da palavra. LW/SW continuam funcionando; MMIO permanece acessível somente por palavras inteiras. Os testes cobrem acessos naturalmente alinhados; a política para desalinhados ainda está em `instructions/duvidas.md`.

## Como validar

1. **Simulação:** rode `python3 tests/run_branches.py`, `bash tests/run_memory_test.sh` e `python3 tests/run_etapa03.py` a partir de `rv32i_pipelined_base_project/`, com Icarus Verilog instalado. O teste integrado monta `assembler/etapa03_test.asm` e verifica os valores esperados. Também existem testes específicos de JAL/JALR e regressão do programa-base em `tests/`.
2. **Síntese:** use a DE2-115/EP4CE115F29C7, `pl_top.sv` (PLL para 10 MHz), os fontes em `src/`, as atribuições de `quartus/add_to_qsf.txt` e as restrições `quartus/pl_top.sdc`. Coloque `mifs/etapa03_fpga/instruction.mif` e `data.mif` no caminho de inicialização esperado pelo Quartus. Compile e confira inicialização das RAMs, erros/avisos e timing; então grave o `.sof` via JTAG.
3. **Placa:** conecte a porta serial a 9600 baud, inicie `python3 dump/serial_dump.py /dev/ttyUSB0 --baud 9600 --out etapa03_dump.txt` (substitua a porta), e pressione/solte KEY[0] para reiniciar o programa. Compare o dump com `tests/etapa03_esperado.md`: x1=`FFFFFFFF`, x2=`FFFFFFFF`, x3=`000000FF`, x4=`00000080`, x5=`FFFF80FF`, x6=`000080FF`, x7=`008080FF`, x8=`0000005C`; RAM[0x000]=`008080FF`, RAM[0x004]=`0000005C`, RAM[0x008]=`00000070`, RAM[0x00C]=`00000007`, RAM[0x010]=`008080FF`.

**ModelSim:** o usuário executou a simulação integrada no ModelSim Intel FPGA 2020.1 em 16/11/2026; `etapa03_tb` terminou em PASS, sem erros ou avisos. O enunciado não exige especificamente ModelSim, mas essa conferência complementa os testes Icarus. O `modelsim/golden.txt` pertence ao programa legado; o testbench da etapa 3 verifica diretamente registradores e RAM. Ainda faltam síntese/timing no Quartus e captura do dump na placa: não há validação física concluída.
