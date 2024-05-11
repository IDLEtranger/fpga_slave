`timescale 1ns/1ns
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
    output	[7:0]	PWM,
	output	[1:0]	PWM_Q
);
/* clock */
wire clk_50M;
wire clk_65M;
wire clk_100M;
wire clk_216M;

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
/************* PULSE PARAMETER *************/
/*******************************************/
wire is_machine;
wire [15:0] Ton_data;
wire [15:0] Toff_data;
wire [15:0] Ip_data;
wire [15:0] waveform_data;

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
    .sys_clk(clk_100M),
    .clk(sys_clk_216M),
    .rst_n(sys_rst_n),

    // spi interface
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .cs_n(cs_n),

    .machine_start_ack(machine_start_ack),
    .machine_stop_ack(machine_stop_ack),

    .Ton_data(Ton_data_async),
    .change_Ton_ack(change_Ton_ack),
    .Toff_data(Toff_data_async),
    .change_Toff_ack(change_Toff_ack),
    .Ip_data(Ip_data_async),
    .change_Ip_ack(change_Ip_ack),
    .waveform_data(waveform_data_async),
    .change_waveform_ack(change_waveform_ack),

    .change_feedback_ack(1'b1),
    .feedback_data(32'h0F0F0F0F)
);

parameter_generator parameter_generator_inst
(
    .clk(),
    .sys_rst_n(),

    .machine_start_ack(machine_start_ack),
    .machine_stop_ack(machine_stop_ack),
    .is_machine(is_machine),

    .change_Ton_ack(change_Ton_ack),
    .Ton_data_async(Ton_data_async),
    .Ton_data(Ton_data),
    
    .change_Toff_ack(change_Toff_ack),
    .Toff_data_async(Toff_data_async),
    .Toff_data(Toff_data),

    .change_Ip_ack(change_Ip_ack),
    .Ip_data_async(Ip_data_async),
    .Ip_data(Ip_data),
    
    .change_waveform_ack(change_waveform_ack),
    .waveform_data_async(waveform_data_async),
    .waveform_data(waveform_data)
);

// pulse_sort pulse_sort_inst
// (
//     .clk(clk_50M),
// 	.rst_n(sys_rst_n),
	 
// 	//丝速到达
// 	.silk_reach(silk_reach),
	
// 	//电压检测AD采样值
// 	.ad_vol_data(filtered_vol),
// 	.ad_ip_data(filtered_wave),
	
// 	//PWM-标志一个脉冲放电开始
// 	.pwm({PWM[6],PWM[4],PWM[2],PWM[0]}),
// 	.pro1_short_flag(pro1_short_flag),
	 
// 	//IPC
// 	.Start1(Start1),
// 	.Start2(Start2),
// 	.Start3(Start3),
// 	.Start4(Start4),
	 
// 	//放电状态计数器
// 	.servo_cansend_flag	(SendFlag),
// 	.NullPulse   		(NullPulse),
// 	.NormalPulse 		(NormalPulse),
// 	.ShortPulse  		(ShortPulse),
// 	//output
// 	.vf_pulse			(vf_pulse)
// );

// FirFilter_top FirFilter_top_inst
// (
//     //system
//         .clk(clk_50m),
//         .rst_n(sys_rst_n),
    
//     //ad9226 input
//         .ad_ch1(ad_ch1),
//         .ad_ch2(ad_ch2),
    
//     //fir output
//         .filtered_wave(filtered_wave),
//         .filtered_vol(filtered_vol)
// ); 

// IPC IPC_inst  
// (
//     // 开发板上输入时钟: 50Mhz
//     .clk(clk_50m),              
//     .rst_n(sys_rst_n),
    
//     //丝速达到信号
//     .silk_reach(silk_reach),          

//     //ad module
//     .ad_ch1(filtered_wave),
//     .ad_ch2(filtered_vol),


//     //Board peripheral interface		
//     .key_in(key_in),           // 输入按键信号(KEY1~KEY4)				
//     .seg_sel(seg_sel),
//     .seg_data(seg_data),
    
//     //can_protocol_analyze模块接口
//     .can_para_en(can_para_en),
    
//     //first frame
//     .can_para_Start      (can_para_Start	),    
//     .can_para_Mode       (can_para_Mode		),
//     .can_para_panglu		(can_para_panglu	),
//     .can_para_Vneg			(can_para_Vneg		),
//     .can_para_Idset		(can_para_Idset	),
//     .can_para_Dt			(can_para_Dt		),
//     .can_para_Ts_1			(can_para_Ts_1		),
//     .can_para_Ton_1		(can_para_Ton_1	),
//     //second  frame                    
//     .can_para_Ts_2			(can_para_Ts_2		),
//     .can_para_Ts_3	      (can_para_Ts_3	 	),
//     .can_para_Ton_3      (can_para_Ton_3 	),
//     .can_para_Ts_4	      (can_para_Ts_4	 	),
//     .can_para_Ton_4      (can_para_Ton_4 	),
//     .can_para_T_neg		(can_para_T_neg	),
        
//     /*.can_para_Start(can_para_Start),
//     .can_para_Idset(can_para_Idset),
//     .can_para_Ton(can_para_Ton),
//     .can_para_Ts(can_para_Ts),
//     .can_para_Dt(can_para_Dt),
//     .can_para_Numon(can_para_Numon),	
//     .can_para_Numoff(can_para_Numoff),*/
    
//     //PID 模块
//         .PID_Dt(PID_Dt),
//         .ns_level2(ns_level2),
//         .Id_set(Id_set),
        
//         //pulse_Sort
//         .pro1_short_flag(pro1_short_flag),
        
//         //pulse sort
//         .Start1(Start1),
//         .Start2(Start2),
//         .Start3(Start3),
//         .Start4(Start4), 
    
//     //output PWM
//     .PWM(PWM),
//     .PWM_Q(PWM_Q),//切断
//     .PWM_po1(PWM_po1),//导线旁路
//     .PWM_po2(PWM_po2),//电阻旁路

//     .enn(enn)
// 		);	
endmodule