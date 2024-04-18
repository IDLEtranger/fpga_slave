module spi_slave_control
( 
    input wire          sys_clk,      // FPGA Clock
    input wire          rst, 

    // SPI Interface
    input wire          i_SPI_Clk,
    output wire         o_SPI_MISO,
    input wire          i_SPI_MOSI,
    input wire          i_SPI_CS_n,
    
    input wire [11:0]   ad1_in, 
    output wire         ad1_clk,

    input wire [11:0]   ad2_in, 
    output wire         ad2_clk
);

wire clk65M;
assign ad1_clk = clk65M;
assign ad2_clk = clk65M;
assign adc_clk = clk65M;

wire [11:0] ad_ch1; 
wire [11:0] ad_ch2;
reg [15:0] ad1_reg;
reg [15:0] ad2_reg;

wire             RX_DV;
wire [7:0]       RX_Byte;
wire [7:0]       TX_Byte;


always@(posedge adc_clk or posedge rst)




    spi_slave_driver SPI_SLAVE(
        .rec_data(RX_Byte),
        .rec_done(RX_DV),
        .miso(o_SPI_MISO),
        .mosi(i_SPI_MOSI),
        .sclk(i_SPI_Clk),
        .cs_n(i_SPI_CS_n),
        .response_data(TX_Byte),
        .mode(2'b00),
        .clk(sys_clk),
        .rst(rst)
        );
endmodule