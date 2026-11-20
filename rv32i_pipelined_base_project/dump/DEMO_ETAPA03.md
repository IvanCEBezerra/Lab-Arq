# Demonstração na DE2-115

Na raiz do projeto, monte o exemplo e confira os arquivos de inicialização.

```powershell
python assembler/assembler.py --dump --output-dir quartus assembler/etapa03_test.asm
python quartus/check_project.py
```

Para demonstrar outro programa, troque o caminho do `.asm`. O código precisa
alcançar o ponto em que o montador anexa a rotina UART. Compile e grave o
bitstream conforme o [roteiro Quartus](../quartus/README.md).

Conecte a porta RS-232 da placa e execute a captura a 9600 baud. Use a porta
correspondente no computador e solte KEY[0] depois que a captura estiver pronta.
Para captura ao vivo, instale `pyserial` no Python usado.

```powershell
python dump/serial_dump.py COM3 --raw-out etapa03.bin --out etapa03.txt --check-etapa03
```

Use `--check-etapa03` com `assembler/etapa03_test.asm`. Para outro programa,
omita essa opção e confira manualmente o relatório. São exibidos o contador
de ciclos, x1–x8 e 32 palavras da RAM a partir do byte 0x000.
