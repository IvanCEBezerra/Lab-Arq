# Estado do projeto

## Feito

- [x] Etapas 1 e 2 (R-type, I-type aritmético, LUI e AUIPC): validadas na placa, conforme registro da equipe.
- [x] Etapa 3 — branches `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`: condição selecionada por `funct3` em EX, comparação com/sem sinal e flush das duas instruções mais novas quando o desvio é tomado.
- [x] Etapa 3 — `JAL` e `JALR`: imediato J, alvo correto (com forwarding de `rs1` e bit 0 zerado no JALR), gravação de PC+4 e flush.
- [x] Etapa 3 — `LB`, `LH`, `LBU`, `LHU`, `SB`, `SH`: seleção e extensão de byte/meia-palavra, escrita com máscara de bytes na RAM e MMIO restrito a LW/SW por palavra.
- [x] Testes em Icarus: casos de branches, memória, saltos, regressão da base e programa integrado. Arquivos em `rv32i_pipelined_base_project/tests/`.
- [x] Programa `assembler/etapa03_test.asm`, resultados esperados em `tests/etapa03_esperado.md` e imagens da placa em `mifs/etapa03_fpga/` (caminhos relativos a `rv32i_pipelined_base_project/`).
- [x] Simulação integrada no ModelSim Intel FPGA 2020.1: `tests/etapa03_modelsim.do` / `etapa03_tb` com PASS, 0 erros e 0 avisos, conforme log enviado pela equipe em 16/11/2026. O `golden.txt` legado não é usado nesse teste.
- [x] Etapa 3 — programa integrado executado na DE2-115 em 16/11/2026, segundo a equipe, no código `c8ff0be`: captura UART COM14 a 9600 baud em `rv32i_pipelined_base_project/etapa03_placa_01.bin` (164 bytes, SHA-256 `c1f0b46960927fcd4bd2ac9b481fe9695e63684908bf98dfb164b9708ed86289`) e relatório `etapa03_placa_01.txt`, versionados em `826f084`. A comparação offline deste binário com `dump/serial_dump.py --input etapa03_placa_01.bin --check-etapa03` retornou PASS para x1–x8 e 32 palavras da RAM; o relatório regenerado coincide com o versionado, exceto pelo horário de geração. Contador de ciclos: 62 (não faz parte do oráculo). Esta evidência valida o programa integrado, não todos os casos do ISA.
- [x] Arquivar/inspecionar o relatório do build final Quartus Lite 21.1.1: conferir pinagem efetivamente aplicada (sem `136021`/`169085`), inicialização das memórias e timing do `.sof` que produziu a captura. O sucesso do dump não substitui esse registro técnico; o log final da compilação não está versionado.

## A fazer

O programa integrado da etapa 3 já foi capturado e conferido na placa. Permanecem pendentes o registro do relatório da compilação final do Quartus (a primeira compilação tinha 49 pinos sem localização exata; não usar seus números como evidência do build corrigido), a atualização do relatório técnico, eventuais esclarecimentos do professor e o ensaio da apresentação.

- [ ] Perguntar ao professor sobre o comportamento de acessos desalinhados e destinos de salto desalinhados (`instructions/duvidas.md`); os testes atuais usam acessos naturalmente alinhados.
- [ ] Concluir o relatório no repositório: arquitetura, mudanças por etapa e resultados reais da simulação e do dump físico.
- [ ] Preparar o `.sof`, os MIFs e o roteiro da demonstração ao vivo; ensaiar a apresentação na placa.