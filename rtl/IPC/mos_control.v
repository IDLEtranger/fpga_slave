module mos_control
#(
	parameter DEAD_TIME = 16'd10; // Because of the extra diodes, the dead time can be long but not short.
	parameter WAIT_BREAKDOWN_MAXTIME = 16'd250;
	parameter WAIT_BREAKDOWN_MINTIME = 16'd50;
	parameter MAX_CURRENT_LIMIT = 16'd16320;
	parameter CURRENT_RISE_THRESHOLD = 16'd500;
	parameter BREAKDOWN_THRESHOLD_CUR = 16'd300;
	parameter BREAKDOWN_THRESHOLD_VOL = 12'd500;
)
(
	input clk, // 100MHz 10ns
	input rst_n,

	// pulse generate parameter
	input is_machine_start, // 1'b1: machine start, 1'b0: machine stop
	input [15:0] waveform_data,
	/*
		0: buck rectangular wave
		1: buck sawtooth wave
		2: resister discharge
	*/
	input [15:0] Ip, // specified current	
	input [15:0] Ton, // discharge time (us)
	input [15:0] Ts, // Ts = Twaitbreakdown + Ton + Tofff (a discharge cycle) (us)
	
	// via inductor charging time control average current
	input [7:0]	inductor_charging_time,
	output reg [7:0] current_state,

	output reg [15:0] timer_buck_rectangle_interleave,
	output reg occ_flag,
	
	// adc
	input [16:0] sample_current,
	input [16:0] sample_voltage,
	
	// output mosfet control signal
	output reg [1:0] mosfet_buck1, // Buck1:上管 下管
	output reg [1:0] mosfet_buck2, // Buck2:上管 下管
	output reg [1:0] mosfet_res1, // Res1:上管 下管
	output reg [1:0] mosfet_res2, // Res2:上管 下管
	output reg mosfet_deion, // Qoff 消电离回路
);

localparam BUCK_RECTANGLE_WAVE = 16'd0;
localparam BUCK_SAWTOOTH_WAVE = 16'd1;
localparam RESISTOR_DISCHARGE_WAVE = 16'd2;

// current correction
reg [15:0] corrected_current;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		corrected_current <= 15'd0;
	else 
		corrected_current <= sample_current;
end	

reg [15:0] unsigned_current;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		unsigned_current <= 15'd0;
	else 
	begin
		if(corrected_current[15] == 1'b1)
			unsigned_current <= 15'd0;
		else
			unsigned_current <= corrected_current;
	end
end	

reg [15:0] total_current;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		total_current <= 15'd0;
	else 
	begin
		total_current <= {sample_current,1'b0}; // single path current multiply 2 as the total current
	end
end				

// is_overcurrent protection
reg is_overcurrent;
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) 
		is_overcurrent <= 1'b0;
	else if(total_current > MAX_CURRENT_LIMIT) 
		is_overcurrent <= 1'b1;
	else 
		is_overcurrent <= 1'b0;
end 

// is_operation 
reg is_operation;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		is_operation <= 1'b1;
	else if((is_overcurrent) || (is_machine_start == 1'b0))
		is_operation <= 1'b0;
	else 
		is_operation <= 1'b1;
end

// occ_flag
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		occ_flag <= 1'b0;
	else if( current_state == S_BUCK_RECTANGLE_INTERLEAVE )
		occ_flag <= 1'b1;
	else
		occ_flag <= 1'b0;
end

/******************* state shift *******************/
localparam S_WAIT_BREAKDOWN = 8'b00000001;
localparam S_DEION = 8'b10000000;
// buck rectangular wave
localparam S_BUCK_RECTANGLE_CURRENT_RISE = 8'b00000010;
localparam S_BUCK_RECTANGLE_INTERLEAVE = 8'b00000100;
// buck sawtooth wave
localparam S_BUCK_SAWTOOTH = 8'b00001000;
// resister discharge
localparam S_RES_DISCHARGE = 8'b00010000;

reg [7:0] current_state;
reg [7:0] next_state;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		current_state <= S_DEION;
	else 
		current_state <= next_state;
end

always@(*)
begin
	case(current_state)
		S_DEION:
		begin	
			if(timer_Ts >= Ts && is_operation == 1'b1)
				next_state = S_WAIT_BREAKDOWN;
			else 
				next_state <= S_DEION;
		end

		S_WAIT_BREAKDOWN:
		begin
			if((timer_wait_breakdown > WAIT_BREAKDOWN_MINTIME) \ 
				&& (timer_wait_breakdown < WAIT_BREAKDOWN_MAXTIME) \
				&& (unsigned_current >= BREAKDOWN_THRESHOLD_CUR) \ 
				&& (sample_voltage < BREAKDOWN_THRESHOLD_VOL) \
				&& (is_operation == 1'b1) \ 
				&& (waveform_data == BUCK_RECTANGLE_WAVE) )
				next_state = S_BUCK_RECTANGLE_CURRENT_RISE;
			else if((timer_wait_breakdown > WAIT_BREAKDOWN_MINTIME) \ 
				&& (timer_wait_breakdown < WAIT_BREAKDOWN_MAXTIME) \
				&& (unsigned_current >= BREAKDOWN_THRESHOLD_CUR) \ 
				&& (sample_voltage < BREAKDOWN_THRESHOLD_VOL) \
				&& (is_operation == 1'b1) \ 
				&& (waveform_data == BUCK_SAWTOOTH_WAVE) )
				next_state == S_BUCK_SAWTOOTH;
			else if((timer_wait_breakdown > WAIT_BREAKDOWN_MINTIME) \ 
				&& (timer_wait_breakdown < WAIT_BREAKDOWN_MAXTIME) \
				&& (unsigned_current >= BREAKDOWN_THRESHOLD_CUR) \ 
				&& (sample_voltage < BREAKDOWN_THRESHOLD_VOL) \
				&& (is_operation == 1'b1) \ 
				&& (waveform_data == S_RES_DISCHARGE) )
				next_state == S_RES_DISCHARGE;
			else if( timer_wait_breakdown >= WAIT_BREAKDOWN_MAXTIME || is_operation == 1'b0 ) 
				next_state = S_DEION;
			else
				next_state = S_WAIT_BREAKDOWN; 
		end	

		// buck rectangular wave
		S_BUCK_RECTANGLE_CURRENT_RISE:
		begin
			if( total_current >= CURRENT_RISE_THRESHOLD
				&& (is_operation == 1'b1) ) 
				next_state = S_BUCK_RECTANGLE_INTERLEAVE;
			else if( is_operation == 1'b0 )
				next_state = S_DEION;
			else
				next_state = S_BUCK_RECTANGLE_CURRENT_RISE;
		end

		S_BUCK_RECTANGLE_INTERLEAVE:
		begin
			if(timer_buck_rectangle_interleave >= Ton || is_operation == 1'b0) 
				next_state = S_DEION; 
			else
				next_state = S_BUCK_RECTANGLE_INTERLEAVE;
		end

		// buck sawtooth wave
		S_BUCK_SAWTOOTH:
		begin
			if(timer_buck_sawtooth_discharge >= Ton || is_operation == 1'b0) 
				next_state = S_DEION;
			else
				next_state = S_BUCK_SAWTOOTH;
		end
		// resister discharge
		S_RES_DISCHARGE:
		begin
			if(timer_buck_sawtooth_discharge >= Ton || is_operation == 1'b0) 
				next_state = S_DEION;
			else
				next_state = S_RES_DISCHARGE;
		end
		default:
			next_state = S_DEION;
	endcase
end
/******************* end state shift *******************/

/******************* mosfet control *******************/
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
	begin 
		mosfet_buck1 <= 2'b00;
		mosfet_buck2 <= 2'b00;
		mosfet_res1 <= 2'b00;
		mosfet_res2 <= 2'b00;
		mosfet_deion <= 1'b0;
	end
	else
	begin
		case(current_state)
			S_WAIT_BREAKDOWN:
			begin
				mosfet_buck1 <= 2'b00;
				mosfet_buck2 <= 2'b00;
				mosfet_res1 <= 2'b10; // wait for discharge, RES1: Qup turn on Qdown turn off
				mosfet_res2 <= 2'b00;
				mosfet_deion <= 1'b0;
			end

			S_DEION: // The state of mosfet is uncertain when entering the S_DEION state
			begin
				// deal with dead time
				if(timer_deion < DEAD_TIME)
				begin
					if(mosfet_buck1 == 2'b10)
						mosfet_buck1 <= 2'b00;
					if(mosfet_buck2 <= 2'b10)
						mosfet_buck2 <= 2'b00;
					
					mosfet_res1 <= 2'b01;
					mosfet_res2 <= 2'b01;
				end
				else if(timer_Ts >= Ts - DEAD_TIME) // before into S_WAIT_BREAKDOWN, turn off all mosfet to ensure dead time
				begin
					mosfet_buck1 <= 2'b00;
					mosfet_buck2 <= 2'b00;
					mosfet_res1 <= 2'b00;
					mosfet_res2 <= 2'b00;
					mosfet_deion <= 1'b0;
				end
				else 
				begin
					mosfet_buck1 <= 2'b01; // interpulse state, turn off Qup and turn on Qdown
					mosfet_buck2 <= 2'b01;
					mosfet_res1 <= 2'b01;
					mosfet_res2 <= 2'b01;
					mosfet_deion <= 1'b1;
				end
			end
			
			/******************* buck rectangular wave *******************/
			S_BUCK_RECTANGLE_CURRENT_RISE:
			begin
				mosfet_buck1 <= 2'b10; // turn on buck1 (Qup on Qdown off)
				mosfet_buck2 <= 2'b10; // turn on buck2 (Qup on Qdown off)
				mosfet_res1 <= 2'b01; // turn off RES1 (Qup off Qdown on)
			end

			S_BUCK_RECTANGLE_INTERLEAVE:
			if(timer_buck_rectangle_interleave <= DEAD_TIME)
			begin
				mosfet_buck2 <= 2'b00; // before into S_BUCK_RECTANGLE_INTERLEAVE, turn off buck2 to ensure dead time
			end
			else
			begin
				// buck1, wait DEAD_TIME before turn on mosfet
				if(timer_buck_4us_0 >= 16'd0 && timer_buck_4us_0 < DEAD_TIME)
					mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qdown turn off
				else if(timer_buck_4us_0 >= DEAD_TIME && timer_buck_4us_0 < inductor_charging_time + DEAD_TIME)
					mosfet_buck1 <= 2'b10; // charge inductor
				else if(timer_buck_4us_0 >= inductor_charging_time + DEAD_TIME && timer_buck_4us_0 < inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qup turn off
				else if(timer_buck_4us_0 >= inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck1 <= 2'b01; // discharge inductor
											
				// buck2, wait DEAD_TIME before turn on mosfet
				if(timer_buck_4us_180 >= 16'd0 && timer_buck_4us_180 < DEAD_TIME)
					mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qdown turn off
				else if(timer_buck_4us_180 >= DEAD_TIME && timer_buck_4us_180 < inductor_charging_time + DEAD_TIME)
					mosfet_buck2 <= 2'b10; // charge inductor
				else if(timer_buck_4us_180 >= inductor_charging_time + DEAD_TIME && timer_buck_4us_180 < inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qup turn off
				else if(timer_buck_4us_180 >= inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck2 <= 2'b01; // discharge inductor
			end
			
			/******************* buck sawtooth wave *******************/
			S_BUCK_SAWTOOTH:
			begin
				if(timer_res_discharge <= 16'd0 && timer_buck_4us_0 < DEAD_TIME)
					mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qdown turn off
					mosfet_buck2 <= 2'b00;
				else if(timer_buck_4us_0 >= DEAD_TIME && timer_buck_4us_0 < inductor_charging_time + DEAD_TIME)
					mosfet_buck1 <= 2'b10; // charge inductor
					mosfet_buck2 <= 2'b10;
				else if(timer_buck_4us_0 >= inductor_charging_time + DEAD_TIME && timer_buck_4us_0 < inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qup turn off
					mosfet_buck2 <= 2'b00;
				else if(timer_buck_4us_0 >= inductor_charging_time + DEAD_TIME + DEAD_TIME)
					mosfet_buck1 <= 2'b01; // discharge inductor
					mosfet_buck2 <= 2'b01;
			end

			/******************* res discharge *******************/
			S_RES_DISCHARGE:
			begin
				if(timer_res_discharge <= Ton)
					mosfet_res1 <= 2'b10;
				else
					mosfet_res1 <= 2'b01;
			end

		endcase
	end
end

// timer
reg [15:0] timer_Ts; // every 10ns ++, reset every Ts us
reg [15:0] timer_wait_breakdown; // in S_WAIT_BREAKDOWN every 10ns ++, reset when leave S_WAIT_BREAKDOWN
reg [15:0] timer_deion; // in S_DEION every 10ns ++, reset when leave S_DEION

// buck rectangular wave timer
reg [15:0] timer_buck_rectangle_current_rise; // in S_BUCK_RECTANGLE_CURRENT_RISE every 10ns ++, reset when leave S_BUCK_RECTANGLE_CURRENT_RISE
reg [15:0] timer_buck_rectangle_interleave; // in S_BUCK_RECTANGLE_INTERLEAVE every 10ns ++, reset when leave S_BUCK_RECTANGLE_INTERLEAVE
reg [15:0] timer_buck_4us_0; // in S_BUCK_RECTANGLE_INTERLEAVE every 10ns ++, reset every 4us
reg [15:0] timer_buck_4us_180; // reset when timer_buck_4us_0 reaches 2us, ends in inductor_charging_time + DEAD_TIME + DEAD_TIME
// buck sawtooth wave timer
reg [15:0] timer_buck_sawtooth_discharge; // in S_BUCK_SAWTOOTH every 10ns ++, reset when leave S_BUCK_SAWTOOTH
// res discharge timer
reg [15:0] timer_res_discharge; // in S_RES_DISCHARGE every 10ns ++, reset when leave S_RES_DISCHARGE

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		timer_Ts <= 16'd0;
	else if(next_state == S_WAIT_BREAKDOWN && current_state != S_WAIT_BREAKDOWN) 
		timer_Ts <= 16'd0;
	else
	begin
		if(timer_Ts >= Ts) 
			timer_Ts <= 0;
		else 
			timer_Ts <= timer_Ts + 1'b1; // per 10ns +1
	end
end
// timer_deion
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_deion <= 16'd0;
	else if(current_state == S_DEION)
		timer_deion <= timer_deion + 1'b1; // per 10ns +1
	else
		timer_deion <= 16'd0;
end
// timer_wait_breakdown
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_wait_breakdown <= 16'd0;
	else if(current_state == S_WAIT_BREAKDOWN)
		timer_wait_breakdown <= timer_wait_breakdown + 1'b1; // per 10ns +1
	else
		timer_wait_breakdown <= 16'd0;
end

/******************* rectangular wave timer *******************/
// timer_buck_rectangle_current_rise
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_rectangle_current_rise <= 16'd0;
	else if(current_state == S_BUCK_RECTANGLE_CURRENT_RISE)
		timer_buck_rectangle_current_rise <= timer_buck_rectangle_current_rise + 1'b1; // per 10ns +1
	else
		timer_buck_rectangle_current_rise <= 16'd0;
end
// timer_buck_rectangle_interleave
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_rectangle_interleave <= 16'd0;
	else if(current_state == S_BUCK_RECTANGLE_INTERLEAVE)
		timer_buck_rectangle_interleave <= timer_buck_rectangle_interleave + 1'b1; // per 10ns +1
	else
		timer_buck_rectangle_interleave <= 16'd0;
end
// timer_buck_4us_0
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_4us_0 <= 16'd0;
	else if(current_state == S_BUCK_RECTANGLE_INTERLEAVE \ 
			|| current_state == S_BUCK_SAWTOOTH)
	begin
		if (timer_buck_4us_0 == 16'd399) // reset timer_buck_4us_0 per 4us
			timer_buck_4us_0 <= 16'd0;
		else
			timer_buck_4us_0 <= timer_buck_4us_0 + 1'd1; // per 10ns +1
	end
	else
		timer_buck_4us_0 <= 16'd0;
end
// timer_buck_4us_180
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_4us_180 <= inductor_charging_time + DEAD_TIME + DEAD_TIME + 1; // set initial value exceed inductor_charging_time + DEAD_TIME*2, make sure timer_buck_4us_180 is invalid before timer_buck_4us_0 reset it at 2us
	else if(current_state == S_BUCK_RECTANGLE_INTERLEAVE)
	begin
		if(timer_buck_4us_0 == 16'd199) // timer_buck_4us_0 at 2us reset timer_buck_4us_180
			timer_buck_4us_180 <= 16'd0;
		else if(timer_buck_4us_180 <= inductor_charging_time + DEAD_TIME + DEAD_TIME)
			timer_buck_4us_180 <= timer_buck_4us_180 + 1'd1; // per 10ns +1
		else
			timer_buck_4us_180 <= timer_buck_4us_180
	end
	else
		timer_buck_4us_180 <= inductor_charging_time + DEAD_TIME + DEAD_TIME + 1;
end

/******************* sawtooth wave timer *******************/
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_sawtooth_discharge <= 16'd0;
	else if(current_state == S_BUCK_SAWTOOTH)
		timer_buck_sawtooth_discharge <= timer_buck_sawtooth_discharge + 1'b1; // per 10ns +1
	else
		timer_buck_sawtooth_discharge <= 16'd0;
end
/******************* res discharge timer *******************/
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_res_discharge <= 16'd0;
	else if(current_state == S_RES_DISCHARGE)
		timer_res_discharge <= timer_res_discharge + 1'b1; // per 10ns +1
	else
		timer_res_discharge <= 16'd0;
end
endmodule
