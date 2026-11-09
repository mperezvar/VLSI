# Ruta al proyecto original
ROOT ?= ../femtoRV

# Simulador
SIM ?= icarus

# Configuracion Cocotb
TOPLEVEL_LANG = verilog
TOPLEVEL = tb_cocotb
COCOTB_TEST_MODULES = test_rv32i

# Archivos Verilog originales
VERILOG_SOURCES = $(abspath tb_cocotb.v) \
    $(abspath $(ROOT)/OpenLane/src/femto.v) \
    $(abspath $(ROOT)/OpenLane/src/femtorv32_quark_un_irq.v) \
    $(abspath $(ROOT)/OpenLane/src/perip_uart.v) \
    $(abspath $(ROOT)/OpenLane/src/uart.v) \
    $(abspath $(ROOT)/OpenLane/src/perip_mult.v) \
    $(abspath $(ROOT)/OpenLane/src/mult.v) \
    $(abspath $(ROOT)/OpenLane/src/bram.v) \
    $(abspath $(ROOT)/OpenLane/src/MappedSPIFlash.v) \
    $(abspath $(ROOT)/OpenLane/src/MappedSPIRAM.v) \
    $(abspath $(ROOT)/cores/sim_spi_flash/spiflash.v) \
    $(abspath $(ROOT)/cores/sim_spi_ram/spiram.v)

# Opciones de compilacion Verilog
COMPILE_ARGS += -DBENCH -DSIM

# Firmware cargado en la SPI Flash
IMAGE ?= firmware_flash.hex
COCOTB_PLUSARGS += +firmware=$(IMAGE)

# Integracion con Cocotb
include $(shell cocotb-config --makefiles)/Makefile.sim


# Compilar el programa Assembly RISC-V
.PHONY: firmware

firmware:
	clang --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -nostdlib -fuse-ld=lld -Wl,--image-base=0 -Wl,-Ttext=0 -Wl,--no-relax -o program.elf program.S
	llvm-objcopy -O binary program.elf program.bin
	python3 bin_to_hex.py program.bin firmware_flash.hex
	python3 $(ROOT)/firmware/asm/fix_shift.py program.bin program_shifted.bin --bits 1 --dir right
	python3 bin_to_hex.py program_shifted.bin firmware_shifted.hex