/*
基于电压检测的脉冲识别
计算公式：（目标电压/25）*2048 / 5v = ad值 即 ad值=目标电压*16.4
原理：MOS管开通后3.3us内，取16个点做平均
avg>30v,		即avg>492  		NULL
30V<avg<55V	即480<avg<901	NORMAL
avg<24V		即avg<390		SHORT		
*/

//1s通过CAN发送一次间隙状态数据（LWH）第一刀50ms内的脉冲数量和比例；第二刀5ms内的脉冲数量和比例
module pulse_sort
(
	input clk,
	input rst_n,
	
	//丝速到达
	input silk_reach,
	
	//电压检测AD采样值
	input [11:0] ad_vol_data,
	input [11:0] ad_ip_data,
	
	//PWM-标志一个脉冲放电开始
	input [3:0] pwm,
	output reg pro1_short_flag,
	
	//IPC
	input Start1,
	input Start2,
	input Start3,
	input Start4,
	
	//output
	output reg servo_cansend_flag,
	output reg [7:0] NullPulse,
	output reg [7:0] NormalPulse,
	output reg [7:0] ShortPulse,
		
	//output
	output reg vf_pulse//走步信号
	
);
localparam NULL_SH = 12'd306;//第一刀空载阈值30v
localparam SHORT_SH = 12'd224;//第一刀短路阈值22v

localparam NULL_SH3 = 12'd199;//第三刀空载阈值
localparam SHORT_SH3 = 12'd224;//第三刀短路阈值22V


//第一刀伺服动作周期50ms（最大不超过1s，否则数据位宽不够）
localparam SERVO_CYCLE_1 = 32'd2_500_000;//伺服周期50ms（最大不超过1s，否则数据位宽不够）
reg [31:0] servo_cnt_1;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) servo_cnt_1 <= 32'd0;
	else if(servo_cnt_1 < SERVO_CYCLE_1 - 1'b1) servo_cnt_1 <= servo_cnt_1 + 1'b1;
	else servo_cnt_1 <= 32'd0;
end
wire servo_cycle_flag_1 = (servo_cnt_1 == SERVO_CYCLE_1 - 1'b1 )?1'b1:1'b0;


//第二刀伺服动作周期5ms（最大不超过1s，否则数据位宽不够）
localparam SERVO_CYCLE_2 = 32'd250_000;//伺服周期50ms（最大不超过1s，否则数据位宽不够）
reg [31:0] servo_cnt_2;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) servo_cnt_2 <= 32'd0;
	else if(servo_cnt_2 < SERVO_CYCLE_2 - 1'b1) servo_cnt_2 <= servo_cnt_2 + 1'b1;
	else servo_cnt_2 <= 32'd0;
end
wire servo_cycle_flag_2 = (servo_cnt_2 == SERVO_CYCLE_2 - 1'b1 )?1'b1:1'b0;


//CAN上传间隙状态数据的周期：1s
localparam CAN_SEND_SYCLE = 32'd50_000_000;//1s
reg [31:0] CAN_SEND_cnt;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) CAN_SEND_cnt <= 32'd0;
	else if (CAN_SEND_cnt < CAN_SEND_SYCLE - 1'b1) CAN_SEND_cnt <= CAN_SEND_cnt + 1'b1;
	else CAN_SEND_cnt <= 32'd0;
end
//wire CAN_SEND_flag = (CAN_SEND_cnt == CAN_SEND_SYCLE - 1'b1) ? 1'b1:1'b0;
reg	CAN_SEND_flag;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin 
		servo_cansend_flag <= 1'b0;
		NullPulse <= 8'd0;
		NormalPulse <= 8'd0;
		ShortPulse <= 8'd0;
	end
	else if (CAN_SEND_cnt == CAN_SEND_SYCLE - 1'b1)
	begin
	servo_cansend_flag <= 1'b1;//can返回间隙状态的使能，在测试上位机通讯时将其置低，即不返回数据
		NullPulse <= 	NullPulse_r;
		NormalPulse <=	NormalPulse_r;
		ShortPulse <= 	ShortPulse_r;
	end
	else 	
		begin
		servo_cansend_flag <= 1'b0;
		NullPulse <= 	NullPulse;
		NormalPulse <=	NormalPulse;
		ShortPulse <= 	ShortPulse;
		end
end


//--------------------------------
//检测pwm的上升沿和下降沿，作为脉冲判别开始依据
reg pwm1_r,pwm2_r,pwm3_r,pwm0_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin pwm1_r <= 1'b0;pwm2_r <= 1'b0;pwm3_r <= 1'b0;pwm0_r <= 1'b0;end
	else begin pwm0_r <= pwm[0];pwm1_r <= pwm[1];pwm2_r <= pwm[2];pwm3_r <= pwm[3];end
end
wire pwm0_rise = (~pwm0_r & pwm[0])?1'b1:1'b0;
wire pwm1_rise = (~pwm1_r & pwm[1])?1'b1:1'b0;
wire pwm2_rise = (~pwm2_r & pwm[2])?1'b1:1'b0;
wire pwm3_rise = (~pwm3_r & pwm[3])?1'b1:1'b0;
//wire pwm_fall = (pwm_r & ~pwm)?1'b1:1'b0;


reg clf_en1;//第1刀脉冲检测使能
reg clf_en2;//第2刀脉冲检测使能
reg clf_en3;//第3\4刀脉冲检测使能,第3刀和第4刀使用相同的脉冲检测使能

always@(posedge clk or negedge rst_n)
begin//通过检测PWM上升沿来判定脉冲开始，第一刀4个Buck,第二刀1个Buck,第三刀1个Buck，第四刀1个Buck
	if(!rst_n) begin clf_en1 <= 1'b0; clf_en3 <= 1'b0; end
	else if(Start1 && pwm0_rise && pwm1_rise && pwm2_rise&& pwm3_rise) begin clf_en1 <= 1'b1;clf_en2 <= 1'b0; clf_en3 <= 1'b0; end
	else if(Start2 && pwm1_rise) begin clf_en2 <= 1'b1;clf_en1 <= 1'b0;clf_en3 <= 1'b0; end
	else if((Start3 && pwm0_rise)||(Start4 && pwm0_rise)) begin clf_en3 <= 1'b1; clf_en1 <= 1'b0;clf_en2 <= 1'b0; end
	else begin clf_en1 <= 1'b0;clf_en2 <= 1'b0; clf_en3 <= 1'b0; end																		
end

//--------------------------------
//打一拍缓存，并将负数处理为0--->滤波模块已做去除符号
reg [11:0] ad_vol_reg;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) ad_vol_reg <= 12'd0;
	else 
		begin
		if(ad_vol_data[11]) ad_vol_reg <= 12'd0;
		else ad_vol_reg <= ad_vol_data;
		end
end


//--------------------------------
//脉冲判别状态机
reg [2:0] i;
reg [5:0] pulse_cnt;//计到20发一个脉冲
reg vf_flag;

//定义三种脉冲类型计数器
reg [7:0] short_pluse_cnt;
reg [7:0] normal_pluse_cnt;
reg [7:0] null_pluse_cnt;
reg [7:0] NullPulse_r  ;
reg [7:0] NormalPulse_r;
reg [7:0] ShortPulse_r ;
reg [7:0] short_cnt_con;//连续短路检测计数器
reg		 short_con;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) 
		begin
		i <= 3'd0;
		pulse_cnt <= 6'd0;
		vf_flag <= 1'b0;
		pro1_short_flag <= 1'b0;
		
		short_pluse_cnt <= 8'd0;
		normal_pluse_cnt <= 8'd0;
		null_pluse_cnt <= 8'd0;
		
		NullPulse_r <= 8'd0;
		NormalPulse_r <= 8'd0;
		ShortPulse_r <= 8'd0;
		
		end
		
		else if (servo_cycle_flag_1 && Start1 )
			begin
			i <= 3'd0;
			NullPulse_r <= null_pluse_cnt;
			NormalPulse_r <= normal_pluse_cnt;
			ShortPulse_r <= short_pluse_cnt;
	
			short_pluse_cnt <= 8'd0;
			normal_pluse_cnt <= 8'd0;
			null_pluse_cnt <= 8'd0;
			end
		
		else if (servo_cycle_flag_2 && Start2 )
			begin
			i <= 3'd0;
			NullPulse_r <= null_pluse_cnt;
			NormalPulse_r <= normal_pluse_cnt;
			ShortPulse_r <= short_pluse_cnt;
	
			short_pluse_cnt <= 8'd0;
			normal_pluse_cnt <= 8'd0;
			null_pluse_cnt <= 8'd0;
			end
		
		else if (Start3 || Start4 )
			begin
			i <= 3'd0;
			NullPulse_r <= 1'd0;
			NormalPulse_r <= 1'd0;
			ShortPulse_r <= 1'd0;
	
			short_pluse_cnt <= 8'd0;
			normal_pluse_cnt <= 8'd0;
			null_pluse_cnt <= 8'd0;
			end
		
	else 
		begin
		//servo_cansend_flag <= 1'b0;
		case(i)
			0://等待脉冲开始
			begin
			vf_flag <= 1'b0;
			
			if(clf_en1) i <= 3'd1;//第1刀脉冲检测
			else if(clf_en2) i <= 3'd5;//第2刀脉冲检测
			else if(clf_en3) i <= 3'd3;//第3刀和第4刀脉冲检测
			else i <= 3'd0;
			end
			
			//------------------------------------第1刀脉冲判断--------------------------------------//
			1://单个脉冲内：16个采样点计数平均，先判断是否空载
			begin
			if(avg_done) 
				begin
					if(ad_vol_avg1 > NULL_SH) 
						begin
						pulse_cnt <= pulse_cnt + 2'd2;//空载+2
						null_pluse_cnt <= null_pluse_cnt + 1'b1;//空载放电计数器+1
						end

					else 
						begin
						if(ad_vol_avg2 < SHORT_SH)//短路
							begin
							pro1_short_flag <= 1'b1;//第一刀检测刀短路波形，大约20us处
							short_pluse_cnt <= short_pluse_cnt + 1'b1;//短路放电计数器+1
							if(pulse_cnt == 1'b0) pulse_cnt <= pulse_cnt;
							else pulse_cnt <= pulse_cnt - 1'b1;
							end
						else //正常
							begin
							pulse_cnt <= pulse_cnt + 1'b1;
							pro1_short_flag <= 1'b0;
							normal_pluse_cnt <= normal_pluse_cnt + 1'b1; //正常放电计数器+1
							end
						end
							i <= i + 1'b1;
				end
				
			else begin i <= i; pulse_cnt <= pulse_cnt;end
			end
						
			2://判断计数是否达到20
			begin 
			pro1_short_flag <= 1'b0;//
			//若空载多， pulse_cnt 到20，vf_flag 为1，若短路多， pulse_cnt 到0，vf_flag 为0。
			if(pulse_cnt >= 6'd20) begin vf_flag <= 1'b1; pulse_cnt <= 6'd0; i <= 3'd0; end 
			else begin vf_flag <= 1'b0; pulse_cnt <= pulse_cnt; i <= 3'd0;end
			end
			
			
			//------------------------------------第3刀脉冲判断--------------------------------------//
			3:
			begin
				//short_pluse_cnt <= 8'd0;
				//normal_pluse_cnt <= 8'd0;
				//null_pluse_cnt <= 8'd0;
			if(avg_done) 
				begin
				if(normal34_cnt >= 8'd5)
					begin
					normal_pluse_cnt <= normal_pluse_cnt + 1'b1; //正常放电或空载，正常放电计数器+1
					short_cnt_con <=8'd0;//连续短路的计数清零
					end
				else
					begin 
					short_pluse_cnt <= short_pluse_cnt + 1'b1;//短路放电计数器+1
					short_cnt_con <= short_cnt_con +1'b1;
					end
				
				i <= i + 1'b1;
				end
				
			else 
				begin i <= i;end
			end
			
			
			4:
			begin
			if(short_cnt_con >=8'd10)
				begin 
				short_con <=1'b1;//连续短路的判断信号
				i <= 3'd0;
				end
			else 
				begin
				short_con <=1'b0;
				i <= 3'd0;
				end
			end
			
			
			
				
			
			
			
			/*3:
			begin
			short_pluse_cnt <= 8'd0;
			normal_pluse_cnt <= 8'd0;
			null_pluse_cnt <= 8'd0;
			if(avg_done) 
				begin
				if(ad_vol_avg1 > NULL_SH3) pulse_cnt <= pulse_cnt + 2'd1;//空载+1
				else if((ad_vol_avg1 <= NULL_SH3) && (ad_vol_avg1 > SHORT_SH3)) pulse_cnt <= pulse_cnt + 1'd1;//正常+1
				else 
					begin
					if(pulse_cnt <= 6'd1) pulse_cnt <= 6'd0;//保证pulse_cnt不可能为负数
					else pulse_cnt <= pulse_cnt - 2'd2;//短路-2
					end
					
				i <= i + 1'b1;
				end
				
			else begin i <= i; pulse_cnt <= pulse_cnt;end
			
			end
			
			4:
			begin
			if(pulse_cnt >= 6'd20) begin pulse_cnt <= 6'd10; i <= 3'd0; end //第三刀脉冲检测没有动作
			else begin pulse_cnt <= pulse_cnt; i <= 3'd0;end
			end*/

			//------------------------------------第2刀脉冲判断--------------------------------------//
			5://单个脉冲内：16个采样点计数平均，先判断是否空载
			begin
			if(avg_done) 
				begin
				if(ad_vol_avg1 > NULL_SH) 
				begin
				pulse_cnt <= pulse_cnt + 2'd2;//空载+2
				null_pluse_cnt <= null_pluse_cnt + 1'b1;//空载放电计数器+1
				end
							
				else if((ad_vol_avg1 <= NULL_SH) && (ad_vol_avg1 > SHORT_SH)) 
				begin
				pulse_cnt <= pulse_cnt + 1'd1;//正常+1
				normal_pluse_cnt <= normal_pluse_cnt + 1'b1; //正常放电计数器+1
				end
				else 
					begin
					short_pluse_cnt <= short_pluse_cnt + 1'b1;//短路放电计数器+1
					if(pulse_cnt <= 6'd1) pulse_cnt <= 6'd0;//保证pulse_cnt不可能为负数
					else pulse_cnt <= pulse_cnt - 2'd1;//短路-2
					end
					
				i <= i + 1'b1;
				end
				
			else begin i <= i; pulse_cnt <= pulse_cnt;end
			end
						
			6://判断计数是否达到20
			if(pulse_cnt >= 6'd20) begin vf_flag <= 1'b1; pulse_cnt <= 6'd0; i <= 3'd0; end 
			else begin vf_flag <= 1'b0; pulse_cnt <= pulse_cnt; i <= 3'd0;end

		endcase
		end
end


//--------------------------------
//采样8个点-->修改为采样3us内16个点
reg [15:0] samp_cnt;
reg [1:0] samp_i;
reg [26:0] ad_vol_sum;
reg [11:0] ad_vol_avg1;
reg [11:0] ad_vol_avg2;
reg avg_done;
reg [7:0] normal34_cnt;
reg [7:0] ad_normal_cnt;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin samp_i <= 2'd0; samp_cnt <= 16'd0;end
	else 
		begin
		case(samp_i)
		
			0:
			if(Start1 && pwm0_rise && pwm1_rise && pwm2_rise&& pwm3_rise) samp_i <= 2'd1; 
			else if(Start2 && pwm1_rise) samp_i <= 2'd2;
			else if((Start3 && pwm0_rise)||(Start4 && pwm0_rise)) samp_i <= 2'd3;
			else samp_i <= 2'd0;
			//------------------------------------第1刀采样点计数--------------------------------------//
			1:
			if(samp_cnt == 16'd1500) begin samp_cnt <= 16'd0; samp_i <= 2'd0; end
			else begin samp_cnt <= samp_cnt + 1'b1; samp_i <= samp_i; end
			
			//------------------------------------第2刀采样点计数--------------------------------------//
			2:
			if(samp_cnt == 16'd1000) begin samp_cnt <= 16'd0; samp_i <= 2'd0; end
			else begin samp_cnt <= samp_cnt + 1'b1; samp_i <= samp_i; end
			
			//------------------------------------第3刀第4刀采样点计数--------------------------------------//
			3:
			if(samp_cnt == 16'd250) begin samp_cnt <= 16'd0; samp_i <= 2'd0; end
			else begin samp_cnt <= samp_cnt + 1'b1; samp_i <= samp_i; end
			
		
		endcase
		end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		ad_vol_sum <= 27'd0;
		ad_vol_avg1 <= 12'd0;
		ad_vol_avg2 <= 12'd0;
		avg_done <= 1'b0;
		normal34_cnt<= 8'd0;
		end
	//------------------------------------第1刀采样控制--------------------------------------//
	else if(i == 1)
		begin	
		case(samp_cnt)
		50,60,70,80,90,
		100,110,120,130,140,
		150,160,170,180,190,200://sampling 16 points
		begin
		ad_vol_sum <= ad_vol_sum + ad_vol_reg;
		end
		
		201://cal avg
		begin
		ad_vol_avg1 <= ad_vol_sum >> 4;
		ad_vol_sum <= 27'd0;
		end
		
//		750,760,770,780,790,
//		800,810,820,830,840,
//		850,860,870,880,890,900://第二次隔15us开始采样，采3us
		300,310,320,330,340,
		350,360,370,380,390,
		400,410,420,430,440,450://第二次隔6us开始采样，采3us
		begin
		ad_vol_sum <= ad_vol_sum + ad_vol_reg;
		end

		451:
		begin
		ad_vol_avg2 <= ad_vol_sum >> 4;
		ad_vol_sum <= 27'd0;
		avg_done <= 1'b1;
		end
		
		452:
		begin
		avg_done <= 1'b0;
		end
		
		default:
			begin
			ad_vol_sum <= ad_vol_sum;
			ad_vol_avg1 <= ad_vol_avg1;
			ad_vol_avg2 <= ad_vol_avg2;
			avg_done <= avg_done;
			end

		
		endcase
		end
	//------------------------------------第3刀第4刀采样控制--------------------------------------//
	else if(i == 3)
		begin
		
		case(samp_cnt)
		20,22,24,26,28,30,32,34,36,38,
		40,42,44,46,48,50,52,54,56,58,
		60,62,64,66,68,70,72,74,76,78,
		80,82,84,86,88,90,92,94,96,98,100://sampling 16 points

			begin
			if(ad_vol_reg >=SHORT_SH3)
			ad_normal_cnt <= ad_normal_cnt + 1'b1;//记录2us内间隙电压超过SHORT_SH3的次数，超过5次算加工或空载，否则算短路
			else 
			ad_normal_cnt <= ad_normal_cnt;
			end
		
		102:
			begin
			avg_done <= 1'b1;
			normal34_cnt <=ad_normal_cnt;
			end
		
		
		103:
			begin
			avg_done <= 1'b0;
			ad_normal_cnt <=8'd0;
			end

		
	
		default:
			begin
			ad_normal_cnt <= ad_normal_cnt;
			normal34_cnt <= normal34_cnt;
			avg_done <= avg_done;
			end

		
		endcase		
		end
	
	/*else if(i == 3)
		begin
		
		case(samp_cnt)
		20,22,24,26,28,
		30,32,34,36,38,
		40,42,44,46,48,
		50,52,54,56,58,
		60,62,64,66,68,
		70,72,74,76,78,
		80,82,84,86,88,
		90,92,94,96,98,100://sampling 16 points

		begin
		ad_vol_sum <= ad_vol_sum + ad_vol_reg;
		end
		
		83://cal avg
		begin
		ad_vol_avg1 <= ad_vol_sum >> 4;
		ad_vol_sum <= 20'd0;
		avg_done <= 1'b1;
		end
		
		84://clear
		begin
		avg_done <= 1'b0;
		end
		
		default:
		begin
		end

		
		endcase		
		end*/
		
	//------------------------------------第2刀采样控制--------------------------------------//
	else if(i == 5)
		begin	
		case(samp_cnt)
		50,60,70,80,90,
		100,110,120,130,140,
		150,160,170,180,190,200://sampling 16 points
		begin
		ad_vol_sum <= ad_vol_sum + ad_vol_reg;
		end
		
		201://cal avg
		begin
		ad_vol_avg1 <= ad_vol_sum >> 4;
		ad_vol_sum <= 20'd0;
		avg_done <= 1'b1;
		end
		
		202:
		begin
		avg_done <= 1'b0;
		end
		
		default:
		begin
		ad_vol_sum <= ad_vol_sum;
		ad_vol_avg1 <= ad_vol_avg1;
		ad_vol_avg2 <= ad_vol_avg2;
		avg_done <= avg_done;
		end

		
		endcase
		end
		
	else 
		begin
		ad_vol_sum <= 27'd0;
		ad_vol_avg1 <= ad_vol_avg1;
		avg_done <= 1'b0;
		end
end


//**************************************************************************************************
//***********************************走步信号给出****************************************************
//丝速到达处理（丝速到达信号前后有抖动）
reg silk_reach_r;
reg [19:0] silk_cnt;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) silk_cnt <= 20'd0;
	else if(silk_cnt < 20'd1_000_000) silk_cnt <= silk_cnt + 1'b1;
	else silk_cnt <= 20'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) silk_reach_r <= 1'b0;
	else if(silk_cnt == 20'd1_000_000) silk_reach_r <= silk_reach;
end

//pulse_cnt计数到20后发出一个周期200us的vf信号
reg [15:0] vf_cnt;
reg [2:0] vf_i;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		vf_pulse <= 1'b0;
		vf_cnt <= 16'd0;
		vf_i <= 3'd0;
		end
	//------------------------------------第1、2刀走步信号控制--------------------------------------//
	else if(Start1 || Start2)
		begin
		case(vf_i)
		
		0:
		if(vf_flag) 
		begin vf_i <= vf_i + 1'b1; vf_pulse <= 1'b1; end
		else begin vf_i <= 3'd0; vf_pulse <= 1'b0; end			
		1:
		begin
		vf_cnt <= vf_cnt + 1'b1;
		if(vf_cnt <= 16'd5000) vf_pulse <= 1'b1;//100us high
		else begin vf_pulse <= 1'b0; vf_cnt <= 16'd0; vf_i <= 3'd0; end
		
		end
		
		endcase
		end
	//------------------------------------第3、4刀走步信号(优化)--------------------------------------//	
	else if(Start3||Start4)
		begin
		if( silk_reach_r) 
			begin
			if(vf_cnt <= 16'd50000) vf_cnt <= vf_cnt + 1'b1;//d50000为1ms， vf_cnt 以1ms为一个周期循环计数
			else vf_cnt <= 14'd0;
			
			if(vf_cnt <= 16'd25000) vf_pulse <= 1'b1;//vf_pulse：500us置高，500us清零
			else vf_pulse <= 1'b0;
			end
			
		else begin vf_cnt <= 16'd0; vf_pulse <= 1'b0; end
		end
end



endmodule 
