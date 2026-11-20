# Demonstração na DE2-115

Na raiz do projeto, monte o exemplo e confira os arquivos de inicialização.

```powershell
python assembler/assembler.py --dump --output-dir quartus assembler/etapa03_test.asm
```

Para demonstrar outro programa, troque o caminho do `.asm`. O código precisa
alcançar o ponto em que o montador anexa a rotina UART. Compile e grave o
bitstream conforme o [roteiro Quartus](../quartus/README.md).

Conecte a porta RS-232 da placa e execute a captura a 9600 baud. Use a porta
correspondente no computador e solte KEY[0] depois que a captura estiver pronta.
Para captura ao vivo, instale `pyserial` no Python usado.

```powershell
python dump/serial_dump.py COM3 --out dump/etapa03.txt
```

Troque `COM3` pela porta da placa. Para o exemplo da etapa 3, confira os valores
abaixo no relatório. Para outro programa, compare com os resultados dele.

| Campo | Valor esperado (hex) |
| --- | --- |
| x1, x2 | FFFFFFFF, FFFFFFFF |
| x3, x4 | 000000FF, 00000080 |
| x5, x6 | FFFF80FF, 000080FF |
| x7, x8 | 008080FF, 0000005C |
| RAM 0x000, 0x004, 0x008, 0x00C, 0x010 | 008080FF, 0000005C, 00000070, 00000007, 008080FF |
| RAM 0x014–0x07C | 00000000 em cada palavra |
