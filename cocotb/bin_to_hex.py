from pathlib import Path
import sys

# Archivos
entrada = Path(
    sys.argv[1] if len(sys.argv) > 1 else "program.bin"
)

salida = Path(
    sys.argv[2] if len(sys.argv) > 2 else "firmware_flash.hex"
)

# Leer firmware
firmware = entrada.read_bytes()

# Verificar tamaño
if len(firmware) > 4096:
    raise ValueError(
        "El modelo original spiflash.v reserva 4096 bytes"
    )

# Completar memoria con 0xFF
firmware_completo = firmware.ljust(4096, b"\xff")

# Generar archivo hexadecimal
with open(salida, "w") as archivo:
    for byte in firmware_completo:
        archivo.write(f"{byte:02x}\n")

print(f"Imagen generada: {salida}")