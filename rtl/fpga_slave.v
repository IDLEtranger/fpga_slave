`define DEBUG_MODE
module fpga_slave
(
    /** CLOCK & RESET **/
    input wire clk_in,
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
    output wire miso,

    /** MOSFET CONTROL SIGNAL **/
    output wire [1:0] mosfet_buck1, // Buck1:上管 下管
	output wire [1:0] mosfet_buck2, // Buck2:上管 下管
	output wire [1:0] mosfet_res1, // Res1:上管 下管
	output wire [1:0] mosfet_res2, // Res2:上管 下管
	output wire mosfet_deion // Qoff 消电离回路
);
/* clock */
`ifdef DEBUG_MODE
    (* preserve *) wire clk_50M;
    (* preserve *) wire clk_65M;
    (* preserve *) wire clk_100M;
    (* preserve *) wire clk_216M;
`else
    wire clk_50M;
    wire clk_65M;
    wire clk_100M;
    wire clk_216M;
`endif

assign ad1_clk = clk_65M;
assign ad2_clk = clk_65M;

/*********************************/
/************** ADC **************/
/*********************************/
wire [15:0] sample_current;
wire [15:0] sample_voltage;

/*************************************/
/************* SPI_SLAVE *************/
/*************************************/
// pulse_generator discharge signal
wire [15:0] Ton_data_async;
wire [15:0] Toff_data_async;
wire [15:0] Ip_data_async;
wire [15:0] waveform_data_async;

wire machine_start_ack;
wire machine_stop_ack;
wire change_Ton_ack;
wire change_Toff_ack;
wire change_Ip_ack;
wire change_waveform_ack;

/*******************************************/
/************* DISCHARGE CONTROL *************/
/*******************************************/
// wire [1:0] mosfet_buck1, // Buck1:上管 下管
// wire [1:0] mosfet_buck2, // Buck2:上管 下管
// wire [1:0] mosfet_res1, // Res1:上管 下管
// wire [1:0] mosfet_res2, // Res2:上管 下管
// wire mosfet_deion // Qoff 消电离回路

/**************************************/
/************* PULSE SORT *************/
/**************************************/
wire [7:0] null_pulse_num;
wire [7:0] normal_pulse_num;
wire [7:0] short_pulse_num;
wire pro1_short_flag; // 极间击穿 放电开始？

/*******************************/
/************* FIR *************/
/*******************************/
wire [11:0] filtered_wave;
wire [11:0] filtered_vol;

/*******************************/
/************* IPC *************/
/*******************************/
wire [9:0] PID_Dt;
wire [4:0] ns_level2;
wire [15:0] Id_set;
wire Start1;
wire Start2;
wire Start3;
wire Start4;


//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
pll	pll_inst 
(
	.inclk0 ( clk_in ),
	.c0 ( clk_50M ),
	.c1 ( clk_65M ),
	.c2 ( clk_100M ),
	.c3 ( clk_216M )
);

ad_sample ad_sample_inst
(
    .sys_clk(clk_100M),
    .ad_clk(clk_65M),
    .rst_n(sys_rst_n),

    .ad1_in(ad1_in),
    .ad2_in(ad2_in),

    .sample_current_fifo_out(sample_current), // synchronized to sys_clk
    .sample_voltage_fifo_out(sample_voltage)
);

spi_slave_cmd spi_slave_cmd_inst
(
    .clk(clk_216M),
    .rst_n(sys_rst_n),

    // spi interface
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .cs_n(cs_n),

    .machine_start_ack(machine_start_ack),
    .machine_stop_ack(machine_stop_ack),

    .Ton_data_async(Ton_data_async),
    .change_Ton_ack(change_Ton_ack),
    .Toff_data_async(Toff_data_async),
    .change_Toff_ack(change_Toff_ack),
    .Ip_data_async(Ip_data_async),
    .change_Ip_ack(change_Ip_ack),
    .waveform_data_async(waveform_data_async),
    .change_waveform_ack(change_waveform_ack),

    .change_feedback_ack(1'b1),
    .feedback_data_async(32'h0F0F0F0F)
);

discharge_control discharge_ctrl_inst
(
    .clk(clk_100M),
    .rst_n(sys_rst_n),

    // parameter in
    .machine_start_ack(machine_start_ack),
    .machine_stop_ack(machine_stop_ack),

    .change_Ton_ack(change_Ton_ack),
    .Ton_data_async(Ton_data_async),

    .change_Toff_ack(change_Toff_ack),
    .Toff_data_async(Toff_data_async),

    .change_Ip_ack(change_Ip_ack),
    .Ip_data_async(Ip_data_async),

    .change_waveform_ack(change_waveform_ack),
    .waveform_data_async(waveform_data_async),

    // sampling data
    .sample_current(sample_current),
    .sample_voltage(sample_voltage),

    // output mosfet control signal
    .mosfet_buck1(mosfet_buck1),
    .mosfet_buck2(mosfet_buck2),
    .mosfet_res1(mosfet_res1),
    .mosfet_res2(mosfet_res2),
    .mosfet_deion(mosfet_deion)
);

endmodule