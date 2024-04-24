`timescale 1ns/1ns
`define DEBUG_MODE

module fpga_slave
(
    input wire clk_50M,
	input wire sys_rst_n,
    
    /** ADC **/
    output wire ad1_clk,
    output wire ad2_clk,
    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in,

    /** SPI_SLAVE **/
    input wire mosi,
    input wire sclk,
    input wire cs_n,
    output wire miso

);
/* clock */
wire sys_clk; // system clock 100MHz
wire sys_clk_216M; // system clock 216MHz
wire ad_clk; // adc clock 65MHz
assign ad1_clk = ad_clk;
assign ad2_clk = ad_clk;

/*********************************/
/************** ADC **************/
/*********************************/
// ADC output data(mV)
wire [15:0] volt_ch1; // voltage channel 1
wire [15:0] volt_ch2;

/*************************************/
/************* SPI_SLAVE *************/
/*************************************/
wire machine_start;
wire machine_stop;

wire [15:0] Ton_data;
wire [15:0] Toff_data;
wire [15:0] Ip_data;
wire [15:0] waveform_data;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
pll	pll_inst 
(
	.inclk0 ( clk_50M ),
	.c0 ( sys_clk ), // sys_clk 100MHz
	.c1 ( ad_clk ), // ad_clk 65MHz
    .c2 ( sys_clk_216M )
);

ad9238 adc_inst
( 
    .ad_clk (ad_clk),
    .rst_n (sys_rst_n),
    .ad1_in (ad1_in),
    .ad2_in (ad2_in),

    .volt_ch1 (volt_ch1),
    .volt_ch2 (volt_ch2)
);

spi_slave_cmd spi_slave_cmd_inst
(
    .clk(sys_clk_216M),
    .rst_n(sys_rst_n),

    // spi interface
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .cs_n(cs_n),

    .machine_start(machine_start),
    .machine_stop(machine_stop),

    .Ton_data(Ton_data),
    .Toff_data(Toff_data),
    .Ip_data(Ip_data),
    .waveform_data(waveform_data),

    .feedback_data({volt_ch1, volt_ch2})
);

endmodule