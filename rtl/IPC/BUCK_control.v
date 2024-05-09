module buck_control
(
	input clk, // 50MHz 20ns
	input rst_n,

	input power_start,

	input [15:0] Id_set,			
	input [15:0] Ton,
	input [15:0] Ts,
	
	// duty
	input [6:0]	CURRENT_RISE_TIME,
	output reg [15:0] occ_cnt,
	output reg OCC_flag,
	
	// adc
	input [11:0] ad_ch1,
	input [11:0] ad_ch2,
	
	// pulse sort
	input pro1_short_flag,
	
	// output PWM
	output reg [3:0] mos_buck, // Buck1:上管 下管 Buck2:上管 下管
	output reg [3:0] mos_res, // Res1:上管 下管 Res2:上管 下管
	output reg mos_deion, // Qoff 消电离回路
);

// parameter define
parameter DEAD_TIME = 16'd5;
parameter T_WAIT_MAX = 16'd250;
parameter T_WAIT_MIN = 16'd50;
parameter MAX_CURRENT_LIMIT = 16'd16320;
parameter BREAKDOWN_CUR = 16'd300;
parameter BREAKDOWN_VOL = 12'd500; // 由510变为350，将击穿电压阈值降低

/******************* begin state shift *******************/
localparam WAIT_BREAK  	= 3'b000;
localparam INTERLEAVE  	= 3'b010;
localparam T_OFF  		= 3'b100;

reg [2:0] current_state;
reg [2:0] next_state;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		current_state <= WAIT_BREAK;
	else 
		current_state <= next_state;
end

always@(*)
begin
	if(is_machine == 1'b0)
		next_state = WAIT_BREAK;
	else
		case(current_state)
			WAIT_BREAK:
			begin
				if((count_wait_break > T_WAIT_MIN) && (count_wait_break < T_WAIT_MAX)\
				&& (ad_ch1 >= BREAKDOWN_CUR	) && (ad_ch2 < BREAKDOWN_VOL))
					next_state = INTERLEAVE;
				else if(count_wait_break >= T_WAIT_MAX) 
					next_state = T_OFF; 
				else 
					next_state = WAIT_BREAK; 
			end	
						
			INTERLEAVE:
			begin
				if(count_interleave >= Ton) 
					next_state = T_OFF; 
				else 
					next_state = INTERLEAVE;
			end
						
			T_OFF:
			begin	
				if(timer_ts >= Ts) 
					next_state = WAIT_BREAK;
				else 
					next_state <= T_OFF;
			end

			default:	
				next_state = WAIT_BREAK;
		endcase
	else
		next_state =  WAIT_BREAK;
end
/******************* end state shift *******************/

// Qoff mosfet control
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		mos_deion <= 1'b0;
	end
	else if(current_state == T_OFF)
	begin
		mos_deion <= 1'b1;
	end
end

// current offset and short detect
reg [12:0] i_real;//单路补偿后的中间量电流，不可直接用于状态跳转
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		i_real <= 13'd0;
	else 
	begin
		i_real <= ad_ch1 - 13'd200;
	end
end	

reg [11:0] i_real_real;//单路补偿后的电流，可直接用于状态跳转
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		i_real_real <= 13'd0;
	else 
	begin
		if(i_real[12] == 1'b1)
			i_real_real <= 13'd0;
		else
		
			i_real_real <= i_real;
	end
end

//直接乘4，作为4路总电流--------------------------------------------------->此处无需加2048，因为Fir滤波补偿模块中已+2048
reg [13:0] i_real_real_sum;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		i_real_real_sum <= 14'd0;
	else 
	begin
		i_real_real_sum <= {i_real_real,2'b00};
	end
end				

reg [13:0] ad_ch1_sum;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		ad_ch1_sum <= 14'd0;
	else 
	begin
		ad_ch1_sum <= {ad_ch1,2'b00};
	end
end				

// protect
reg danger_short;
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) 
		danger_short <= 1'b0;
	else if(ad_ch1_sum > MAX_CURRENT_LIMIT) 
		danger_short <= 1'b1;
	else 
		danger_short <= 1'b0;
end 

// is_machine 
reg is_machine;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		is_machine <= 1'b1;
	else if((danger_short) || (~power_start))
		is_machine <= 1'b0;
	else 
		is_machine <= 1'b1;
end
		
// timer
reg [15:0] timer_ts;
reg [15:0] count_wait_break;
reg [15:0] count_interleave;
reg [15:0] count_Toff;

reg [15:0] timer0;
reg [15:0] timer1;
reg [15:0] timer2;
reg [15:0] timer3;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		count_wait_break <= 16'd0;
		count_interleave <= 16'd0;
		timer0 <= 16'd0;
		timer1 <= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME + 1; // set initial value higher than CURRENT_RISE_TIME + DEAD_TIME*2
		count_Toff <= 16'd0;
		occ_cnt <= 16'd0;
	end
	
	else if(is_machine == 1'b0) // no machine, reset timer
	begin
		count_wait_break <= 16'd0;
		count_interleave <= 16'd0;
		timer0 <= 16'd0;
		timer1 <= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME + 1;
		count_Toff <= 16'd0;
		occ_cnt <= 16'd0;
	end

	else
	begin
		case(next_state)
			WAIT_BREAK:
			begin
				count_wait_break <= count_wait_break + 1'b1; // per 20ns +1
				count_interleave <= 16'd0;
				timer0 <= 16'd0;
				timer1 <= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME + 1;
				count_Toff <= 16'd0;
				occ_cnt <= 16'd0;
			end
			
			INTERLEAVE:
			begin
				count_interleave <= count_interleave + 1'b1; // per 20ns +1
				occ_cnt <= occ_cnt + 1'b1; // per 20ns +1
				// timer0 4us
				if (timer0 == 16'd199) // reset timer0 per 4us
					timer0 <= 16'd0;
				else
					timer0 <= timer0 + 1'd1; // per 20ns +1
				// timer1 1us
				if(timer0 == 16'd99) // timer0 at 2us reset timer1
					timer1 <= 16'd0;
				else
					timer1 <= timer1 + 1'd1; // per 20ns +1

				count_wait_break <= 16'd0;
				count_Toff <= 16'd0;
			end

			T_OFF:
			begin
				count_wait_break <= 16'd0;
				count_interleave <= 16'd0;	
				count_Toff <= count_Toff + 1'b1; // per 20ns +1
				occ_cnt <= 16'd0;
			end
			
			default: 
			begin
				count_wait_break <= 16'd0;
				count_interleave <= 16'd0;
				timer0 <= 16'd0;
				timer1 <= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME + 1;;
				count_Toff <= 16'd0;
				occ_cnt<=16'd0;
			end
		endcase
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		timer_ts <= 16'd0;
	else if(is_machine == 1'b0) 
		timer_ts <= 16'd0;
	else
	begin
		if(timer_ts >= Ts) timer_ts <= 0;
		else timer_ts <= timer_ts + 1'b1;
	end
end

//P3:describe output PWM //pwm_open.v中存在需要讨论的问题（年后）：刚入交错时的死去时间是无法保证的，需讨论是否严格加入死区还是刚进入交错是忽略此问题！！！！！！！！！
// mosfet control
reg interleave_start;//用于在交错前先把后三路上管关闭

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
	begin 
		interleave_start <= 1'b0; 
		mos_buck <= 4'b00_00;
		mos_res <= 4'b00_00;
		OCC_flag <= 1'b0;
	end
	else if(is_machine == 1'b0) 
	begin
		interleave_start <= 1'b0; 
		mos_buck <= 4'b00_00;
		mos_res <= 4'b00_00;
		OCC_flag <= 1'b0;	
	end
	else
	begin
		case(next_state)
			WAIT_BREAK:
			begin
				mos_buck <= 4'b00_00;
				mos_res <= 4'b10_00; // wait for discharge, RES1: Qup open Qdown close
				OCC_flag <= 1'b0;
			end
			
			INTERLEAVE:
			begin
				OCC_flag <= 1'b1;
				if(interleave_start == 1'b0) 
				begin
					interleave_start <= 1'b1;
					mos_buck <= 4'b00_00;
					mos_res <= 4'b00_00;
				end
				else
				begin
					// buck1, wait DEAD_TIME before open mosfet
					if(timer0 >= 16'd0 && timer0 < DEAD_TIME)
						mos_buck[1:0] <= 2'b00; // wait DEAD_TIME for Qdown close
					else if(timer0 >= DEAD_TIME && timer0 < CURRENT_RISE_TIME + DEAD_TIME)
						mos_buck[1:0] <= 2'b10; // open Qup
					else if(timer0 >= CURRENT_RISE_TIME + DEAD_TIME && timer0 < CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME)
						mos_buck[1:0] <= 2'b00; // wait DEAD_TIME for Qup close
					else if(timer0 >= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME)
						mos_buck[1:0] <= 2'b01; // open Qdown
												
					// buck2, wait DEAD_TIME before open mosfet
					if(timer1 >= 16'd0 && timer1 < DEAD_TIME)
						mos_buck[3:2] <= 2'b00; // wait DEAD_TIME for Qdown close
					else if(timer1 >= DEAD_TIME && timer1 < CURRENT_RISE_TIME + DEAD_TIME)
						mos_buck[3:2] <= 2'b10; // open Qup for CURRENT_RISE_TIME
					else if(timer1 >= CURRENT_RISE_TIME + DEAD_TIME && timer1 < CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME)
						mos_buck[3:2] <= 2'b00; // wait DEAD_TIME for Qup close
					else if(timer1 >= CURRENT_RISE_TIME + DEAD_TIME + DEAD_TIME)
						mos_buck[3:2] <= 2'b01; // open Qdown
				end
			end
													
			T_OFF:
			begin
				OCC_flag <= 1'b0;
				interleave_start <= 1'b0;
				
				if((timer_ts >= Ts - DEAD_TIME)||(count_Toff < DEAD_TIME)) 
					mos_buck <= 4'b00_00;
				else 
					mos_buck <= 4'b01_01; // interpulse close Qup and open Qdown
			end
		endcase
	end
end

endmodule
