module para_generate//第三刀和第四刀的Ton需要特殊关注
/*#(
			  parameter Id_set_STEP = 4'd1,
			  parameter Ton_STEP = 4'd2,
			  parameter Ton_STEP3 = 4'd1,
			  parameter Ts_STEP = 4'd5,
			  parameter Ts_STEP3 = 4'd10,
			  parameter Dt_STEP = 4'd1,
			  parameter Num_on_STEP = 4'd1,
			  parameter Num_off_STEP = 4'd1
)*/
(
				//50Mhz clock
				input clk,                     
				input rst_n,
			  
				//can总线输入
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
 		  
			  //key模块输入
			  input	 [2:0] 	key_code,
			  input 		  		key2_down,
			  input		  		key3_down,
				
				//由can和key共同决定的电参数输出----seg display数码管显示
			  output reg		  Start_r1,
			  output reg		  Start_r2,
			  output reg		  Start_r3,
			  output reg		  Start_r4,	
			  output reg		  power_Start_r,
			  output reg		  panglu_r,
			  output reg		  Vneg_r,			  
			  output reg [7:0]  Id_set_r, 
			  output reg [7:0]  Ton_r,
			  output reg [15:0] Ts_r,
			  output	reg [7:0]  T_neg_r,
			  //output reg [7:0]  Num_on_r, 
			  //output reg [7:0]  Num_off_r,
			  output reg [7:0]  Dt_r,
			  
			  	//由can和key共同决定的电参数输出------PWM module转换过的量(50MHz)，用于计数
			  output 		   Start1,
			  output 		   Start2,
			  output 		   Start3,
			  output 		   Start4,
			  output				power_Start,
			  output				panglu_en,
			  output				Vneg_en,
			  output  [13:0]  Id_set, 
			  output  [15:0]  Ton,
			  output  [15:0]  Ts,
			  output	 [7:0]	T_neg,
			  output  [7:0]   Num_on, 
			  output  [7:0]   Num_off,
			  output  [15:0]  Dt
			  
			  
	 
	 );
	 // 此处参数为按键修改参数的步长
			  parameter Id_set_STEP = 4'd1;
			  parameter Ton_STEP = 4'd2;
			  parameter Ton_STEP3 = 4'd1;
			  parameter Ts_STEP = 4'd5;
			  parameter Ts_STEP234 = 4'd1;
			  parameter Dt_STEP = 4'd1;
			  //parameter Num_on_STEP = 4'd1;
			  //parameter Num_off_STEP = 4'd1;
//----------------------------------------------------------------
//can数据帧到达边沿检测
reg can_para_en_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) can_para_en_r <= 1'b0;
	else can_para_en_r <= can_para_en;
end

wire can_flag = (~can_para_en_r & can_para_en)?1'b1:1'b0;


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
			Start_r1 <= 1'b0;
			Start_r2 <= 1'b0;
			Start_r3 <= 1'b0;
			Start_r4 <= 1'b0;
			power_Start_r<=1'b0;
			panglu_r	<= 1'b0;
			Vneg_r	<= 1'b0;
			Id_set_r <= 8'd20;		
			Ton_r<= 8'd0;
			Ts_r <= 16'd50;
			T_neg_r	<= 8'd0;
			//Num_on_r <= 8'd1; 
			//Num_off_r <= 8'd0;
			Dt_r <= 8'd00;
		end
	
	else if(can_flag)	 //若can发来数据帧，则将电参数更新为can发送的数值
		begin
			Start_r1 	   <= can_para_Mode[0];
			Start_r2       <= can_para_Mode[1];
			Start_r3       <= can_para_Mode[2];			
			Start_r4       <= can_para_Mode[3];	
			power_Start_r  <= can_para_Start;
			panglu_r 	   <= can_para_panglu;
			Vneg_r	       <= can_para_Vneg;
			Id_set_r	   <= can_para_Idset;		
			Dt_r		   <= can_para_Dt;
			T_neg_r		   <= can_para_T_neg;
			
			
			if(can_para_Mode[0])
				begin
				Ts_r			<=	can_para_Ts_1;
				Ton_r			<= can_para_Ton_1;
				end
			else if(can_para_Mode[1])
				Ts_r			<=	can_para_Ts_2;			
			else if(can_para_Mode[2])
				begin
				Ts_r			<=	can_para_Ts_3;
				Ton_r			<= can_para_Ton_3;
				end
			else if(can_para_Mode[3])
				begin
				Ts_r			<=	can_para_Ts_4;
				Ton_r			<= can_para_Ton_4;
				
				end
			else;
	
			
			//Ts_r			<= ( can_para_Mode[0] * can_para_Ts_1 + can_para_Mode[1] * can_para_Ts_2 + can_para_Mode[2] * can_para_Ts_3 + can_para_Mode[3]*can_para_Ts_3);
			//Ton_r			<= ( can_para_Mode[0] * can_para_Ton_1 + can_para_Mode[2] * can_para_Ton_3 + can_para_Mode[3]*can_para_Ton_4);

			//if(can_para_Numon == 8'd0) Num_on_r <= 8'd1;
			//else Num_on_r <= can_para_Numon;
		end		
	//第1刀开始信号被人为按下
	else if(start1_rise)
		begin
			Id_set_r <= 8'd20;		
			Ton_r<= 8'd50;
			Ts_r <= 16'd450;
			//Num_on_r <= 8'd1; 
			//Num_off_r <= 8'd0;
			Dt_r <= 8'd23;			
		end
		
	//第2刀开始信号被人为按下
	else if(start2_rise)
		begin
			Id_set_r <= 8'd11;		
			Ton_r<= 8'd0;
			Ts_r <= 16'd60;
			//Num_on_r <= 8'd1; 
			//Num_off_r <= 8'd0;
			Dt_r <= 8'd25;			
		end
	
	//第3刀开始信号被人为按下
	else if(start3_rise)
		begin
			Id_set_r <= 8'd00;		
			Ton_r<= 8'd10;//表示1.0us
			Ts_r <= 16'd15;//表示15us
			//Num_on_r <= 8'd1; 
			//Num_off_r <= 8'd0;
			Dt_r <= 8'd00;			
		end

	//第4刀开始信号被人为按下
	else if(start4_rise)
		begin
			Id_set_r <= 8'd00;		
			Ton_r<= 8'd7;//表示0.7us
			Ts_r <= 16'd15;//表示15us
			//Num_on_r <= 8'd1; 
			//Num_off_r <= 8'd0;
			Dt_r <= 8'd00;			
		end


		
	else if(key2_down || key3_down) //若按键按下，则更改当前的电参数:key2++ key3--
		begin
			case(key_code)
				3'd0://修改Start
					begin
						if(key2_down && Start_r1 == 1'b0 && Start_r2 == 1'b0 && Start_r3 == 1'b0 && Start_r4 == 1'b0) begin Start_r1 <= 1'b1;Start_r2 <= 1'b0;Start_r3 <= 1'b0;Start_r4 <= 1'b0;end
						else if(key2_down && Start_r1 == 1'b1 && Start_r2 == 1'b0) begin Start_r1 <= 1'b0;Start_r2 <= 1'b1;Start_r3 <= 1'b0;Start_r4 <= 1'b0;end
						else if(key2_down && Start_r1 == 1'b0 && Start_r2 == 1'b1) begin Start_r1 <= 1'b0;Start_r2 <= 1'b0;Start_r3 <= 1'b1;Start_r4 <= 1'b0;end
						else if(key2_down && Start_r1 == 1'b0 && Start_r3 == 1'b1) begin Start_r1 <= 1'b0;Start_r2 <= 1'b0;Start_r3 <= 1'b0;Start_r4 <= 1'b1;end
						else if(key2_down && Start_r1 == 1'b0 && Start_r4 == 1'b1) begin Start_r1 <= 1'b0;Start_r2 <= 1'b0;Start_r3 <= 1'b0;Start_r4 <= 1'b0;end
						else ;
					end
					
				3'd1://修改Id_set
					begin
						if(key2_down && Id_set_r < 8'd160) Id_set_r <= Id_set_r + Id_set_STEP;
						else if(key2_down && Id_set_r >= 8'd160)Id_set_r <= Id_set_r;
						else if(key3_down && Id_set_r > 8'd5)Id_set_r <= Id_set_r - Id_set_STEP;
						else if(key3_down && Id_set_r <= 8'd5)Id_set_r <= Id_set_r;
						else ;
					end
					
				3'd2://修改Ton
					begin
						if(Start_r1||Start_r2)
							begin
							if(key2_down && (Ton_r < Ts_r - 16'd20)) Ton_r <= Ton_r + Ton_STEP;
							else if(key2_down && (Ton_r >= Ts_r - 16'd20))Ton_r <= Ton_r;
							else if(key3_down && Ton_r > 8'd0)Ton_r <= Ton_r - Ton_STEP;
							else if(key3_down && Ton_r <= 8'd0)Ton_r <= Ton_r;
							else ;
							end
						else if(Start_r3)
							begin
							if(key2_down && (Ton_r < 8'd20)) Ton_r <= Ton_r + Ton_STEP3;//第3刀的导通时间期范围在0.8~2us
							else if(key2_down && (Ton_r >=  8'd20))Ton_r <= Ton_r;//
							else if(key3_down && Ton_r > 8'd8)Ton_r <= Ton_r - Ton_STEP3;
							else if(key3_down && Ton_r <= 8'd8)Ton_r <= Ton_r;//第3刀的最小导通时间不能小于0.8us
							else ;
							end
						else if(Start_r4)
							begin
							if(key2_down && (Ton_r < 8'd20)) Ton_r <= Ton_r + Ton_STEP3;//第4刀的导通时间期范围在0.4~2us
							else if(key2_down && (Ton_r >= 8'd20))Ton_r <= Ton_r;//
							else if(key3_down && Ton_r > 8'd4)Ton_r <= Ton_r - Ton_STEP3;
							else if(key3_down && Ton_r <= 8'd4)Ton_r <= Ton_r;//第4刀的最小导通时间不能小于0.4us
							else ;
							end
						else ;
					end
					
				3'd3://修改Ts
					begin
						if(Start_r1)
							begin
							if(key2_down && Ts_r < 16'd1000) Ts_r <= Ts_r + Ts_STEP;//第1刀和第2刀的周期范围在30~1000us
							else if(key2_down && Ts_r >= 16'd1000)Ts_r <= Ts_r;
							else if(key3_down && Ts_r > 16'd30)Ts_r <= Ts_r - Ts_STEP;
							else if(key3_down && Ts_r <= 16'd30)Ts_r <= Ts_r;
							else ;
							end
						else if(Start_r2)
							begin
							if(key2_down && Ts_r < 16'd100) Ts_r <= Ts_r + Ts_STEP234;//第1刀和第2刀的周期范围在30~100us
							else if(key2_down && Ts_r >= 16'd100)Ts_r <= Ts_r;
							else if(key3_down && Ts_r > 16'd30)Ts_r <= Ts_r - Ts_STEP234;
							else if(key3_down && Ts_r <= 16'd30)Ts_r <= Ts_r;
							else ;
							end	
						else if(Start_r3||Start_r4)
							begin
							if(key2_down && Ts_r < 16'd30) Ts_r <= Ts_r + Ts_STEP234;//第3刀和第4刀的周期范围在8~30us
							else if(key2_down && Ts_r >= 16'd30)Ts_r <= Ts_r;
							else if(key3_down && Ts_r > 16'd8)Ts_r <= Ts_r - Ts_STEP234;//注意第三刀和第四刀的周期不能小于Ton+旁路切断时长
							else if(key3_down && Ts_r <= 16'd8)Ts_r <= Ts_r;
							else ;
							end
						else ;
					end
		
				3'd4://修改Dt
					begin
						if(key2_down && Dt_r < 8'd60) Dt_r <= Dt_r + Dt_STEP;
						else if(key2_down && Dt_r >= 8'd60)Dt_r <= Dt_r;
						else if(key3_down && Dt_r > 8'd1)Dt_r <= Dt_r - Dt_STEP;
						else if(key3_down && Dt_r <= 8'd1)Dt_r <= Dt_r;
						else ;
					end
					
				//3'd5://修改Num_on
					
						//Num_on_r <=8'd1; 
					/*begin
						
						/*if(key2_down && Num_on_r < 8'd30) Num_on_r <= Num_on_r + Num_on_STEP;
						else if(key2_down && Num_on_r >= 8'd30)Num_on_r <= Num_on_r;
						else if(key3_down && Num_on_r > 8'd1)Num_on_r <= Num_on_r - Num_on_STEP;//至少为1
						else if(key3_down && Num_on_r <= 8'd1)Num_on_r <= Num_on_r;
						else ;
					end*/
					
				//3'd6://修改Num_off
					//Num_off_r <= 8'd0;
					/*begin
						if(key2_down && Num_off_r < 8'd30) Num_off_r <= Num_off_r + Num_off_STEP;
						else if(key2_down && Num_off_r >= 8'd30)Num_off_r <= Num_off_r;
						else if(key3_down && Num_off_r > 8'd0)Num_off_r <= Num_off_r - Num_off_STEP;
						else if(key3_down && Num_off_r <= 8'd0)Num_off_r <= Num_off_r;
						else ;
					end*/
					
				default: ;
					
			endcase
		end
	
end

//--------显示值与实际计数值/实际电压电流点数转换，准备进入PWM模块-------//
assign Start1 = Start_r1;
assign Start2 = Start_r2;
assign Start3 = Start_r3;
assign Start4 = Start_r4;
assign power_Start = power_Start_r;
assign panglu_en = panglu_r;
assign Vneg_en	  = Vneg_r;
assign Id_set = Id_set_r * 14'd102;
//assign Num_on = Num_on_r;
//assign Num_off = Num_off_r;
assign Dt = Dt_r * 8'd2 ;
assign Ts = Ts_r * 8'd50;
assign T_neg = T_neg_r * 8'd5;//传送的为0~100（表示0~10us,即为计数值的0~500），所以乘5

assign Ton = (Start1||Start2)? Ton_r * 8'd50 : Ton_r * 8'd5;//第1、2刀传0~120（表示0~120us,即计数值的0~6000），所以乘50
																				//第3、4刀传04~20（表示0.4us~2.0us，即计数值的20~100），所以乘5

//assign TON = Ton * 16'd50;
//assign Ts = Ts_r * 16'd50;

//--------------------------------------------------------------------
//自动切换对应电参数
reg start1_reg,start2_reg,start3_reg,start4_reg;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		start1_reg <= 1'b0;
		start2_reg <= 1'b0;
		start3_reg <= 1'b0;
		start4_reg <= 1'b0;
		
		end
	else 
		begin
		start1_reg <= Start_r1;
		start2_reg <= Start_r2;
		start3_reg <= Start_r3;
		start4_reg <= Start_r4;
		
		end		
end

wire start1_rise = (Start_r1 && ~start1_reg)?1'b1:1'b0;
wire start2_rise = (Start_r2 && ~start2_reg)?1'b1:1'b0;
wire start3_rise = (Start_r3 && ~start3_reg)?1'b1:1'b0;
wire start4_rise = (Start_r4 && ~start4_reg)?1'b1:1'b0;


endmodule


