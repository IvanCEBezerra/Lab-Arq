# RV32I Pipelined Base Project

Processador RISC-V de 32 bits com pipeline de 5 estágios implementado em SystemVerilog, baseado nas seções 4.6 a 4.10 de *Computer Organization and Design: RISC-V Edition* (Patterson & Hennessy). O projeto tem como plataforma alvo a placa **DE2-115** (Intel Cyclone IV E) e é estruturado para servir de base para extensões do conjunto de instruções pelos alunos.

---

## Instruções do projeto

| Grupo | Instruções |
| --- | --- |
| Base | ADD, SUB, OR, AND, SLT, BEQ, LW, SW |
| Etapa 01 | XOR, SLL, SRL, SRA, SLTU |
| Etapa 02 | ADDI, ANDI, ORI, SLTI, SLLI, SRLI, SRAI, LUI, AUIPC |
| Etapa 03 | LB, LH, LBU, LHU, SB, SH, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR |

O [enunciado](../instructions/projeto.pdf) define o escopo das etapas. O
[relatório técnico](../instructions/relatorio.md) explica as alterações no pipeline.
Os testes de memória usam endereços naturalmente alinhados.

## Rodar um programa novo no ModelSim

Na raiz do projeto, com Python 3 e ModelSim no PATH, passe o caminho do arquivo
`.asm` recebido ou criado no editor. Use aspas para caminhos com espaços.

```powershell
python assembler/assembler.py --output-dir modelsim/novo "caminho/meu_programa.asm"
vsim -c -do "set run_dir modelsim/novo; set sim_args {+DUMP_ONLY +MAX_CYCLES=20000}; do modelsim/run.do"
```

O montador gera os quatro arquivos de memória. Quando há espaço, acrescenta um
laço de parada após o código. O testbench também reconhece um desvio ou salto
para o próprio endereço já existente no programa. Um programa que ocupa as
256 palavras precisa incluir sua própria parada. O estado final sai no terminal
e em `modelsim/novo/output.txt`. Na seção final do relatório, palavras de RAM
omitidas valem zero. Para programas longos, ajuste `+MAX_CYCLES`.

Para rodar a regressão original com `modelsim/golden.txt`:

```powershell
vsim -c -do modelsim/run.do
```

---

## Arquitetura

### Pipeline de 5 estágios

```
+------+     +------+     +------+     +------+     +------+
|  IF  | --> |  ID  | --> |  EX  | --> | MEM  | --> |  WB  |
+------+     +------+     +------+     +------+     +------+
  Busca      Decode       Execução     Memória     Write-back
  instrução  Regs         ALU          dmem/MMIO   Regfile
             Sign-ext     Branch
```

**Registradores de pipeline:** `IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB` (definidos em `pl_pipe_pkg.sv`).

### Tratamento de hazards

| Hazard | Mecanismo | Detalhe |
|--------|-----------|---------|
| RAW (dado) | Forwarding | EX/MEM → EX e MEM/WB → EX (`pl_forward.sv`) |
| Load-use | Stall | 1 bolha inserida em ID/EX (`pl_hazard.sv`) |
| Branch taken | Flush | 2 NOPs (IF e ID) na resolução em EX (`pl_datapath.sv`) |

**Resolução de branch no estágio EX:** quando `BEQ` é tomado, o PC retorna ao alvo e os dois estágios anteriores são esvaziados. O custo é de 2 ciclos de penalidade por branch tomado.

**Banco de registradores com escrita em negedge:** a escrita ocorre na borda de descida do clock, garantindo que o estágio ID leia o valor atualizado no próximo posedge sem necessidade de forwarding WB→ID explícito.

### Mapa de memória

| Endereço (byte) | Tamanho | Acesso | Descrição |
|-----------------|---------|--------|-----------|
| `0x000 – 0x3FC` | 256 × 32 b | R/W | Memória de dados (`pl_dmem`) |
| `0x400` | 32 b | R | SW\[17:0\] — chaves deslizantes |
| `0x404` | 32 b | R | KEY\[3:0\] — botões push |
| `0x408` | 32 b | W | LEDR\[17:0\] — LEDs vermelhos |
| `0x40C` | 32 b | W | LEDG\[8:0\] — LEDs verdes |
| `0x410` | 32 b | R/W | UART RS-232 (8N1; 9600 baud pretendidos, pendente de correção do clock) |
| `0x414` | 32 b | R | Contador de ciclos de clock (32 bits, reset em 0) |

Seleção: `alu_result[10] = 1` redireciona o acesso ao controlador MMIO (`pl_mmio`).

**Leitura da UART (`lw` em 0x410):** `{22'b0, tx_busy[9], rx_ready[8], rx_data[7:0]}`

**Escrita na UART (`sw` em 0x410):** o hardware (`pl_mmio`) divide automaticamente a palavra de 32 bits em 4 bytes e os envia em sequência little-endian (byte 0 primeiro). `tx_busy` permanece alto até o último byte ser aceito pelo shift register. O software deve aguardar `tx_busy = 0` antes de escrever nova palavra.

### ALU — codificação de operação

| Operation | Instrução |
|-----------|-----------|
| `4'd01` ADD | LW, SW, ADD |
| `4'd02` SUB | BEQ (comparação) |
| `4'd03` XOR | XOR |
| `4'd04` OR  | OR |
| `4'd05` AND | AND |
| `4'd06` SLL | SLL |
| `4'd07` SRL | SRL |
| `4'd08` SRA | SRA |
| `4'd11` SLT | SLT |
| `4'd12` SLTU | SLTU |

---

## Estrutura do repositório

```
rv32i_pipelined_base_project/
│
├── src/                        Código-fonte SystemVerilog
│   ├── pl_pipe_pkg.sv          Structs dos registradores de pipeline
│   ├── pl_top.sv               Top-level (PLL 50→10 MHz + CPU)
│   ├── pl_top_no_pll.sv        Top-level alternativo (clock direto de 50 MHz)
│   ├── pl_cpu.sv               Wrapper: Control + ALU_Ctrl + Datapath
│   ├── pl_control.sv           Unidade de controle (estágio ID)
│   ├── pl_alu_ctrl.sv          Controle da ALU (estágio EX)
│   ├── pl_alu.sv               ALU 32 bits
│   ├── pl_regfile.sv           Banco de registradores 32×32 b
│   ├── pl_sign_ext.sv          Extensão de sinal I/S/B
│   ├── pl_imem.sv              Memória de instruções 256×32 b (MIF)
│   ├── pl_dmem.sv              Memória de dados 256×32 b (MIF)
│   ├── pl_mmio.sv              Controlador MMIO (SW/KEY/LED/UART)
│   ├── pl_uart.sv              UART RS-232 8N1 (divisor parametrizável)
│   ├── pl_hazard.sv            Detecção de hazard load-use
│   ├── pl_forward.sv           Unidade de forwarding
│   ├── pl_datapath.sv          Datapath 5 estágios
│   ├── pl_cpu_tb.sv            Testbench de verificação
│   └── pll_10mhz.v             PLL Altera (50 MHz → 10 MHz)
│
├── mifs/                       Arquivos de inicialização de memória
│   ├── instruction_halt_serial.mif  Programa demonstrativo com UART/LED
│   ├── data_halt_serial.mif         Dados desse programa
│   ├── mmio_test_program.mif   Programa de teste MMIO + UART
│   └── mmio_test_data.mif      Dados para o teste MMIO
│
├── assembler/
│   ├── assembler.py            Montador Python: assembly → .mif / dump
│   ├── hello.asm               Programa de entrada padrão
│   ├── etapa03_test.asm        Exemplo integrado da etapa 3
│   ├── instruction.mif         MIF gerado (não versionado)
│   ├── data.mif                MIF gerado em --dump (não versionado)
│   └── program.hex             Hex gerado (não versionado)
│
├── dump/
│   └── serial_dump.py          Captura e decodifica dump serial do FPGA
│
├── modelsim/                   Dados versionados para simulação
│   ├── program.hex             Imagem da instrução (.hex para $readmemh)
│   ├── data.hex                Imagem dos dados (.hex para $readmemh)
│   ├── golden.txt              Saída esperada pela regressão
│   ├── run.do                  Compila e executa o testbench original
│
└── quartus/                    Arquivos auxiliares versionados para síntese
    ├── add_to_qsf.txt          Atribuições de pinos para incorporar ao QSF
    ├── pl_top.qpf / pl_top.qsf Projeto e atribuições da DE2-115
    └── pl_top.sdc              Restrições de timing com PLL
```

---

## Programa de regressão

**Programa de teste padrão (`modelsim/program.hex`):**

```
000: lw  x1,  0(x0)   x1 = 10
001: lw  x2,  4(x0)   x2 = 20
002: add x3, x1, x2   x3 = 30   -- forwarding MEM/WB→EX
003: and x4, x3, x1   x4 = 10   -- forwarding EX/MEM→EX
004: lw  x5,  0(x0)   x5 = 10   -- causa load-use stall
005: add x6, x5, x2   x6 = 30   -- executado após 1 ciclo de stall
006: sw  x3,  8(x0)   dmem[2] = 30
007: beq x1, x2, +8   NÃO tomado (10 ≠ 20)
008: add x7, x1, x2   x7 = 30
009: beq x1, x5, +8   TOMADO (10 = 10) → flush de 00A
00A: add x8, x0, x0   DESCARTADO
00B: add x8, x1, x4   x8 = 20
00C: beq x0, x0,  0   halt
```

Estado final esperado: `x1=10  x2=20  x3=30  x4=10  x5=10  x6=30  x7=30  x8=20  dmem[2]=30`

---

## Gerar a imagem para a FPGA

Na raiz do projeto, monte o programa de sua escolha e confira as imagens locais:

```powershell
python assembler/assembler.py --dump --output-dir quartus "caminho/meu_programa.asm"
python quartus/check_project.py
```

Abra `quartus/pl_top.qpf`, recompile para a DE2-115 e grave o novo bitstream.
Para receber o dump por UART, o programa precisa chegar ao fim do código do
usuário. Retire o laço de parada usado exclusivamente na simulação se ele
impedir chegar ao dump. O roteiro completo está em [Quartus](quartus/README.md)
e [dump UART](dump/DEMO_ETAPA03.md).

## Sintaxe e limites do assembly

- Aceita os mnemônicos do projeto, registradores `x0` a `x31` e aliases como
  `zero`, `ra` e `a0`. Imediatos podem ser decimais, hexadecimais ou binários.
- Aceita espaços, linhas vazias, comentários com `#`, `;` ou `//`, rótulos
  para branches/saltos e as pseudoinstruções `li`, `mv`, `nop`, `j` e `ret`.
  Desvios diretos também aceitam deslocamento numérico em bytes, múltiplo de 4.
- Aceita `.text`, `.globl` e `.global`. Seções de dados, relocação e outras
  diretivas ficam fora do formato deste montador.
- A ROM comporta 256 instruções de 32 bits. Com `--dump`, são até 127
  instruções de usuário após a expansão de pseudoinstruções. Esse modo ocupa
  parte da RAM (bytes `0x1E0–0x218`) e envia x1–x8 e RAM `0x000–0x07C`.
- Sem `--output-dir`, a montagem normal mantém a interface original e grava
  apenas `instruction.mif` e `program.hex` no diretório corrente.

---

## Detalhes de implementação

### Banco de registradores — escrita em negedge

A escrita no banco de registradores ocorre na **borda de descida** do clock (`negedge clk`). Isso resolve o conflito de leitura/escrita simultânea que ocorre quando, após um load-use stall, o estágio WB escreve um registrador no mesmo ciclo em que o estágio ID o lê para captura no registrador ID/EX. Com a escrita em negedge, o valor é garantidamente visível antes do próximo posedge. Esta é a solução descrita na Fig. 4.63 do P&H.

### Detecção de parada no testbench

O testbench identifica uma transferência de controle para o próprio endereço
e aguarda as escritas pendentes da CPU antes de mostrar o estado final.

### UART (9600 8N1)

O top `pl_top.sv` fornece 10 MHz à CPU e à UART. Nesse clock, o divisor de
`pl_mmio.sv` produz 9600 baud. O top alternativo `pl_top_no_pll.sv` opera a
50 MHz e requer ajuste do divisor para essa frequência. O sequenciador
`pl_mmio.sv` envia quatro bytes consecutivos por `sw` em `0x410`.

### Dump serial

A captura ao vivo usa `pyserial`. Selecione a porta da máquina, como `COM3`
no Windows ou `/dev/ttyUSB0` no Linux. Veja o [roteiro UART](dump/DEMO_ETAPA03.md).

---

## Recursos

- [Manual RISC-V ISA v2.2](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf)
- [RISC-V ISA Reference (msyksphinz)](https://msyksphinz-self.github.io/riscv-isadoc/html/rvi.html)
- [RISC-V Interpreter — Cornell University](https://www.cs.cornell.edu/courses/cs3410/2019sp/riscv/interpreter/)
- Patterson & Hennessy, *Computer Organization and Design: RISC-V Edition*, seções 4.6 – 4.10
