# ModelSim — simulação da etapa 3

O arquivo `instructions/sim.pdf` é uma introdução à simulação de um multiplexador; não contém a configuração deste processador. A configuração específica está em `rv32i_pipelined_base_project/tests/etapa03_modelsim.do`.

## Preparação (terminal Linux)

O ModelSim/Questa deve estar instalado e seus comandos `vsim`, `vlib`, `vmap` e `vlog` acessíveis no PATH. A partir de `rv32i_pipelined_base_project/`:

    python3 tests/prepare_modelsim_etapa03.py
    cd modelsim/etapa03
    vsim -c -do ../../tests/etapa03_modelsim.do

Para abrir a interface gráfica e mantê-la aberta ao final:

    MODELSIM_GUI=1 vsim -do ../../tests/etapa03_modelsim.do

Na janela de transcrição deve aparecer `PASS etapa03 end-to-end assembled program` e nenhuma mensagem `FAIL`/`FATAL`. O arquivo `.do` cria a biblioteca `work`, compila `pl_pipe_pkg.sv` primeiro, depois os demais módulos necessários e `etapa03_tb.sv`, carrega o testbench e executa `run -all`. Para observar formas de onda na interface, após a primeira execução use `restart -f`, `add wave -r sim:/etapa03_tb/dut/*` e `run -all` na janela Transcript. Se `vsim` não estiver no PATH, use o executável da sua instalação sem mudar o diretório de trabalho.

O preparador monta `assembler/etapa03_test.asm`, acrescenta o laço de parada e gera `program.hex`/`data.hex` com 256 palavras em `modelsim/etapa03/`. As memórias usam `$readmemh` com caminhos relativos ao diretório de execução; **não** rode o `.do` de outro diretório sem antes fazer `cd modelsim/etapa03`. O testbench verifica valores finais dos registradores e da RAM, além de escritas indevidas em x14. Ele não usa nem modifica `modelsim/golden.txt`, que corresponde ao teste legado.

`modelsim/etapa03/` contém arquivos gerados e biblioteca de trabalho, ignorados pelo Git. O roteiro e as imagens foram verificados com Icarus Verilog; o ModelSim não estava instalado neste ambiente, portanto ainda é necessário executar os comandos acima na máquina que o possui e conferir a saída real.
