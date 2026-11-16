Já feito
Etapas 1 e 2 validadas na placa (R-type, I-type, LUI, AUIPC).

Etapa 3: RTL integrado e testes Icarus concluídos para branches, jumps, loads e stores.
Pendente: reproduzir no ModelSim, compilar no Quartus e validar dump na placa.
Branches: BNE, BLT, BGE, BLTU, BGEU
Decodificar funct3 no estágio EX.
Trocar o teste zero por uma condição de comparação (igual, menor com sinal, menor sem sinal).
Manter o flush de 2 ciclos.
JAL e JALR
Adicionar o imediato J-type no pl_sign_ext.
Calcular o alvo: JAL = PC+imm; JALR = (rs1 adiantado + imm) com o bit 0 zerado.
Gravar PC+4 em rd.
Gerar flush ao saltar.
Loads: LB, LH, LBU, LHU
Usar o funct3 em ex_mem e addr[1:0] para selecionar o byte ou a meia-palavra.
Estender com sinal (LB, LH) ou com zero (LBU, LHU) antes do WB.
Não mexer no caminho do MMIO, que continua por palavra.
Stores: SB e SH
Alinhar o dado ao offset.
Dar escrita por byte na pl_dmem (máscara de bytes) apenas para a memória de dados.
O MMIO continua só com SW.
Teste
.asm da Etapa 3: assembler/etapa03_test.asm; resultados em tests/etapa03_esperado.md.
Simulação automatizada: tests/run_etapa03.py, tests/run_branches.py e tests/run_memory_test.sh.
Rodar no ModelSim (atualizar golden.txt) e depois na placa, com dump.
Entrega
Relatório no repositório: arquitetura, mudanças por etapa, resultados dos dumps.
Ensaiar a demo ao vivo e ter o .sof e os MIFs prontos.