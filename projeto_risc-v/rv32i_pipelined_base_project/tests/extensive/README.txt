Testes arquiteturais extras (imagens isoladas)

Na raiz rv32i_pipelined_base_project:

  python3 tests/run_extensive.py

Com Icarus instalado, o script recompila o RTL, roda três programas no
processador real e confere registradores selecionados, todas as 256 palavras
RAM e visitas repetidas ao loop de parada. IVERILOG/VVP permitem apontar para
uma instalação local do simulador; o script não depende de Quartus.

Cada diretório tests/extensive/{alu,memory,control}/ contém:
  test.asm, program.hex (simulação), instruction.mif (síntese),
  data.hex, data.mif, expected_regs.hex, expected_data.hex.
Os MIFs são imagens de inicialização; um .sof só nasce de uma compilação
Quartus com o projeto e a placa DE2-115, e não foi gerado aqui.
Não copie esses arquivos sobre quartus/ ou modelsim/ sem guardar as imagens
já usadas na validação da placa. Um .sof antigo NÃO adota novos MIFs sozinho:
é preciso recompilar no Quartus e verificar pinagem, init e timing.

Para ModelSim Intel FPGA, depois de gerar as imagens, execute da pasta do
caso escolhido (não da raiz do projeto):

  vsim -c -do ../../extensive.do

Repita para alu, memory e control. Em Windows/PowerShell, entre na pasta do
caso com Set-Location antes de executar o comando. O testbench lê arquivos
relativos ao diretório de execução e não usa golden.txt legado. FATAL indica
falha; exija "PASS oracle" em cada um dos três casos.

Cobertura adicional: alu testa 28 registradores, sinais, deslocamentos 31,
limites imediatos e x0; memory testa extensão de sinais, lanes, meia-palavra,
forwarding e load-use; control testa branches tomados/não tomados, flush,
JAL/JALR, link, forwarding e máscara do bit 0. Não cobre acessos desalinhados,
instruções fora do subconjunto do enunciado nem comprova funcionamento físico.
