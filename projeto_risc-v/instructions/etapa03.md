# Etapa 3 — guia da implementação para apresentação

Os caminhos e números de linha abaixo usam como base `rv32i_pipelined_base_project/` e correspondem ao código atual da branch `imprv`. Se o código mudar, confira novamente os números. A arquitetura permanece IF → ID → EX → MEM → WB.

## 1. Desvios condicionais: BNE, BLT, BGE, BLTU e BGEU

| Arquivo e linhas | O que mostrar |
|---|---|
| `src/pl_control.sv:47-51,95-99` | O opcode B-type ativa `Branch` em ID para toda a família; a condição específica não é decidida no controle principal. O opcode BRANCH já existia para BEQ: a ampliação efetiva está no estágio EX. |
| `src/pl_datapath.sv:234-242,304-315` | `funct3` chega a ID/EX e seleciona em EX BEQ (`000`), BNE (`001`), BLT/BGE com sinal (`100/101`) ou BLTU/BGEU sem sinal (`110/111`). Os operandos comparados são `fwd_srca` e `fwd_srcb`, após o forwarding de `src/pl_datapath.sv:255-290`. Códigos não previstos não tomam o desvio. |
| `src/pl_datapath.sv:316-319,113-139,206-225` | O alvo B é PC da instrução + imediato; quando `Branch && branch_taken`, o PC muda e IF/ID e ID/EX são esvaziados (duas instruções descartadas). O mecanismo de flush já existia para BEQ e foi reaproveitado. |
| `src/pl_sign_ext.sv:38-39` | Formação do imediato B, já presente na base e reutilizada pelos novos branches. |

**Para explicar:** BLT/BGE interpretam os operandos como inteiros com sinal (`$signed`); BLTU/BGEU usam os bits como valores sem sinal. Assim, `-1 < 1` é verdadeiro para BLT e falso para BLTU.

## 2. Saltos: JAL e JALR

| Arquivo e linhas | O que mostrar |
|---|---|
| `src/pl_control.sv:41,50-51,63,114-121` | Novo controle `Jump`: `01` para JAL, `10` para JALR; ambos habilitam `RegWrite` para gravar o retorno em `rd`. |
| `src/pl_cpu.sv:50,61-71,87-98` e `src/pl_pipe_pkg.sv:29-31` | Sinal passa do controle ao datapath e fica armazenado no registrador ID/EX. `src/pl_datapath.sv:195-234` zera `jump` no reset/bubble/flush e o captura no avanço normal. |
| `src/pl_sign_ext.sv:33-34,44-45` | JALR usa imediato I com sinal; JAL monta o imediato J com sinal e bit 0 zero. |
| `src/pl_datapath.sv:266-272,316-319` | Em EX, JAL usa `PC + imm`; JALR usa `(rs1 adiantado + imm) & ~1`, zerando o bit 0. Ambos acionam `pc_src` e o flush já mostrado para branches. |
| `src/pl_datapath.sv:320-321,336-345,159-160,423-428` | `ex_result` escolhe PC+4 para o salto, passa por EX/MEM e MEM/WB e chega a `rd` pelo caminho normal de write-back. Assim, o link também pode ser encaminhado por forwarding. |

**Para explicar:** o PC+4 gravado é o PC *da instrução de salto*, não o PC já redirecionado. Sem extensão C, o alvo final precisa estar alinhado a 4 bytes; JALR zera apenas o bit 0. A política para um destino ainda desalinhado está em `instructions/duvidas.md`.

## 3. Acessos à memória: LB, LH, LBU, LHU, SB e SH

| Arquivo e linhas | O que mostrar |
|---|---|
| `src/pl_control.sv:47-49,81-99` e `src/pl_sign_ext.sv:32-39` | LOAD/STORE já calculavam `rs1 + imediato` e ativavam os sinais de acesso. Reutilizamos os formatos I/S de imediato; o tamanho e a extensão vêm de `funct3`, não de novos opcodes. |
| `src/pl_pipe_pkg.sv:52-55` e `src/pl_datapath.sv:341-344` | `funct3` e o endereço calculado chegam juntos a EX/MEM para decidir o acesso no estágio MEM. O campo `funct3` já existia no registrador; agora determina também a granularidade. |
| `src/pl_datapath.sv:351-370` | Endereço `[1:0]` seleciona a posição na palavra. `SB` habilita 1 byte, `SH` 2 bytes e `SW` os 4 bytes; `ram_write_data` desloca os bits de `rs2` até a posição certa. |
| `src/pl_dmem.sv:19,34-43` | Nova entrada `ByteEnable[3:0]`: no `posedge`, cada lane de 8 bits só é escrita quando seu bit da máscara está ativo. Bytes vizinhos permanecem inalterados. |
| `src/pl_datapath.sv:391-405,423-428` | A palavra lida é deslocada para alinhar o byte/meia-palavra desejado; LB/LH estendem sinal (`funct3=000/001`), LBU/LHU estendem zero (`100/101`) e LW retorna a palavra inteira (`010`). O valor segue a MEM/WB e é gravado em `rd`. |
| `src/pl_datapath.sv:373-396` | MMIO só aceita LW/SW alinhados; acessos menores não são enviados aos periféricos. A máscara de bytes afeta apenas a RAM. |

**Exemplo para apresentar:** em `assembler/etapa03_test.asm:1-10`, `SW -1` cria `FFFFFFFF`, `SB` no endereço 1 e `SH` no endereço 2 atualizam somente as lanes escolhidas. LB/LH e LBU/LHU mostram a diferença entre extensão de sinal e de zeros. Os testes cobrem acessos naturalmente alinhados; não foi definido suporte a acessos desalinhados.

## 4. Testes e evidências

- Programa integrado: `assembler/etapa03_test.asm:1-34`. Branches tomados e não tomados estão nas linhas 11–22; JAL/JALR e instruções que devem ser descartadas estão nas linhas 23–30; os resultados de salto são escritos na RAM nas linhas 31–34.
- Autoverificação: `tests/etapa03_tb.sv:16-43` verifica registradores, RAM e ausência de escrita no caminho descartado (`x14`). O roteiro `tests/etapa03_modelsim.do:9-18` compila o pacote primeiro, compila o processador e executa o testbench. O `modelsim/golden.txt` é do programa legado e **não** participa deste teste.
- Resultado obtido: execução no ModelSim Intel FPGA 2020.1 em 16/11/2026, relatada pela equipe: `PASS etapa03 end-to-end assembled program`, 0 erros e 0 avisos. Testes adicionais em Icarus cobrem branches (`tests/run_branches.py`), memória (`tests/run_memory_test.sh`) e o programa montado (`tests/run_etapa03.py`).
- Compatibilidade com ModelSim 2020.1: `src/pl_mmio.sv:48-61` declara `tx_byte` antes de conectá-lo à UART; não modifica a semântica da etapa 3.

## 5. O que falta demonstrar na placa

1. Abrir `quartus/pl_top.qpf` para DE2-115 (EP4CE115F29C7), conferir `src/pl_top.sv`, PLL, pinos, SDC e as duas imagens MIF locais; executar `python quartus/check_project.py` antes de compilar e inspecionar inicialização da RAM, erros e timing no Quartus (`quartus/README.md`). `pl_top.sv` usa PLL de 10 MHz; a UART em `src/pl_mmio.sv:53-56` foi parametrizada para 10 MHz/9600 baud, portanto não trocar para `pl_top_no_pll.sv` sem adaptar o clock da UART.
2. Gravar o `.sof`, conectar RS-232 e executar `python dump/serial_dump.py COM3 --baud 9600 --raw-out etapa03_placa.bin --out etapa03_dump.txt --check-etapa03` (trocar `COM3` pela porta correta; partir da raiz do subprojeto). Pressionar/soltar KEY[0] após o aviso de espera da captura. Consulte `dump/DEMO_ETAPA03.md` para o roteiro completo.
3. Comparar x1–x8 e RAM 0x000–0x010 com `tests/etapa03_esperado.md`: por exemplo, x8=`0000005C`, RAM[0x000]=`008080FF` e RAM[0x008]=`00000070` (retorno de JALR). O dump não inclui x11, x14 ou x15; esses foram verificados no ModelSim. Até obter o dump e conferir o timing, a etapa 3 **não está validada na FPGA**.
