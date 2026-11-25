
/* Pruebas RV32I + transmision UART */

.section .text
.globl _start

/* Registrar el resultado y transmitirlo */
.macro REPORTAR
    sw x3, 8(x20)
    jal x19, enviar_palabra
.endm

_start:
    /* NOP para compensar el arranque SPI */
    nop
    nop
    nop
    nop

    /* Direcciones base */
    lui x20, 0x400       /* UART:    0x00400000 */
    lui x21, 0x10        /* SPI RAM: 0x00010000 */

    /* Operand​os */
    addi x1, x0, 10
    addi x2, x0, 3

    /* ===== ARITMETICA Y LOGICA ===== */

    add x3, x1, x2
    REPORTAR

    sub x3, x1, x2
    REPORTAR

    and x3, x1, x2
    REPORTAR

    or x3, x1, x2
    REPORTAR

    xor x3, x1, x2
    REPORTAR

    /* ===== DESPLAZAMIENTOS ===== */

    sll x3, x2, x2
    REPORTAR

    srl x3, x1, x2
    REPORTAR

    addi x4, x0, -16

    sra x3, x4, x2
    REPORTAR

    /* ===== COMPARACIONES ===== */

    slt x3, x2, x1
    REPORTAR

    sltu x3, x2, x1
    REPORTAR

    /* ===== INMEDIATOS ===== */

    addi x3, x1, -2
    REPORTAR

    andi x3, x1, 6
    REPORTAR

    ori x3, x2, 8
    REPORTAR

    xori x3, x1, 3
    REPORTAR

    slli x3, x2, 4
    REPORTAR

    srli x3, x1, 1
    REPORTAR

    srai x3, x4, 2
    REPORTAR

    slti x3, x2, 10
    REPORTAR

    sltiu x3, x2, 10
    REPORTAR

    /* ===== LUI Y AUIPC ===== */

    lui x3, 0x12345
    REPORTAR

    auipc x3, 0
    REPORTAR

    /* ===== SPI RAM ===== */

    /* Escritura y lectura de palabra */
    sw x1, 0(x21)
    lw x3, 0(x21)
    REPORTAR

    /* Escritura y lectura de byte */
    addi x3, x0, 127
    sb x3, 4(x21)
    lbu x3, 4(x21)
    REPORTAR

    /* ===== SALTOS CONDICIONALES ===== */

    addi x3, x0, 0

    beq x1, x1, beq_ok
    addi x3, x0, 99

beq_ok:
    addi x3, x3, 1

    bne x1, x2, bne_ok
    addi x3, x0, 99

bne_ok:
    addi x3, x3, 1

    blt x2, x1, blt_ok
    addi x3, x0, 99

blt_ok:
    addi x3, x3, 1

    bge x1, x2, bge_ok
    addi x3, x0, 99

bge_ok:
    addi x3, x3, 1

    bltu x2, x1, bltu_ok
    addi x3, x0, 99

bltu_ok:
    addi x3, x3, 1

    bgeu x1, x2, bgeu_ok
    addi x3, x0, 99

bgeu_ok:
    addi x3, x3, 1
    REPORTAR

    /* ===== JAL ===== */

    jal x0, jal_ok
    addi x3, x0, 99

jal_ok:
    addi x3, x3, 1
    REPORTAR

    /* ===== JALR ===== */

    lui x18, %hi(jalr_ok)
    addi x18, x18, %lo(jalr_ok)

    jalr x0, 0(x18)
    addi x3, x0, 99

jalr_ok:
    addi x3, x3, 1
    REPORTAR

    /* ===== FINALIZACION ===== */

    addi x3, x0, 0x55
    REPORTAR

fin:
    jal x0, fin


/* =========================================
   RUTINA DE TRANSMISION UART

   Entrada:
       x3 = palabra de 32 bits

   Salida:
       4 bytes por UART, little-endian

   Registros utilizados:
       x19 = direccion de retorno
       x22 = copia del resultado
       x23 = contador de bytes
       x24 = control UART
       x25 = estado UART

   x3 permanece sin modificar.
   ========================================= */

enviar_palabra:

    addi x22, x3, 0
    addi x23, x0, 4

siguiente_byte:

    /* Cargar el dato a transmitir */
    sw x22, 8(x20)

    /* Activar tx_wr (bit 3 del control) */
    addi x24, x0, 8
    sw x24, 16(x20)

esperar_inicio:

    /* Esperar tx_busy = 1 (bit 9) */
    lw x25, 16(x20)
    andi x25, x25, 512
    beq x25, x0, esperar_inicio

    /* Desactivar tx_wr para evitar reenvios */
    sw x0, 16(x20)

esperar_fin:

    /* Esperar tx_busy = 0 */
    lw x25, 16(x20)
    andi x25, x25, 512
    bne x25, x0, esperar_fin

    /* Preparar el siguiente byte */
    srli x22, x22, 8
    addi x23, x23, -1
    bne x23, x0, siguiente_byte

    /* Volver al programa */
    jalr x0, 0(x19)
