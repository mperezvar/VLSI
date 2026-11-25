
"""Verificación RV32I, bus de memoria y UART."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import (
    Event,
    RisingEdge,
    FallingEdge,
    Timer,
    with_timeout,
)


# Resultados esperados
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
    ("AUIPC", 0x00000114),

    ("SW/LW (SPI RAM)", 10),
    ("SB/LBU (SPI RAM)", 127),

    ("BEQ/BNE/BLT/BGE/BLTU/BGEU", 6),
    ("JAL", 7),
    ("JALR", 8),

    ("FIN", 0x55),
]


# Temporización UART
# El reloj simulado es 25 MHz (40 ns).
# femto.v configura la UART para 27 MHz y 115200 baudios.
# El divisor implementado en uart.v produce 208 ciclos por bit.

PERIODO_RELOJ_NS = 40
CICLOS_POR_BIT = (27_000_000 // 115_200 // 16 - 1) * 16
TIEMPO_BIT_NS = PERIODO_RELOJ_NS * CICLOS_POR_BIT


async def recibir_uart(dut, bytes_recibidos, evento_byte):
    """Recibe bytes desde TXD, formato UART 8N1."""

    while True:

        # Esperar el bit de inicio (transición 1 -> 0)
        await FallingEdge(dut.TXD)

        # Esperar hasta el centro del primer bit de datos
        await Timer(3 * TIEMPO_BIT_NS // 2, unit="ns")

        dato = 0

        # Leer 8 bits, primero el menos significativo
        for bit in range(8):
            valor_bit = int(dut.TXD.value)
            dato |= valor_bit << bit

            await Timer(TIEMPO_BIT_NS, unit="ns")

        # Verificar bit de parada
        assert int(dut.TXD.value) == 1, (
            "UART: bit de parada incorrecto"
        )

        bytes_recibidos.append(dato)
        evento_byte.set()


async def verificar_escritura(dut):
    """Comprueba una escritura al registro de datos UART."""

    # Esperar el inicio de una escritura en 0x00400008
    await with_timeout(
        RisingEdge(dut.resultado_valido),
        30,
        "ms"
    )

    # Permitir que las señales se estabilicen
    await Timer(1, unit="ns")

    direccion = int(dut.uut.mem_address.value)
    mascara = int(dut.uut.mem_wmask.value)
    dato = int(dut.uut.mem_wdata.value)

    # Verificar la dirección
    assert direccion == 0x00400008, (
        f"Dirección incorrecta: 0x{direccion:08X}"
    )

    # Verificar escritura de palabra completa
    assert mascara == 0b1111, (
        f"Máscara de escritura incorrecta: {mascara:04b}"
    )

    return dato


@cocotb.test()
async def probar_rv32i(dut):

    # ==============================
    # 1. INICIALIZACIÓN
    # ==============================

    dut.resetn.value = 0
    dut.RXD.value = 1

    cocotb.start_soon(
        Clock(
            dut.clk,
            PERIODO_RELOJ_NS,
            unit="ns"
        ).start()
    )

    # Iniciar receptor UART en paralelo
    bytes_recibidos = []
    evento_byte = Event()

    receptor = cocotb.start_soon(
        recibir_uart(dut, bytes_recibidos, evento_byte)
    )

    # Reset durante cinco ciclos
    for _ in range(5):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.resetn.value = 1

    # ==============================
    # 2. VERIFICACIÓN DEL BUS
    # ==============================

    esperado_uart = []

    for nombre, esperado in ESPERADO:

        # REPORTAR escribe primero el resultado completo
        palabra = await verificar_escritura(dut)

        assert palabra == esperado, (
            f"{nombre}: bus incorrecto. "
            f"Esperado 0x{esperado:08X}, "
            f"recibido 0x{palabra:08X}"
        )

        # Después enviar_palabra escribe cuatro bytes
        for posicion in range(4):

            desplazado = (
                esperado >> (8 * posicion)
            ) & 0xFFFFFFFF

            dato_bus = await verificar_escritura(dut)

            assert dato_bus == desplazado, (
                f"{nombre}, byte {posicion}: "
                f"bus=0x{dato_bus:08X}, "
                f"esperado=0x{desplazado:08X}"
            )

            # Solo los ocho bits inferiores se transmiten
            esperado_uart.append(desplazado & 0xFF)

        dut._log.info(
            "OK BUS %-27s = 0x%08X",
            nombre,
            palabra
        )

    # ==============================
    # 3. VERIFICACIÓN DE UART
    # ==============================

    # Esperar a recibir todos los bytes por TXD
    while len(bytes_recibidos) < len(esperado_uart):

        await with_timeout(
            evento_byte.wait(),
            30,
            "ms"
        )

        evento_byte.clear()

    # Verificar cantidad de bytes
    assert len(bytes_recibidos) == len(esperado_uart), (
        "Cantidad incorrecta de bytes UART"
    )

    # Comparar cada byte transmitido
    for indice, (obtenido, esperado) in enumerate(
        zip(bytes_recibidos, esperado_uart)
    ):

        assert obtenido == esperado, (
            f"UART byte {indice}: "
            f"recibido 0x{obtenido:02X}, "
            f"esperado 0x{esperado:02X}"
        )

    # ==============================
    # 4. RESULTADO FINAL
    # ==============================

    receptor.cancel()

    dut._log.info(
        "PASS: %d resultados RV32I, "
        "%d bytes UART verificados",
        len(ESPERADO),
        len(bytes_recibidos)
    )
