// fs = 250kHz(4us)   L = 3.3uH
// output delay 6 cycles
module one_cycle_control
#(
	parameter Vin = 16'd120, // input voltage 120V
	parameter L = 16'd3300, // inductance(uH) 3.3uH = 3300nH
	parameter fs = 16'd250, // frequency 250kHz (Ts = 4us)
	parameter V_GAP_FIXED = 16'd25 // discharge gap voltage
)
(
	input clk,
	input rst_n,
	
	input [15:0] sample_current,
	input [15:0] sample_voltage,

	input [15:0] timer_buck_4us_0,

	input [15:0] i_set, // total current，iref = i_set / 2 (number of channels)
		
	output reg [15:0] inductor_charging_time
);

reg [15:0] sample_current_reg;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		sample_current_reg <= 13'd0;
	else 
	begin
		if(sample_current < 0)
			sample_current_reg <= 16'd0;
		else
			sample_current_reg <= sample_current;
	end
end

//每个开关频率开始时刻触发采样
reg [15:0] Id_in_Ts;
reg	[15:0] V_gap;
reg [7:0] i_ref;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
	begin
		Id_in_Ts <= 12'd0;
		V_gap <= 12'd25;
		i_ref <= 8'd0;
	end
	else
	begin
		if(timer_buck_4us_0 == 16'b0)
		begin
			Id_in_Ts <= sample_current_reg;
			//V_gap <= sample_voltage;
			V_gap <= V_GAP_FIXED; // set a fixed discharge gap voltage value for test
			if(i_set > 100)
				i_ref <= 8'd50;
			else
				i_ref <= (i_set >> 1); // i_ref = i_set / 2 (2 channels)
		end
	end
end

reg signed [31:0] Vin_Vgap; // Vin-Vgap
reg signed [31:0] Lxfsx106; // L*fs
reg signed [31:0] Vinx2; // 2*Vin
reg signed [31:0] iref_id_i; // i_ref - id_i
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		Vin_Vgap <= 31'd0;
		Lxfsx106 <= 31'd0;
		Vinx2 <= 31'd0;
		iref_id_i <= 31'd0;
	end
	else
	begin
		Vin_Vgap <= Vin - V_gap; // Vin - Vgap
		Lxfsx106 <= L * fs; // L*fs*10^6
		Vinx2 <= Vin * 2; // 2*Vin
		if(i_ref - Id_in_Ts < 0)
			iref_id_i <= -32'd5;
		else
			iref_id_i <= i_ref - Id_in_Ts;
	end
end

reg signed [63:0] numerator1;
reg signed [63:0] numerator2;
reg signed [31:0] denominator1;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		numerator1 <= 64'd0;
		numerator2 <= 64'd0;
		denominator1 <= 32'd0;
	end

	else
	begin
		numerator1 <= V_gap * (Vin_Vgap) * 1_000_000; // Vgap*(Vin - Vgap)
		numerator2 <= Vinx2 * Lxfsx106 * iref_id_i; // 2*Vin*L*fs*(i_ref - id_i)*10^6
		denominator1 <= Vinx2 * Vin_Vgap; // 2Vin*(Vin - Vgap)
	end
end

reg signed [63:0] sum_numerators;
always@(posedge clk or negedge rst_n)  //102*(2vin-V_gap)*(vin-V_gap)
begin
	if(rst_n == 1'b0)
		sum_numerators <= 64'd0;
	else
		sum_numerators <= numerator1 + numerator2;
end

wire [19:0] inductor_charging_time_x1000000;
divider_64d32	divider_64d32_inst 
(
	.clock ( clk ),
	.denom ( denominator1 ),
	.numer ( sum_numerators ),
	.quotient ( inductor_charging_time_x1000000 ),
	.remain (  )
);

reg [31:0] inductor_charging_time_reg;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		inductor_charging_time_reg <= 31'd0;
	else
		inductor_charging_time_reg <= inductor_charging_time_x1000000 * 400 / 1_000_000 ; // 4us = 400 clk
end

always@(posedge clk or negedge rst_n)  
begin
	if(rst_n == 1'b0)
			inductor_charging_time <= 16'd0;
	else if (timer_buck_4us_0 != 16'b0)
	begin
		if((inductor_charging_time_reg > 16'd400))
			inductor_charging_time <= 16'd0;
		else if((inductor_charging_time_reg > 13'd180 )&&(inductor_charging_time_reg <= 13'd400))
			inductor_charging_time <= 16'd180; // keep the inductor charging time below 30% of the cycle
		else
			inductor_charging_time <= inductor_charging_time_reg[15:0];
	end
	else 
		inductor_charging_time <= 16'd0;
end

endmodule