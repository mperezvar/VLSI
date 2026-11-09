`timescale 1ns/1ps

module tb_cocotb;

    reg clk = 0;
    reg resetn = 0;
    reg RXD = 1;

    wire TXD;
    wire LEDS;

    // Señales de la SPI Flash
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs_n;
    wire spi_clk;

    // Señales de la SPI RAM
    wire spi_mosi_ram;
    wire spi_miso_ram;
    wire spi_cs_n_ram;
    wire spi_clk_ram;


    // Procesador original
    femto uut (
        .clk(clk),
        .resetn(resetn),

        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),

        .spi_mosi_ram(spi_mosi_ram),
        .spi_miso_ram(spi_miso_ram),
        .spi_cs_n_ram(spi_cs_n_ram),
        .spi_clk_ram(spi_clk_ram),

        .RXD(RXD),
        .TXD(TXD),
        .LEDS(LEDS)
    );


    // Modelo original de SPI Flash
    spiflash flash0 (
        .csb(spi_cs_n),
        .clk(spi_clk),

        .io0(spi_mosi),
        .io1(spi_miso),

        .io2(),
        .io3()
    );


    // Modelo original de SPI RAM
    spiram flashram0 (
        .CS(spi_cs_n_ram),
        .SCK(spi_clk_ram),

        .SI(spi_mosi_ram),
        .SO(spi_miso_ram)
    );


    // Detectar resultados enviados por la CPU
    wire resultado_valido =
        uut.wr &&
        (uut.mem_address == 32'h00400008);

    wire [31:0] resultado = uut.mem_wdata;


    // Generar archivo de ondas
    initial begin
        $dumpfile("cocotb_femto.vcd");
        $dumpvars(0, tb_cocotb);
    end

endmodule