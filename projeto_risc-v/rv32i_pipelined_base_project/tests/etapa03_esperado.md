# Etapa 3 — resultado esperado e validação na DE2-115

Programa: `assembler/etapa03_test.asm`. Usa apenas endereços naturalmente alinhados. A suíte `python3 tests/run_etapa03.py` monta uma cópia temporária com `beq x0,x0,0` ao final e verifica os valores na simulação Icarus. As suítes `python3 tests/run_branches.py` e `bash tests/run_memory_test.sh` exercitam casos adicionais.

## Estado esperado após o programa

- x1 = `FFFFFFFF`; x2 (LB) = `FFFFFFFF`; x3 (LBU) = `000000FF`;
- x4 = `00000080`; x5 (LH) = `FFFF80FF`; x6 (LHU) = `000080FF`;
- x7 (LW) = `008080FF`; x8 (retorno JAL) = `0000005C`;
- RAM 0x000 = `008080FF`; 0x004 = `0000005C`; 0x008 = `00000070` (retorno JALR); 0x00C = `00000007` (branch não tomado); 0x010 = `008080FF`.
- Nenhuma instrução especulativa deve gravar x14. Na simulação, x11 = `00000070` e x15 = `00000007`.

## Placa

1. Execute as suítes de simulação e compare os valores. Os arquivos `mifs/etapa03_fpga/instruction.mif` e `mifs/etapa03_fpga/data.mif` foram gerados pelo modo `--dump` do montador sem sobrescrever as imagens de outras etapas. O código de usuário ocupa 34 palavras; o dump começa em 0x80.
2. No Quartus, configure a DE2-115 (EP4CE115F29C7), top `pl_top.sv`, todos os fontes de `src/`, PLL e as atribuições de pinos de `quartus/add_to_qsf.txt`; use `quartus/pl_top.sdc`. Disponibilize os dois MIFs acima com os nomes `instruction.mif` e `data.mif` no caminho resolvido pelo Quartus e confirme a inclusão deles na compilação. Não selecione `pl_top_no_pll.sv` sem adaptar o `CLK_HZ` da UART: `pl_mmio.sv` usa 10 MHz e 9600 baud.
3. Compile, confira mensagens de inferência/inicialização das RAMs e análise de timing. Grave o `.sof` via JTAG. Conecte a UART RS-232 a uma porta serial do computador e execute `python3 dump/serial_dump.py /dev/ttyUSB0 --baud 9600 --out etapa03_dump.txt` (substitua pela porta real). Pressione e solte KEY[0] após iniciar a captura, para reiniciar a CPU e receber o dump completo.
4. Compare os campos x1–x8 e a RAM nos endereços acima com o esperado; o dump tem 164 bytes (contador de ciclos, x1–x8, 32 palavras iniciais da RAM). x11/x15 e ausência de escrita em x14 não são transmitidos: confira-os na simulação, ou exponha seus resultados na RAM em outro programa de diagnóstico.

Ainda falta verificar síntese, timing e a execução física: Quartus/ModelSim e a placa não estavam disponíveis neste ambiente. `modelsim/golden.txt` é do programa legado; não o substitua pelo resultado desta etapa sem configurar uma simulação específica para este programa.
