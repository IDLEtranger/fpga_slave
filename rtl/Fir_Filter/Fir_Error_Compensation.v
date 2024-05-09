/*
fir 误差补偿模块
*/
module Fir_Error_Compensation(
									input clk,
									input rst_n,
									
									//fir output
									input signed [11:0] o_filter_out,
									
									//after compensation
									output [11:0] o_filter_acc
									
);

//-------------------------------------------->delay1
//先把滤波器输出处理为无符号数
reg [11:0] unsigned_filter_out;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) unsigned_filter_out <= 12'd0;
	else unsigned_filter_out <= o_filter_out + 12'd2048;
end


//--------------------------------------------->delay2
//除法器IP例化
wire [11:0] num_of_50;
Fir_Div_IP	Fir_Div_IP_inst (
	.clock ( clk ),
	.denom ( 12'd50 ),
	.numer ( unsigned_filter_out ),
	.quotient ( num_of_50 ),
	.remain (  )
	);

//--------------------------------------------->delay3
//以+2048后，除以50的倍数进行补偿
reg [11:0] compen_data;
always@(*)
begin
	case(num_of_50)
		0,1,2,3,4,5,6: compen_data = 12'd300;
					7  : compen_data = 12'd285;
					8  : compen_data = 12'd277;
					9  : compen_data = 12'd270;
					10 : compen_data = 12'd263;
					11 : compen_data = 12'd255;
					12 : compen_data = 12'd240;
					13 : compen_data = 12'd233;
					14 : compen_data = 12'd225;
					15 : compen_data = 12'd218;
					16 : compen_data = 12'd210;
					17 : compen_data = 12'd202;
					18 : compen_data = 12'd195;
					19 : compen_data = 12'd180;
					20 : compen_data = 12'd172;
					21 : compen_data = 12'd165;
					22 : compen_data = 12'd158;
					23 : compen_data = 12'd150;
					24 : compen_data = 12'd142;
					25 : compen_data = 12'd135;
					26 : compen_data = 12'd120;
					27 : compen_data = 12'd112;
					28 : compen_data = 12'd105;
					29 : compen_data = 12'd98;
					30 : compen_data = 12'd90;
					31 : compen_data = 12'd82;
					32 : compen_data = 12'd75;
					33 : compen_data = 12'd60;
					34 : compen_data = 12'd52;
					35 : compen_data = 12'd45;
					36 : compen_data = 12'd28;
					37 : compen_data = 12'd30;
					38 : compen_data = 12'd15;
					39 : compen_data = 12'd8;
					40 : compen_data = 12'd0;
					
					
					41 : compen_data = 12'd8;
					42 : compen_data = 12'd15;
					43 : compen_data = 12'd30;
					44 : compen_data = 12'd28;
					45 : compen_data = 12'd45;
					46 : compen_data = 12'd52;
					47 : compen_data = 12'd60;
					48 : compen_data = 12'd75;
					49 : compen_data = 12'd82;
					50 : compen_data = 12'd90;
					51 : compen_data = 12'd98;
					52 : compen_data = 12'd105;
					53 : compen_data = 12'd112;
					54 : compen_data = 12'd120;
					55 : compen_data = 12'd135;
					56 : compen_data = 12'd142;
					57 : compen_data = 12'd150;
					58 : compen_data = 12'd165;
					59 : compen_data = 12'd172;
					60 : compen_data = 12'd180;
					
					default:compen_data = 12'd0;
	endcase
end

//---------------------------------------------
//补偿后输出
assign o_filter_acc = (num_of_50 > 12'd40)?(unsigned_filter_out + compen_data):((unsigned_filter_out>12'd300)?(unsigned_filter_out-compen_data):12'd0);



endmodule 