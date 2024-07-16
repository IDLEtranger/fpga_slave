module avg
(
    input clk_65M, // ad clk
	input clk_100M, // sys clk
    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in,
	input rst_n,
    input feedback_finish,
	
	output reg [15:0] avg_vol
);

reg [63:0] sum_vol;
reg [31:0] count;

always @(posedge ad_clk or negedge rst_n)
begin
    if(rst_n == 1'b0 || feedback_finish == 1'b1)
    begin
        sum_vol <= 64'b0;
        count <= 32'b0;
    end
    else
    begin
        sum_vol <= sum_vol + sample_vol;
        count <= count + 1;
    end
end

wire [63:0] avg_vol_temp;
always@(posedge clk or negedge rst_n)
begin
    if (avg_vol_temp > 16'hFFFF)
        avg_vol <= 16'hFFFF;
    else
        avg_vol <= avg_vol_temp[15:0];
end

ad_sample ad_sample_inst
(
    .sys_clk(clk_100M),
    .ad_clk(clk_65M),
    .rst_n(rst_n),

    .ad1_in(ad1_in),
    .ad2_in(ad2_in),

    .sample_current_fifo_out(sample_current), // synchronized to sys_clk
    .sample_voltage_fifo_out(sample_voltage)
);

divider_64d32	divider_64d32_inst 
(
	.clock ( clk_100M ),
	.denom ( count ),
	.numer ( sum_vol ),
	.quotient ( avg_vol_temp ),
	.remain (  )
);
endmodule