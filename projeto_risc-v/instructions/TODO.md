# Estado do projeto

## Feito

- [x] Etapas 1 e 2 (R-type, I-type aritmético, LUI e AUIPC): validadas na placa, conforme registro da equipe.
- [x] Etapa 3 — branches `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`: condição selecionada por `funct3` em EX, comparação com/sem sinal e flush das duas instruções mais novas quando o desvio é tomado.
- [x] Etapa 3 — `JAL` e `JALR`: imediato J, alvo correto (com forwarding de `rs1` e bit 0 zerado no JALR), gravação de PC+4 e flush.
- [x] Etapa 3 — `LB`, `LH`, `LBU`, `LHU`, `SB`, `SH`: seleção e extensão de byte/meia-palavra, escrita com máscara de bytes na RAM e MMIO restrito a LW/SW por palavra.
- [x] Testes em Icarus: casos de branches, memória, saltos, regressão da base e programa integrado. Arquivos em `rv32i_pipelined_base_project/tests/`.
- [x] Programa `assembler/etapa03_test.asm`, resultados esperados em `tests/etapa03_esperado.md` e imagens da placa em `mifs/etapa03_fpga/` (caminhos relativos a `rv32i_pipelined_base_project/`).
- [x] Simulação integrada no ModelSim Intel FPGA 2020.1: `tests/etapa03_modelsim.do` / `etapa03_tb` com PASS, 0 erros e 0 avisos, conforme log enviado pela equipe em 16/11/2026. O `golden.txt` legado não é usado nesse teste.

## A fazer

- [ ] Configurar o projeto Quartus da DE2-115 para `pl_top.sv` e EP4CE115F29C7; incluir fontes, pinos, `quartus/pl_top.sdc` e os MIFs da etapa 3 nos caminhos esperados. Compilar e conferir inicialização da RAM e timing.
- [ ] Gravar o `.sof` na FPGA, capturar os 164 bytes pela UART a 9600 baud com `dump/serial_dump.py` e comparar registradores x1–x8 e RAM com `tests/etapa03_esperado.md`. Só então declarar a etapa 3 validada na placa.
- [ ] Perguntar ao professor sobre o comportamento de acessos desalinhados e destinos de salto desalinhados (`instructions/duvidas.md`); os testes atuais usam acessos naturalmente alinhados.
- [ ] Concluir o relatório no repositório: arquitetura, mudanças por etapa e resultados reais da simulação e do dump físico.
- [ ] Preparar o `.sof`, os MIFs e o roteiro da demonstração ao vivo; ensaiar a apresentação na placa.