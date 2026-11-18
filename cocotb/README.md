# Verificación del procesador FemtoRV con Cocotb (RV32I)

Esta carpeta contiene una prueba independiente del proyecto **VLSI** para verificar instrucciones básicas del procesador **FemtoRV RV32I** mediante **Cocotb 2.1.0 e Icarus Verilog**.

El test utiliza **el RTL original del proyecto** y los modelos de memoria incluidos en `femtoRV/cores`:

- `femtoRV/cores/sim_spi_flash/spiflash.v`: proporciona las instrucciones del programa.
- `femtoRV/cores/sim_spi_ram/spiram.v`: modela la memoria de datos.
- `femtoRV/OpenLane/src/MappedSPIFlash.v` y `MappedSPIRAM.v`: controladores SPI del SoC.

**Importante:** este flujo no modifica `femtoRV/Makefile` ni sustituye `make sim` del profesor. Todo se ejecuta **dentro de `VLSI/cocotb/`**.

## 1. Estructura de carpetas

```text
VLSI/
├── femtoRV/
│   ├── Makefile                   # Flujo original (no modificar)
│   ├── OpenLane/src/             # SoC, CPU, periféricos y controladores SPI
│   ├── cores/
│   │   ├── sim_spi_flash/spiflash.v
│   │   └── sim_spi_ram/spiram.v
│   └── firmware/asm/fix_shift.py
└── cocotb/
    ├── Makefile                   # Flujo independiente de Cocotb
    ├── test_rv32i.py              # Prueba en Python
    ├── tb_cocotb.v                # Testbench de conexión Verilog
    ├── program.S                  # Firmware Assembly RV32I (con cuatro NOP)
    ├── bin_to_hex.py              # Convierte BIN a HEX para $readmemh
    ├── firmware_flash.hex         # Se genera con make firmware
    ├── firmware_shifted.hex       # Imagen alternativa con corrimiento
    ├── README.md                  # Este documento
    └── .venv/                     # Entorno local de Python (no subir a Git)
```

Los archivos `program.elf`, `program.bin`, `program_shifted.bin`, `sim_build/`, `results.xml` y `cocotb_femto.vcd` se generan durante la compilación y simulación.

## 2. Requisitos

Probado por el equipo en **Linux**, con las siguientes versiones presentes en la ejecución exitosa:

| Herramienta | Para qué sirve | Versión de la ejecución exitosa |
|---|---|---|
| Python | Ejecutar Cocotb y las utilidades | 3.14.0 |
| Cocotb | Controlar y verificar la simulación desde Python | 2.1.0 |
| Icarus Verilog (`iverilog` / `vvp`) | Compilar y simular el RTL | 12.0 |
| Clang + LLD | Compilar y enlazar `program.S` para RV32I | Sin versión fijada |
| LLVM (`llvm-objcopy`) | Convertir ELF a binario | Sin versión fijada |
| GNU Make | Ejecutar `make firmware` y `make sim` | Sin versión fijada |
| GTKWave | Consultar las señales del archivo VCD | Opcional |

No se necesitan OpenLane, Yosys ni una placa física para **esta prueba de simulación**.

### 2.1. Instalar herramientas de sistema (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install -y make iverilog gtkwave clang lld llvm python3 python3-pip python3-venv
```

Comprueba que todos los programas principales existen:

```bash
python3 --version
iverilog -V
vvp -V
clang --version
ld.lld --version
llvm-objcopy --version
make --version
```

> En algunas distribuciones los ejecutables LLVM tienen un sufijo, como `llvm-objcopy-19`. Si `llvm-objcopy` no existe, busca el nombre disponible con `ls /usr/bin/llvm-objcopy*` y úsalo en el Makefile.

### 2.2. Crear y activar el entorno virtual

Desde la carpeta `cocotb`:

```bash
cd ~/VLSI/cocotb
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install 'cocotb==2.1.0'
```

Verifica la instalación:

```bash
python --version
python -m pip show cocotb
cocotb-config --version
cocotb-config --makefiles
```

El comando `cocotb-config --makefiles` debe mostrar la carpeta donde Cocotb guarda `Makefile.sim`.

**Cada vez que abras una terminal nueva:**

```bash
cd ~/VLSI/cocotb
source .venv/bin/activate
```

Si no estás usando exactamente la ruta `~/VLSI/cocotb`, entra en la ubicación real de tu copia.

## 3. Verificar el Makefile de Cocotb

En `VLSI/cocotb/Makefile` debe figurar lo siguiente:

```makefile
ROOT ?= ../femtoRV
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = tb_cocotb
COCOTB_TEST_MODULES = test_rv32i

# Permite importar test_rv32i.py desde esta carpeta.
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

# Debe mantener la lista de archivos RTL del diseño y modelos SPI.
# VERILOG_SOURCES = ...
COMPILE_ARGS += -DBENCH -DSIM

IMAGE ?= firmware_flash.hex
COCOTB_PLUSARGS += +firmware=$(IMAGE)

include $(shell cocotb-config --makefiles)/Makefile.sim
```

**Advertencia:** este es el fragmento de configuración, **no un Makefile completo**. Conserva la variable `VERILOG_SOURCES` del Makefile de la prueba, con el `tb_cocotb.v`, los módulos `OpenLane/src/*.v` necesarios y los dos modelos `cores/sim_spi_*/`.

Ten en cuenta estas correcciones importantes:

- Para Cocotb 2.x usa `COCOTB_TEST_MODULES = test_rv32i` (sin extensión `.py`) en lugar del nombre antiguo `MODULE`.
- Para pasar `+firmware=...` a **`vvp`**, usa `COCOTB_PLUSARGS`, **no** `SIM_ARGS`: el argumento debe aparecer **después** de `sim_build/sim.vvp`.
- Mantén `ROOT ?= ../femtoRV` cuando las carpetas `cocotb/` y `femtoRV/` sean hermanas.
- `test_rv32i.py` debe llamarse **exactamente así**, con el mismo nombre definido en `COCOTB_TEST_MODULES`.

### 3.1. Comandos para compilar el firmware

La regla `firmware` del Makefile debe ejecutar los siguientes comandos, **cada uno en su propia línea con una tabulación al inicio**:

```makefile
.PHONY: firmware
firmware:
	clang --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -nostdlib -fuse-ld=lld -Wl,--image-base=0 -Wl,-Ttext=0 -Wl,--no-relax -o program.elf program.S
	llvm-objcopy -O binary program.elf program.bin
	python3 bin_to_hex.py program.bin firmware_flash.hex
	python3 $(ROOT)/firmware/asm/fix_shift.py program.bin program_shifted.bin --bits 1 --dir right
	python3 bin_to_hex.py program_shifted.bin firmware_shifted.hex
```

Las opciones `-fuse-ld=lld` y `-Wl,--image-base=0` se requieren en esta configuración para enlazar correctamente el firmware y ubicar el código desde la dirección `0x00000000`.

**Nota sobre el corrimiento:** `firmware_shifted.hex` es una imagen alternativa creada mediante `fix_shift.py`. La prueba que obtuvo `PASS` usó **`firmware_flash.hex` sin ese corrimiento**, pero con cuatro `nop` iniciales. El uso de la imagen desplazada debe comprobarse por separado; no se garantiza que pase automáticamente.

## 4. Compilar el programa Assembly

Desde `VLSI/cocotb/` con el entorno virtual activado:

```bash
make firmware
```

Comprueba que se generaron los archivos:

```bash
ls -lh program.elf program.bin program_shifted.bin firmware_flash.hex firmware_shifted.hex
```

El `program.S` de la prueba exitosa comienza con **cuatro instrucciones `nop`** antes de `lui x20, 0x400`. En esta versión, la comprobación de `AUIPC` en `test_rv32i.py` debe esperar `0x000000C4`:

```python
("AUIPC", 0x000000C4),
```

Sin los `nop`, la primera instrucción de inicialización puede perderse durante el arranque SPI simulado y producir valores `X` en las direcciones de memoria. Los `nop` compensaron ese síntoma en la prueba; **no corrigen el RTL del controlador SPI**.

Si editas `program.S`, ejecuta nuevamente `make firmware` antes de simular. En particular, si agregas o eliminas instrucciones antes de `AUIPC`, su dirección y el resultado esperado pueden cambiar.

## 5. Ejecutar Cocotb

Ejecuta el test desde la carpeta **independiente**:

```bash
cd ~/VLSI/cocotb
source .venv/bin/activate
make sim
```

El Makefile de Cocotb invoca Icarus Verilog para compilar el SoC y los modelos de las memorias SPI; después inicia `vvp` y ejecuta la función `probar_rv32i` definida en `test_rv32i.py`.

En una ejecución exitosa debes ver líneas de este estilo:

```text
OK ADD                         = 0x0000000D
OK SUB                         = 0x00000007
...
OK AUIPC                       = 0x000000C4
OK SW/LW (SPI RAM)             = 0x0000000A
OK SB/LBU (SPI RAM)            = 0x0000007F
...
OK FIN                         = 0x00000055
PASS: 27 comprobaciones RV32I
TESTS=1 PASS=1 FAIL=0 SKIP=0
```

**Resultado ya obtenido en el proyecto:** 27 comprobaciones exitosas en **671740 ns de simulación** utilizando `firmware_flash.hex`. Es un resultado de esta secuencia de pruebas, **no** una demostración exhaustiva de todas las instrucciones y casos límite de RV32I.

Para probar la imagen predesplazada de forma independiente:

```bash
make sim IMAGE=firmware_shifted.hex
```

## 6. ¿Qué señales controla y comprueba Cocotb?

El script `test_rv32i.py` **controla** directamente:

| Señal | Función |
|---|---|
| `clk` | Reloj de período 40 ns (25 MHz) |
| `resetn` | Reset activo en bajo; se libera después de 5 ciclos |
| `RXD` | Entrada UART mantenida en alto (reposo) |

Y **observa** principalmente:

| Señal | Función |
|---|---|
| `resultado_valido` | Se activa cuando la CPU intenta escribir en `0x00400008` |
| `resultado[31:0]` | Datos que la CPU escribe (`mem_wdata`) |

La lógica de observación está en `tb_cocotb.v`:

```verilog
wire resultado_valido = uut.wr && (uut.mem_address == 32'h00400008);
wire [31:0] resultado = uut.mem_wdata;
```

El programa Assembly calcula cada resultado y lo comunica mediante `sw x3, 8(x20)`. Cocotb compara los valores recibidos, en orden, con la lista `ESPERADO`.

Las **27 comprobaciones** abarcan aritmética, lógica, desplazamientos, comparaciones, inmediatos, `LUI`, `AUIPC`, accesos a SPI RAM y saltos (`BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `JAL` y `JALR`). Las seis ramas condicionales comparten una comprobación acumulada.

## 7. Ver señales en GTKWave

El testbench crea el archivo `cocotb_femto.vcd` mediante `$dumpfile` y `$dumpvars`.

```bash
gtkwave cocotb_femto.vcd
```

Señales útiles para examinar:

```text
tb_cocotb.clk
tb_cocotb.resetn
tb_cocotb.resultado_valido
tb_cocotb.resultado
tb_cocotb.spi_cs_n
tb_cocotb.spi_clk
tb_cocotb.spi_mosi
tb_cocotb.spi_miso
tb_cocotb.spi_cs_n_ram
tb_cocotb.spi_clk_ram
tb_cocotb.spi_mosi_ram
tb_cocotb.spi_miso_ram
tb_cocotb.uut.mem_address
tb_cocotb.uut.mem_wdata
tb_cocotb.uut.mem_wmask
```

Si guardaste una configuración `test_rv32i.gtkw` en la carpeta, también puedes abrirla en GTKWave junto con el VCD.

## 8. Solución de errores frecuentes

| Mensaje o síntoma | Causa habitual | Solución |
|---|---|---|
| `no se reconoce el modo de emulación: elf32lriscv` | Clang está llamando al enlazador x86 | Instalar `lld` y añadir `-fuse-ld=lld` |
| `section '.text' address ... smaller than image base` | LLD usa otra dirección base | Añadir `-Wl,--image-base=0` |
| `FileNotFoundError: program.bin` | Falta convertir ELF a BIN | Agregar `llvm-objcopy -O binary program.elf program.bin` |
| `llvm-objcopy: command not found` | Herramienta no instalada o versionada | Instalar `llvm` y revisar `ls /usr/bin/llvm-objcopy*` |
| `+firmware=...: Unable to open input file` | `vvp` recibe el `+firmware` antes del `.vvp` | Cambiar `SIM_ARGS` por `COCOTB_PLUSARGS` |
| `No module named 'test_rv32i'` | El archivo Python tiene otro nombre o no está en la ruta | Comprobar `ls test_rv32i.py` y `COCOTB_TEST_MODULES` |
| `Cannot convert Logic('X') to int` | Se está observando una señal desconocida del RTL | Revisar VCD, reset, lectura SPI y cuatro `nop` iniciales |
| Falla solo `AUIPC` | Cambió la dirección de esa instrucción | Revisar su posición en Assembly y actualizar el esperado |
| `cocotb-config: command not found` | No está activo el entorno virtual o falta Cocotb | `source .venv/bin/activate` y comprobar la instalación |
| Cocotb no recibe resultados | El procesador no está realizando las escrituras previstas | Revisar firmware seleccionado, señales SPI y dirección `0x00400008` |

Para verificar la importación del módulo Python sin iniciar la simulación:

```bash
python -c 'import test_rv32i; print(test_rv32i.__file__)'
```

Para revisar qué va a ejecutar Make sin correr realmente las reglas:

```bash
make -n firmware
make -n sim
```

## 9. Archivos que no conviene subir a GitHub

En `cocotb/.gitignore` puedes incluir:

```gitignore
.venv/
__pycache__/
*.pyc
sim_build/
results.xml
*.vcd
*.fst
*.elf
*.bin
*.log
```

Se recomienda subir los **fuentes** (`Makefile`, `test_rv32i.py`, `tb_cocotb.v`, `program.S`, `bin_to_hex.py`, `README.md`) y, si se desea facilitar la reproducción sin compilar Assembly, las imágenes `.hex` pequeñas. Evita publicar las carpetas del entorno virtual y los archivos temporales de simulación.

## 10. Lista de verificación rápida

- [ ] Estoy dentro de `VLSI/cocotb/`, no de `VLSI/femtoRV/`.
- [ ] Existe la carpeta hermana `../femtoRV/` con el RTL y los modelos SPI.
- [ ] Están instalados `iverilog`, `vvp`, `clang`, `ld.lld`, `llvm-objcopy` y `make`.
- [ ] Activé `.venv` e instalé Cocotb 2.1.0.
- [ ] `COCOTB_TEST_MODULES = test_rv32i` coincide con el nombre del `.py`.
- [ ] El Makefile usa `COCOTB_PLUSARGS += +firmware=$(IMAGE)`.
- [ ] El Assembly incluye los cuatro `nop` iniciales.
- [ ] `test_rv32i.py` espera `AUIPC = 0x000000C4` para este firmware.
- [ ] `make firmware` genera `program.bin` y `firmware_flash.hex`.
- [ ] `make sim` termina con `PASS: 27 comprobaciones RV32I`.
- [ ] Puedo abrir `cocotb_femto.vcd` en GTKWave (opcional).

## Referencias

- Documentación oficial de Cocotb: <https://docs.cocotb.org/en/stable/>
- Instalación: <https://docs.cocotb.org/en/stable/install.html>
- Uso de Makefiles: <https://docs.cocotb.org/en/stable/building.html>
- Guía básica: <https://docs.cocotb.org/en/stable/first_steps.html>
- Repositorio personal: <https://github.com/mperezvar/VLSI>
