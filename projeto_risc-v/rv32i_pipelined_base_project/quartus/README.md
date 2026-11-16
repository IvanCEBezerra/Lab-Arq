# Projeto Quartus da etapa 3 (DE2-115)

Abra `pl_top.qpf` no Quartus Prime **Lite** com suporte a Cyclone IV E. Alvo: `EP4CE115F29C7`; top `pl_top`; entrada `CLOCK_50` 50 MHz -> `pll_10mhz` -> CPU/UART 10 MHz. `KEY[0]` reseta em nível baixo. Os 52 pinos seguem `add_to_qsf.txt` (no QSF, barramentos são escritos sem chaves: o Quartus 21.1.1 interpretou `{KEY[0]}` literalmente e ignorou a atribuição). As entradas SW/KEY pressupõem JP7 na posição de 2,5 V; confirme o jumper e o padrão de I/O da sua revisão DE2-115 **antes** de energizar/programar. Não use o top `pl_top_no_pll` com esta UART.

`pl_top.qsf` lista `../src/pl_pipe_pkg.sv` primeiro, demais arquivos de síntese em `../src/`, o wrapper `../src/pll_10mhz.v`, `pl_top.sdc` e os dois MIFs **locais**. `pl_imem.sv` e `pl_dmem.sv` referenciam `instruction.mif` e `data.mif` por atributo; sua inicialização sintetizável também lê `program.hex` e `data.hex` desta pasta. Os MIFs são cópias byte a byte de `../mifs/etapa03_fpga/`, e os HEXs contêm as mesmas 256 palavras em ordem de endereço. Não compilar a partir da raiz com outro conjunto de imagens por engano. Se regenerar os MIFs, regenere também os HEXs e execute a checagem de novo. Pinagem e níveis de I/O conferidos com o manual Terasic DE2-115, tabelas 4-1 a 4-3, 4-5 e 4-18.

## Checagem sem Quartus

A partir da pasta `projeto_risc-v/`:

```sh
python3 rv32i_pipelined_base_project/quartus/check_project.py
```

Verifica arquivos/caminhos e ordem do package, 52 pinos sem colisões e iguais à referência local, nomes de pinos sem chaves literais, top/PLL, SDC, padrões de I/O, atributos da RAM, MIFs inteiros de 256 × 32 bits idênticos à etapa 3 e HEXs com o mesmo conteúdo. Não tenta validar o QSF por `source` em um `tclsh` genérico: esse teste aceitou chaves que o Quartus tratou como parte do nome. **Não** prova inferência de RAM, utilização das imagens pela ferramenta, posicionamento de PLL, timing ou funcionamento físico.

## No PC com Quartus

No terminal da instalação Quartus (`quartus_sh` no PATH), execute da **pasta `quartus/`**:

```sh
python3 check_project.py
quartus_sh --flow compile pl_top -c pl_top
```

Alternativamente, abra `pl_top.qpf` e selecione **Processing > Start Compilation**. Confirme término sem erros, dispositivo/top no Compilation Report e saída real `output_files/pl_top.sof`. **Não há `.sof` gerado neste ambiente.** Inspecione o relatório de Analysis & Synthesis para `pl_imem.rom` e `pl_dmem.ram`: implementação efetiva, sem `object rom used but never assigned`, sem *Can't open memory initialization file* e com valores iniciais incorporados. Para este RTL de leitura assíncrona/máscaras, não presuma que Quartus infira bloco M9K: se uma memória ficar em lógica, confira que seus valores iniciais ainda foram incorporados ou ajuste a arquitetura em tarefa separada.

Em **Tools > Timing Analyzer**, confira *Report Clocks*: clock primário 20 ns e clock derivado pelo PLL 100 ns; inspecione *Unconstrained Paths*, pior slack de setup/hold e avisos do SDC. `derive_pll_clocks` substitui o caminho hard-coded anteriormente não comprovado. Entradas de chaves/botões/UART RX e saídas LEDs/UART TX são exceções de I/O intencionais: não dispense FF→FF do pipeline nem reporte slack antes da compilação. Se os clocks gerados não aparecerem ou houver caminhos internos sem constraint, corrija antes de gravar a placa.

Depois da compilação válida, programe a placa com o `.sof` real usando Quartus Programmer; a confirmação de UART/164 bytes e estado de registradores/RAM ainda exige teste físico separado. Estes arquivos de configuração e imagens foram adicionados explicitamente ao Git; o `.gitignore` ainda evita versionar os arquivos novos gerados pela compilação em `quartus/`.
