# Limpeza do merge de `sync_changes` em `imprv`

O merge `202ba67` trouxe comentários atualizados em `pl_control.sv`, mas também duas implementações redundantes. Nesta revisão, mantivemos o caminho de hardware que já funcionava em `imprv` e removemos somente as duplicações:

| Arquivo | Localização no código atual | Alteração |
| --- | --- | --- |
| `rv32i_pipelined_base_project/src/pl_sign_ext.sv` | `41–45` | Removido o primeiro braço `JAL` duplicado no `case (Instr[6:0])`. O braço original permanece na linha 44 e continua gerando o imediato J. |
| `rv32i_pipelined_base_project/src/pl_datapath.sv` | `351–370` | Removido o bloco adicional que declarava e calculava `dmem_byte_en` e `dmem_wd`, sem conectá-los à memória. A escrita efetiva continua usando `ram_byte_enable` (linhas 355–361) e `ram_write_data` (linha 353), conectados a `pl_dmem` nas linhas 367 e 369. |
| `rv32i_pipelined_base_project/tests/test_stage3_wiring.py` | `9–18` | Adicionados testes estáticos de regressão: exatamente um braço `JAL` e apenas o caminho efetivo de máscara/dados para stores. Esses testes falharam antes da limpeza e passaram depois. |

Não mudamos a semântica de `JAL` nem de `SB/SH/SW`: os sinais removidos nunca alimentavam `pl_dmem`. As alterações de comentários/ordem das constantes em `pl_control.sv` foram preservadas.

## Verificação local

- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: 3 testes passaram.
- Icarus Verilog 12.0: `tests/run_etapa03.py` passou (registradores, RAM, branches, JAL e JALR); `tests/run_branches.py`: 23/23; `tests/run_memory_test.sh`: PASS; `pl_jumps_tb`, `pl_jalr_tb` e `pl_regression_tb`: PASS. O Icarus imprimiu avisos de seleção constante em `always_*` e de imagens HEX mais curtas que a memória, sem falha funcional nesses testes.
- O ModelSim não está instalado neste computador. Para verificar exatamente o commit publicado no outro PC, execute `vsim -c -do ../../tests/etapa03_modelsim.do` a partir de `rv32i_pipelined_base_project/modelsim/etapa03`, após `python3 tests/prepare_modelsim_etapa03.py` na raiz do subprojeto. Confirme também `git rev-parse --short HEAD` antes de enviar o log: um PASS sem revisão identificada não comprova qual commit foi testado.

A simulação não substitui síntese/timing no Quartus nem validação na FPGA; essas etapas permanecem pendentes em `instructions/TODO.md`.
