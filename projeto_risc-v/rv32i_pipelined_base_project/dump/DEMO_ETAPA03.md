# Etapa 3 — captura e demonstração (procedimento, não evidência física)

**Estado:** sem DE2-115 neste ambiente: nenhum `.sof` foi gravado, nenhum dump UART real foi capturado e a etapa 3 **não** está validada na placa. O teste offline é só uma fixture determinística. A montagem/ModelSim não substitui síntese, timing ou execução física.

## Antes da sessão

1. No Quartus, criar/configurar o projeto para DE2-115 EP4CE115F29C7 com `src/pl_top.sv` como top (PLL 50→10 MHz), incluir os demais `src/*.sv`, o módulo/IP `pll_10mhz`, as atribuições de `quartus/add_to_qsf.txt` e `quartus/pl_top.sdc`. Confirmar pinos da placa e compilação da PLL. **Não** usar `pl_top_no_pll.sv` com UART configurada para 10 MHz (`src/pl_mmio.sv`).
2. Incluir como imagens efetivamente resolvidas pelo Quartus `mifs/etapa03_fpga/instruction.mif` e `mifs/etapa03_fpga/data.mif` sob os nomes `instruction.mif`/`data.mif` referidos por `src/pl_imem.sv`/`src/pl_dmem.sv`; verificar nos relatórios de compilação a inicialização das duas memórias e o timing. Não basta copiá-los ao diretório errado. O arquivo de instruções existente contém 34 instruções do usuário (0x000–0x021), salto em 0x022 e dump em 0x080–0x0AD; o MIF de dados existente inicializa os 32 primeiros words em zero. Atenção: o MIF versionado reserva saves em 0x078–0x07F (bytes 0x1E0–0x1FC); `assembler/assembler.py` atual também usa `SAVES_WBASE=0x78` (0x1E0), mas contém comentários antigos que citam 0x1C8. Confie nos valores codificados e nas imagens efetivamente compiladas, não nesses comentários; não misture MIFs de builds distintos.
3. Preparar `.sof` **gerado nesta configuração**, verificar chip/cabo no Quartus Programmer e programar por JTAG. Registrar versão/hash dos dois MIFs, nome do `.sof`, relatório de timing, data e identificação da placa. Antes da captura, conectar a RS-232 da DE2-115 ao adaptador/porta serial correta (não o conector JTAG), confirmar TXD→RX do host, GND comum, e 9600 8N1 sem controle de fluxo; usar cabo/adaptador compatível com RS-232 da placa, não ligar TXD TTL diretamente a níveis RS-232. Garantir permissão de acesso à porta. Instalar `python3 -m pip install pyserial` no Python usado para captura.

## Captura ao vivo

Executar da raiz `rv32i_pipelined_base_project/`, substituindo a porta real e usando **novos nomes** por tentativa:

```sh
python3 dump/serial_dump.py /dev/ttyUSB0 --baud 9600 --timeout 10 \
  --raw-out dump/etapa03_placa_01.bin --out dump/etapa03_placa_01.txt --check-etapa03
```

Iniciar o comando **antes** de pressionar e soltar KEY[0] (reset ativo-baixo; liberação depende da PLL). A captura limpa o buffer de entrada ao abrir a porta; só depois do aviso “Aguardando dados” acionar KEY[0]. A ferramenta lê 164 bytes, salva o binário bruto **sem sobrescrever** (`--raw-out` obrigatório na captura), produz relatório textual e retorna código 0 somente se x1–x8 e as 32 palavras de RAM conferirem. Em caso de erro, guardar a evidência original e usar nomes novos para repetir. `--timeout` é o tempo máximo *sem novos bytes*, não tempo total. Se houver timeout, cabo/pinagem/baud/reset/imagem/PLL devem ser conferidos; dump parcial não é aceito como sucesso. LEDG[8:0] acende após o envio (sinal auxiliar, não substitui a comparação).

Comparação posterior sem porta nem pyserial:

```sh
python3 dump/serial_dump.py --input dump/etapa03_placa_01.bin \
  --out dump/etapa03_conferencia_01.txt --check-etapa03
```

O binário deve ter **exatamente 164 bytes** (41 palavras little-endian): ciclos nos bytes 0–3, x1–x8 nos bytes 4–35, RAM 0x000–0x07C nos bytes 36–163. O contador de ciclos é exibido mas não comparado (varia entre execuções). Esperados em `tests/etapa03_esperado.md`: x1/x2=FFFFFFFF, x3=000000FF, x4=00000080, x5=FFFF80FF, x6=000080FF, x7=008080FF, x8=0000005C; RAM 0x000=008080FF, 0x004=0000005C, 0x008=00000070, 0x00C=00000007, 0x010=008080FF, e os outros 27 words de 0x014–0x07C=0 (imagem de dados inicializada em zero e programa não os altera). O comparador imprime cada divergência e sai com código não zero; não faz sincronização por framing/checksum: ruído, bytes antigos, truncamento ou fluxo extra podem invalidar a interpretação. Confirme também arquivo/versão/porta corretos antes de declarar validação.

## Roteiro curto da apresentação

1. Mostrar código das instruções dos grupos da etapa 3 e os resultados de simulação já registrados; indicar que simulação e placa são evidências distintas.
2. Mostrar configuração do Quartus: top, dispositivo, PLL, MIFs realmente associados, resultado de compilação/timing e `.sof` resultante. Programar a placa e apresentar a conexão RS-232.
3. Abrir a captura com nomes novos, pressionar/soltar KEY[0] e aguardar 164/164 bytes; apresentar o arquivo `.bin`, o relatório, os valores e o código de saída da comparação. Mostrar LEDG apenas como confirmação visual auxiliar.
4. Explicar little-endian, contador de ciclos variável, comparação de x1–x8 e RAM inteira. Explicar limites: x11/x15 e ausência de escrita especulativa em x14 não são enviados, permanecem evidência da simulação; a captura não observa diretamente todos os registradores nem substitui a inspeção de timing. Conservar binário original e artefatos do build na evidência da equipe.

Teste offline reproduzível, sem placa e sem pyserial:

```sh
python3 -m unittest discover -s dump -p 'test_serial_dump.py' -v
```

O teste constrói 164 bytes sintéticos em memória, verifica caso esperado, mutações em cada um dos 40 words observáveis, contador variável, tamanho inválido e códigos de saída da CLI. **Nunca apresentar a fixture como dump físico.**
