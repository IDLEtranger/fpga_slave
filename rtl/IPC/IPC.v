`timescale 1ns / 1ps
//电流起点检测，记录该点时刻，再加上定值Ton，来控制电流峰值
module IPC  (
	// 开发板上输入时钟: 50Mhz
	input	           clk,              
	input            rst_n,
	
	//丝速达到信号
	input            silk_reach,          

	//ad module
	input [11:0] ad_ch1,
	input [11:0] ad_ch2,


	//Board peripheral interface		
	input [2:0]     key_in,           // 输入按键信号(KEY1~KEY4)				
	output [5:0]     seg_sel,
	output [7:0]     seg_data,
	
	//can_protocol_analyze模块接口
	input 		  can_para_en,
	
	input	    	  can_para_Start,	
	input	 [3:0]  can_para_Mode,	
	input			  can_para_panglu,
	input			  can_para_Vneg,		

	input	 [7:0]  can_para_Idset,	
	input	 [7:0]  can_para_Dt,		
	input	 [15:0] can_para_Ts_1,	
	input	 [7:0]  can_para_Ton_1,	

	input	 [7:0]  can_para_Ts_2,	
	input	 [7:0]  can_para_Ts_3,	
	input	 [7:0]  can_para_Ton_3,	
	input	 [7:0]  can_para_Ts_4,	
	input	 [7:0]  can_para_Ton_4,	
	input	 [7:0]  can_para_T_neg,

						
	//PID 模块
	input [9:0] PID_Dt,
	output [4:0] ns_level2,
	output [13:0] Id_set,
	
	//pulse sort
	input pro1_short_flag,
							
	//送到pulse sort
	output Start1,
	output Start2,
	output Start3,
	output Start4,
	
	//output PWM
	output [7:0] PWM,
	output [1:0] PWM_Q,//切断
	output 		PWM_po1,
	output 		PWM_po2,
	
	
	output enn
	);

					

//--------------------------------------------------------------			 
//key scan
wire [2:0] key_code;
wire [2:0] key_code_cycle;
wire 		  key2_down;
wire 		  key3_down;
key_scan u_key_scan(
				 .clk(clk),
				 .rst_n(rst_n),
				
				 .key_in(key_in),
				 .key_code(key_code),
				 .key_code_cycle(key_code_cycle),
				 
				 .key2_down(key2_down),
				 .key3_down(key3_down)
				);
			 
			
//--------------------------------------------------------------			 
//seg_controller


wire [20:0] vol_ad = (ad_ch1 * 5'd28); // vol_ad=Vgap
wire [20:0] wave_ad = ((ad_ch2 - 12'd2500) / 50; // wave_ad=Igap



seg_controller u_seg_controller(
				  .clk(clk),
				  .rst_n(rst_n),
				
				//另一模块数据输入--由IPC模块输入
			    .Start_r1(Start_r1),
				 .Start_r2(Start_r2),
				 .Start_r3(Start_r3),
				 .Start_r4(Start_r4),
				 .Vneg_r(Vneg_r),
			    .Id_set_r(Id_set_r), 
			    .Ton_r(Ton_r),
			    .Ts_r(Ts_r),
				 .T_neg_r(T_neg_r),
			    //.Num_on_r(Num_on_r), 
			    //.Num_off_r(Num_off_r),
			    .Dt_r(Dt_r),
				
				//key 输入，根据key1的按键次数选取显示的值
					.key_code(key_code),
					.key_code_cycle(key_code_cycle),
				
				//外部数码管连接
				  .dtube_data(seg_data),
				  .dtube_cs_n(seg_sel)//共用到6根数码管
				);

	
//--------------------------------------------------------------			 
//key scan	
wire 		  Start_r1; 
wire 		  Start_r2; 
wire 		  Start_r3;
wire 		  Start_r4;

wire [7:0] Id_set_r;
wire [7:0] Ton_r;
wire [15:0]Ts_r;
//wire [7:0] Num_on_r;
//wire [7:0] Num_off_r;
wire [7:0] Dt_r;


//wire [15:0] Id_set;//将Id_set设为PID控制目标电流，引出至PID模块
wire 			panglu_en;
wire [15:0] Ton;
wire [15:0] Ts;
//wire [7:0]  Num_on;
//wire [7:0]  Num_off;
wire [15:0] Dt;

para_generate 
/*#(
			   .Id_set_STEP(4'd1),
			   .Ton_STEP(4'd2),
				.Ton_STEP3(4'd1),
			   .Ts_STEP(4'd5),
				.Ts_STEP3(4'd10),
			   .Dt_STEP(4'd1),
			   .Num_on_STEP(4'd1),
			   .Num_off_STEP(4'd1)
)*/
u_para_generate
(
				//50Mhz clock
            .clk(clk),                     
			   .rst_n(rst_n),
			  
				//can总线输入,从can_protocal_analyze直接传送到para_generate
			   .can_para_en			(can_para_en		),
				//first frame
				.can_para_Start      (can_para_Start	),    
				.can_para_Mode       (can_para_Mode		),
				.can_para_panglu		(can_para_panglu	),
				.can_para_Vneg			(can_para_Vneg		),
				.can_para_Idset		(can_para_Idset	),
				.can_para_Dt			(can_para_Dt		),
				.can_para_Ts_1			(can_para_Ts_1		),
				.can_para_Ton_1		(can_para_Ton_1	),
				//second  frame                    
				.can_para_Ts_2			(can_para_Ts_2		),
				.can_para_Ts_3	      (can_para_Ts_3	 	),
				.can_para_Ton_3      (can_para_Ton_3 	),
				.can_para_Ts_4	      (can_para_Ts_4	 	),
				.can_para_Ton_4      (can_para_Ton_4 	),
			   .can_para_T_neg		(can_para_T_neg	),
			  
			  //key模块输入
			   .key_code(key_code),
			  	.key2_down(key2_down),
			  	.key3_down(key3_down),
				
				//由can和key共同决定的电参数输出----seg display数码管显示
				 .Start_r1(Start_r1),
				 .Start_r2(Start_r2),
				 .Start_r3(Start_r3),
				 .Start_r4(Start_r4),
             .Vneg_r(Vneg_r),				 
			    .Id_set_r(Id_set_r), 
			    .Ton_r(Ton_r),
				 .T_neg_r(T_neg_r),
			    .Ts_r(Ts_r),
			    //.Num_on_r(Num_on_r), 
			    //.Num_off_r(Num_off_r),
			    .Dt_r(Dt_r),
			  
			  	//由can和key共同决定的电参数输出------PWM module——PWM模块
			    .Start1(Start1),
				 .Start2(Start2),
				 .Start3(Start3),
				 .Start4(Start4),
				 .power_Start(power_Start),
				 .panglu_en(panglu_en),	
				 .Vneg_en(Vneg_en),
			    .Id_set(Id_set), 
			    .Ton(Ton),				//第1.2.3.4刀都是这个变量
			    .Ts(Ts),
				 .T_neg(Tneg),
				 .Dt(Dt)
			    //.Num_on(Num_on), 
			    //.Num_off(Num_off),
			    //.Dt(Dt)
			  
			  
	 
	 );
 
 
 
//--------------------------------------------------------------			 
//PWM 
PWM 
/*#(
			 .T_wait_max  (16'd250),//5us*50
			 .I_start (16'd3060),		//设定单路起始电流 1200/400=3A--->修改为单路值，5A-->4路，12A
			 .T_IP_rise_max  (16'd510),//10us * 50
			 .Protect_MaxIP  (16'd3060), //检测到最大电流，40A*4位*100倍--->修改为单路值，30A--->4路，30A
			 .BREAK_VOL (12'd350)
			)*/
u_PWM
(
			//system interface
			 .clk(clk),
			 .rst_n(rst_n),
			
			// can interface
				.start_signal_1(Start1),
				.start_signal_2(Start2),
				.start_signal_3(Start3),
				.start_signal_4(Start4),	
				.power_Start(power_Start),
				.panglu_en(panglu_en),
				.Vneg_en(Vneg_en),
				.Id_set(Id_set),			
				.Ton(Ton),
				.Ts(Ts),
				.T_neg(Tneg),
			//.Num_on(Num_on),
			//.Num_off(Num_off),
			 
			   .Dt(Dt[6:0]),
			
			//silk reach
				.silk_reach(silk_reach),
			
			//AD9226 interface
				.ad_ch1(ad_ch1),
				.ad_ch2(ad_ch2),
			 
			//OCC interface
			//.Dt(PID_Dt),
				.ns_level2(ns_level2),
				.DT(Dt[6:0]),
				.occ_cnt(occ_cnt),
				.OCC_flag(OCC_flag),
			 
			//pulse sort
				.pro1_short_flag(pro1_short_flag),
			
			//output PWM
				.PWM(PWM),
				.PWM_Q(PWM_Q),//切断
				.PWM_po1(PWM_po1),//导线旁路
				.PWM_po2(PWM_po2)//电阻旁路

				);



wire [15:0] occ_cnt;
wire OCC_flag;

wire [12:0] DT_OCC;
wire [12:0] i_real_real;


OCC u_OCC( 
	.clk(clk),
	.rst_n(rst_n),
	
	.ad_ch1(ad_ch1),//滤波后的电流
	.ad_ch2(ad_ch2),//滤波后的电压
	.OCC_flag(OCC_flag),//定义闭环开始信号
	.OCC_cnt(occ_cnt),
	.iset(Id_set_r),	//上位机传送单路电流值	
	.i_real_real(i_real_real),				//无用
	.vd(vd),										//无用
	.DT(DT_OCC),
	.enn(enn)	

);
				
				
				
				
endmodule



