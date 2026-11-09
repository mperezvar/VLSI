/* Programa de prueba RV32I */

.section .text
.globl _start

_start:
    /* Instrucciones dummy para el arranque SPI */
    nop
    nop
    nop
    nop

    /* Direcciones */
    lui x20, 0x400       /* UART: 0x00400000 */
    lui x21, 0x10        /* SPI RAM: 0x00010000 */

    /* Valores iniciales */
    addi x1, x0, 10
    addi x2, x0, 3


    /* ================================= */
    /* OPERACIONES ARITMETICAS Y LOGICAS */
    /* ================================= */

    add x3, x1, x2
    sw  x3, 8(x20)       /* 13 */

    sub x3, x1, x2
    sw  x3, 8(x20)       /* 7 */

    and x3, x1, x2
    sw  x3, 8(x20)       /* 2 */

    or x3, x1, x2
    sw x3, 8(x20)        /* 11 */

    xor x3, x1, x2
    sw  x3, 8(x20)       /* 9 */


    /* ================================= */
    /* DESPLAZAMIENTOS                  */
    /* ================================= */

    sll x3, x2, x2
    sw  x3, 8(x20)       /* 24 */

    srl x3, x1, x2
    sw  x3, 8(x20)       /* 1 */

    addi x4, x0, -16

    sra x3, x4, x2
    sw  x3, 8(x20)       /* -2 */


    /* ================================= */
    /* COMPARACIONES                    */
    /* ================================= */

    slt x3, x2, x1
    sw  x3, 8(x20)       /* 1 */

    sltu x3, x2, x1
    sw   x3, 8(x20)      /* 1 */


    /* ================================= */
    /* INSTRUCCIONES INMEDIATAS         */
    /* ================================= */

    addi x3, x1, -2
    sw   x3, 8(x20)      /* 8 */

    andi x3, x1, 6
    sw   x3, 8(x20)      /* 2 */

    ori x3, x2, 8
    sw  x3, 8(x20)       /* 11 */

    xori x3, x1, 3
    sw   x3, 8(x20)      /* 9 */

    slli x3, x2, 4
    sw   x3, 8(x20)      /* 48 */

    srli x3, x1, 1
    sw   x3, 8(x20)      /* 5 */

    srai x3, x4, 2
    sw   x3, 8(x20)      /* -4 */

    slti x3, x2, 10
    sw   x3, 8(x20)      /* 1 */

    sltiu x3, x2, 10
    sw    x3, 8(x20)     /* 1 */


    /* ================================= */
    /* LUI Y AUIPC                      */
    /* ================================= */

    lui x3, 0x12345
    sw  x3, 8(x20)

    auipc x3, 0
    sw    x3, 8(x20)


    /* ================================= */
    /* PRUEBAS DE SPI RAM               */
    /* ================================= */

    /* Escribir y leer un valor */

    sw x1, 0(x21)
    lw x3, 0(x21)

    sw x3, 8(x20)        /* 10 */


    /* Escribir y leer un byte */

    addi x3, x0, 127

    sb x3, 4(x21)
    lbu x3, 4(x21)

    sw x3, 8(x20)        /* 127 */


    /* ================================= */
    /* SALTOS CONDICIONALES             */
    /* ================================= */

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

    sw x3, 8(x20)        /* 6 */


    /* ================================= */
    /* JAL                              */
    /* ================================= */

    jal x0, jal_ok

    addi x3, x0, 99

jal_ok:
    addi x3, x3, 1
    sw   x3, 8(x20)      /* 7 */


    /* ================================= */
    /* JALR                             */
    /* ================================= */

    lui x18, %hi(jalr_ok)
    addi x18, x18, %lo(jalr_ok)

    jalr x0, 0(x18)

    addi x3, x0, 99

jalr_ok:
    addi x3, x3, 1
    sw   x3, 8(x20)      /* 8 */


    /* ================================= */
    /* FINALIZACION                     */
    /* ================================= */

    addi x3, x0, 0x55
    sw   x3, 8(x20)

fin:
    jal x0, fin