# Dúvidas para o professor

1. Para as instruções de memória da etapa 3, qual comportamento devemos implementar quando o endereço não estiver alinhado ao tamanho do acesso (por exemplo, `LH`/`SH` em endereço ímpar ou `LW`/`SW` fora de múltiplos de 4)? Devemos sinalizar erro, ignorar o acesso, ou implementar o acesso desalinhado, inclusive quando atravessar o limite entre duas palavras? Há casos de teste ou critérios de avaliação específicos para isso?

2. Para `JAL` e `JALR`, caso o destino não esteja alinhado a 4 bytes em uma implementação sem extensão C, é necessário implementar sinalização de exceção ou basta documentar que programas de teste devem usar destinos alinhados?

3. O TODO menciona um teste da etapa 3 “no mesmo formato do PDF”, mas não identifiquei um formato de teste no enunciado. Há um modelo obrigatório para o programa de teste e seus resultados esperados?
