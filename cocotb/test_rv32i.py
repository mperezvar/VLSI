"""Prueba RV32I del femtoRV usando SPI Flash y SPI RAM originales."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge


# Resultados esperados del procesador
ESPERADO = [
    ("ADD", 13),
    ("SUB", 7),
    ("AND", 2),
    ("OR", 11),
    ("XOR", 9),

    ("SLL", 24),
    ("SRL", 1),
    ("SRA", 0xFFFFFFFE),

    ("SLT", 1),
    ("SLTU", 1),

    ("ADDI", 8),
    ("ANDI", 2),
    ("ORI", 11),
    ("XORI", 9),

    ("SLLI", 48),
    ("SRLI", 5),
    ("SRAI", 0xFFFFFFFC),

    ("SLTI", 1),
    ("SLTIU", 1),

    ("LUI", 0x12345000),
    ("AUIPC", 0x000000C4),

    ("SW/LW (SPI RAM)", 10),
    ("SB/LBU (SPI RAM)", 127),

    ("BEQ/BNE/BLT/BGE/BLTU/BGEU", 6),
    ("JAL", 7),
    ("JALR", 8),

    ("FIN", 0x55),
]


@cocotb.test()
async def probar_rv32i(dut):

    # 1. Inicializar entradas
    dut.resetn.value = 0
    dut.RXD.value = 1

    # 2. Generar reloj de 25 MHz
    cocotb.start_soon(
        Clock(dut.clk, 40, unit="ns").start()
    )

    # 3. Mantener reset durante cinco ciclos
    for _ in range(5):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.resetn.value = 1

    # 4. Comenzar las comprobaciones
    indice = 0

    for _ in range(250_000):

        await FallingEdge(dut.clk)

        # Esperar a que el procesador escriba un resultado
        # Leer la señal sin convertirla todavía a entero
        valido = str(dut.resultado_valido.value)

        # Detectar valores desconocidos
        if valido in ("X", "Z"):

            dut._log.error("¡Se detectó una señal desconocida!")

            # Mostrar las señales internas del procesador
            dut._log.info("PC          = %s", dut.uut.CPU.PC.value)
            dut._log.info("Instrucción = %s", dut.uut.CPU.instr.value)

            dut._log.info("mem_address = %s", dut.uut.mem_address.value)
            dut._log.info("mem_wmask   = %s", dut.uut.mem_wmask.value)
            dut._log.info("mem_wdata   = %s", dut.uut.mem_wdata.value)
            dut._log.info("mem_rdata   = %s", dut.uut.mem_rdata.value)

            # Mostrar las señales SPI Flash
            dut._log.info("SPI CS_N    = %s", dut.spi_cs_n.value)
            dut._log.info("SPI CLK     = %s", dut.spi_clk.value)
            dut._log.info("SPI MISO    = %s", dut.spi_miso.value)

            assert False, "El procesador presenta señales desconocidas"

        # Esperar hasta recibir un resultado
        if valido == "0":
            continue

        # Obtener el valor esperado
        nombre, esperado = ESPERADO[indice]

        # Leer el resultado del procesador
        obtenido = int(dut.resultado.value)

        # Comprobar el resultado
        assert obtenido == esperado, (
            f"{nombre}: esperado 0x{esperado:08X}, "
            f"recibido 0x{obtenido:08X}"
        )

        # Mostrar resultado correcto
        dut._log.info(
            "OK %-27s = 0x%08X",
            nombre,
            obtenido
        )

        # Pasar a la siguiente instrucción
        indice += 1

        # Finalizar cuando todas las pruebas pasen
        if indice == len(ESPERADO):
            dut._log.info(
                "PASS: %d comprobaciones RV32I",
                indice
            )
            return

    # Error si no llegaron todos los resultados
    assert False, (
        f"Tiempo agotado: {indice}/{len(ESPERADO)} resultados. "
        "Revisar SPI Flash / SPI RAM."
    )