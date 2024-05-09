module AvgFilter
(
	input clk,
	input rst_n,
	
	input [11:0] ad_ch2,
	output reg [11:0] filtered_vol
);
//除去符号位
reg [11:0] ad_ch2_reg;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) ad_ch2_reg <= 12'd0;
	else if(ad_ch2[11]) ad_ch2_reg <= 12'd0;
	else ad_ch2_reg <= ad_ch2;
end

//滑动滤波
reg [11:0] ad_pipe [6:0];
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		ad_pipe[0] <= 12'd0;
		ad_pipe[1] <= 12'd0;
		ad_pipe[2] <= 12'd0;
		ad_pipe[3] <= 12'd0;
		ad_pipe[4] <= 12'd0;
		ad_pipe[5] <= 12'd0;
		ad_pipe[6] <= 12'd0;
		end
		
	else 
		begin
		ad_pipe[0] <= ad_ch2_reg;
		ad_pipe[1] <= ad_pipe[0];
		ad_pipe[2] <= ad_pipe[1];
		ad_pipe[3] <= ad_pipe[2];
		ad_pipe[4] <= ad_pipe[3];
		ad_pipe[5] <= ad_pipe[4];
		ad_pipe[6] <= ad_pipe[5];
		end
end

reg [14:0] ad_sum1;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) ad_sum1 <= 15'd0;
	else ad_sum1 <= ad_pipe[6] + ad_pipe[5] + ad_pipe[4] + ad_pipe[3];
end

reg [14:0] ad_sum2;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) ad_sum2 <= 15'd0;
	else ad_sum2 <= ad_pipe[2] + ad_pipe[1] + ad_pipe[0] + ad_ch2_reg;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) filtered_vol <= 12'd0;
	else filtered_vol <= ((ad_sum1 + ad_sum2) >> 3);//4路则除8，1路则除2
end				


endmodule
