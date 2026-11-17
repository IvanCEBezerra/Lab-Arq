# Proposta de demonstração interativa da ULA na DE2-115

**Estado:** ideia para a apresentação; **não implementada nem validada**. O `.sof` atual executa o programa integrado da etapa 3, transmite o dump UART de 164 bytes e acende LEDG ao final. Ele **não** lê as alavancas para selecionar operações. A captura física já aprovada (`rv32i_pipelined_base_project/etapa03_placa_01.bin` e `.txt`, código `c8ff0be`) deve ser preservada como demonstração principal e plano de reserva.

## O que mostrar

Usar SW como entrada de **dados e seleção de operação**, não como a codificação literal de uma instrução RV32I: a placa oferece 18 chaves, e a instrução tem 32 bits. Um programa carregado na memória de instruções lê as chaves via MMIO, escolhe a operação e executa a instrução R-type correspondente na ULA da CPU. Para cada execução, grava o resultado na RAM, mostra seus 18 bits baixos em LEDR e transmite o valor completo de 32 bits pela UART, para apresentação no terminal.

Interface proposta (a confirmar na simulação antes de usar na placa):

| Entrada/saída | Função |
| --- | --- |
| `SW[17:14]` | Seletor de operação, 0 a 9. |
| `SW[13:7]` | Operando A de 7 bits, estendido com sinal para 32 bits. |
| `SW[6:0]` | Operando B de 7 bits, estendido com sinal para 32 bits; para shifts, usar apenas seus 5 bits baixos como shamt. |
| `KEY[0]` | Reset já existente: reinicia o programa. |
| `KEY[1]` | Solicita uma execução; capturar SW uma vez por pressão e aguardar a liberação, para não emitir resultados repetidos enquanto a tecla estiver pressionada. |
| `LEDR[17:0]` | Bits baixos do resultado; não representam, sozinhos, o valor completo de 32 bits. |
| `LEDG[8:0]` | Indicação de estado opcional (pronto/transmitindo/seleção inválida); definir e testar o padrão antes da apresentação. |

Operações do seletor: `0=ADD`, `1=SUB`, `2=XOR`, `3=OR`, `4=AND`, `5=SLL`, `6=SRL`, `7=SRA`, `8=SLT`, `9=SLTU`. Valores `10` a `15` ficam reservados: não executar uma operação não definida; sinalizar seleção inválida. Para `SLT` e `SLTU`, destacar na fala a diferença entre comparação com e sem sinal. Para `SRA`, usar um A negativo em pelo menos um teste. Escolher os valores exatos das chaves e o oráculo antes de ensaiar.

## Caminho pelo processador

1. `LW` de `0x400` lê `SW`; `LW` de `0x404` lê `KEY` (`src/pl_mmio.sv:5-20,139-146`). O programa detecta a pressão de KEY[1], captura os operandos e a operação, e espera a liberação.
2. Uma sequência de branches seleciona a instrução aritmética/lógica R-type; `src/pl_alu_ctrl.sv:45-57` decodifica a operação e `src/pl_alu.sv:40-52` calcula o resultado no estágio EX. A operação selecionada é executada **pela CPU**, não calculada pelo computador que lê a serial.
3. `SW` armazena resultado e parâmetros em posições reservadas da RAM; outro `SW` em `0x408` atualiza LEDR (`src/pl_mmio.sv:150-163`). Definir endereços de RAM próprios da demo, fora de constantes auxiliares do programa.
4. `SW` em `0x410` envia uma palavra de 32 bits em quatro bytes little-endian. Antes de enviar outra palavra, aguardar `tx_busy` (bit 9 de `LW 0x410`) baixar (`src/pl_mmio.sv:10-15,69-109`). Protocolo sugerido: cinco palavras por execução — marcador de sincronização, código da operação, A, B e resultado (20 bytes). Um receptor novo no PC procura o marcador, decodifica as palavras e imprime operação, operandos e resultado em hexadecimal e decimal com/sem sinal.
5. Voltar a aguardar KEY[1]. Alterar SW sem pressionar a tecla não deve gerar nova mensagem. KEY[0] reinicia o programa; não presumir que o reset da CPU apague a RAM, pois a inicialização da memória ocorre na configuração da FPGA.

O atual `dump/serial_dump.py --check-etapa03` é **incompatível** com esse fluxo: ele espera exatamente as 41 palavras do teste fixo da etapa 3. Não mostrar os bytes binários no miniterm com filtro `printable` como se fossem texto; criar e testar um receptor para o protocolo da demo.

## Trabalho necessário antes de apresentar como funcional

- [ ] Criar o programa assembly da demo e o receptor serial, sem alterar `assembler/etapa03_test.asm`, os MIFs/HEXs aprovados da etapa 3 nem sua captura. Preferir arquivos/imagens e revisão de projeto Quartus próprios para a demo; documentar exatamente qual `.sof` está gravado na placa.
- [ ] Montar dentro do limite de 256 palavras de instrução e conferir as imagens de síntese e simulação. Verificar sintaxe/offsets no montador real (`assembler/assembler.py`); não presumir suporte a labels ou pseudoinstruções.
- [ ] Simular o processador completo: operações selecionadas, A negativo, shamt restrito, SLT versus SLTU, gravação na RAM/LEDR, enquadramento UART e uma única resposta por pressão de KEY[1]. Comparar os valores com um oráculo independente; montar o programa, por si só, não valida a CPU.
- [ ] Compilar no Quartus para `pl_top`/DE2-115, inspecionar pinagem efetiva, inicialização das memórias e timing, programar o novo `.sof`, testar fisicamente mais de uma operação e guardar captura bruta/relatório. O `.sof` comprovado da etapa 3 permanece disponível como reserva.
- [ ] Ensaiar troca entre demonstrações e o que dizer caso a demo interativa falhe. O enunciado (`instructions/projeto.pdf`, p. 7) exige explicar os grupos de instruções e demonstrar na FPGA; **não exige** uma interface interativa por alavancas. O teste da etapa 3 já capturado pode cumprir a parte física, com a ULA e as demais etapas explicadas pelo código e pelos testes.
