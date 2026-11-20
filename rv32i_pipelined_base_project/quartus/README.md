# Projeto Quartus (DE2-115)

Abra `pl_top.qpf` no Quartus Prime **Lite** com suporte a Cyclone IV E. Alvo: `EP4CE115F29C7`; top `pl_top`; entrada `CLOCK_50` 50 MHz -> `pll_10mhz` -> CPU/UART 10 MHz. `KEY[0]` reseta em nível baixo. Os 52 pinos seguem `add_to_qsf.txt` (no QSF, barramentos são escritos sem chaves: o Quartus 21.1.1 interpretou `{KEY[0]}` literalmente e ignorou a atribuição). As entradas SW/KEY pressupõem JP7 na posição de 2,5 V; confirme o jumper e o padrão de I/O da sua revisão DE2-115 **antes** de energizar/programar. Não use o top `pl_top_no_pll` com esta UART.

O QSF usa caminhos relativos para as fontes, a PLL, o SDC e os MIFs.
As imagens incluídas correspondem a `assembler/etapa03_test.asm` com dump
UART. Para trocar de programa, rode na raiz do projeto:

```powershell
python assembler/assembler.py --dump --output-dir quartus "caminho/meu_programa.asm"
python quartus/check_project.py
```

O montador grava os pares `instruction.mif`/`program.hex` e
`data.mif`/`data.hex` a partir das mesmas palavras. Recompile o projeto
dentro de `quartus/` após trocar as imagens.

## Checagem sem Quartus

A partir da raiz de `rv32i_pipelined_base_project/`:

```sh
python quartus/check_project.py
```

Verifica arquivos/caminhos e ordem do package, 52 pinos sem colisões e iguais à referência local, nomes de pinos sem chaves literais, top/PLL, SDC, padrões de I/O, atributos da RAM, MIFs inteiros de 256 × 32 bits e HEXs com o mesmo conteúdo. Não tenta validar o QSF por `source` em um `tclsh` genérico: esse teste aceitou chaves que o Quartus tratou como parte do nome. **Não** prova inferência de RAM, utilização das imagens pela ferramenta, posicionamento de PLL, timing ou funcionamento físico.

## No PC com Quartus

No terminal da instalação Quartus (`quartus_sh` no PATH), execute da **pasta `quartus/`**:

```sh
python3 check_project.py
quartus_sh --flow compile pl_top -c pl_top
```

Alternativamente, abra `pl_top.qpf` e selecione **Processing > Start Compilation**. Confirme término sem erros, dispositivo/top no Compilation Report e saída real `output_files/pl_top.sof`. **Não há `.sof` gerado neste ambiente.** Inspecione o relatório de Analysis & Synthesis para `pl_imem.rom` e `pl_dmem.ram`: implementação efetiva, sem `object rom used but never assigned`, sem *Can't open memory initialization file* e com valores iniciais incorporados. Para este RTL de leitura assíncrona/máscaras, não presuma que Quartus infira bloco M9K: se uma memória ficar em lógica, confira que seus valores iniciais ainda foram incorporados ou ajuste a arquitetura em tarefa separada.

Em **Tools > Timing Analyzer**, confira *Report Clocks*: clock primário 20 ns e clock derivado pelo PLL 100 ns; inspecione *Unconstrained Paths*, pior slack de setup/hold e avisos do SDC. `derive_pll_clocks` substitui o caminho hard-coded anteriormente não comprovado. Entradas de chaves/botões/UART RX e saídas LEDs/UART TX são exceções de I/O intencionais: não dispense FF→FF do pipeline nem reporte slack antes da compilação. Se os clocks gerados não aparecerem ou houver caminhos internos sem constraint, corrija antes de gravar a placa.

Depois da compilação válida, programe a placa com o `.sof` real usando Quartus Programmer; a confirmação de UART/164 bytes e estado de registradores/RAM ainda exige teste físico separado.
