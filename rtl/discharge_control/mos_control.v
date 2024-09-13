module mos_control
#(
	parameter DEAD_TIME = 16'd10, // Because of the extra diodes, the dead time can be long but not short.
	parameter WAIT_BREAKDOWN_MAXTIME = 16'd10000, // 50us
	parameter WAIT_BREAKDOWN_MINTIME = 16'd80, // 0.8us
	parameter signed MAX_CURRENT_LIMIT = 16'd76,

	// breakdown_detect
	parameter signed DEION_THRESHOLD_VOL = 16'd8,
	parameter signed BREAKDOWN_THRESHOLD_CUR = 16'd10,
	parameter signed BREAKDOWN_THRESHOLD_VOL = 16'd40,
	parameter signed BREAKDOWN_THRESHOLD_TIME = 16'd10, // 10ns*BREAKDOWN_THRESHOLD_TIME after the current & voltage meet the conditions, it is considered a breakdown

	// one cycle control (OCC)
	parameter INPUT_VOL = 16'd120, // input voltage 120V
	parameter INDUCTANCE =  16'd3300, // inductance(uH) 3.3uH = 3300nH
	parameter V_GAP_FIXED = 16'd10, // discharge gap voltage

	// openloop_control
	parameter CURRENT_STAND_CHARGING_TIMES = 16'd80, // current stand duty cycle
    parameter CURRENT_RISE_CHARGING_TIMES = 16'd120, // current rise duty cycle
    parameter CURRENT_RISE_CYCLE_TIMES = 16'd3, // current rise cycles
	parameter BUCK_INTERLEAVE_DELAY_TIME = 16'd0
)
(
	input clk, // 100MHz 10ns
	input rst_n,

	// pulse generate parameter
	input is_machine, // 1'b1: machine start, 1'b0: machine stop
	input [15:0] waveform,
	input [15:0] Ip, // specified current	
	input [15:0] Ton, // discharge time (us)
	input [15:0] Toff, // Ts = Twaitbreakdown + Ton + Tofff (a discharge cycle) (us)
	
	// adc
	input signed [15:0] sample_current,
	input signed [15:0] sample_voltage,

	// single discharge key press
	input signle_discharge_button_pressed,
	
	// output mosfet control signal
	output reg [1:0] mosfet_buck1, // Buck1:upper_mosfet lower_mosfet
	output reg [1:0] mosfet_buck2, // Buck2:upper_mosfet lower_mosfet
	output reg [1:0] mosfet_res1, // Res1:upper_mosfet lower_mosfet
	output reg [1:0] mosfet_res2, // Res2:upper_mosfet lower_mosfet
	output reg mosfet_deion, // Qoff deion circuit
	// operation indicator
	output reg is_operation,
	// single discharge indicator
	output reg will_single_discharge,
	// breakdown indicator
	output is_breakdown
);
/*!!!!!!!!!!!!!!!!!!!!!!!!! waveform !!!!!!!!!!!!!!!!!!!!!!!!!*/
/*
	x000_0000_0000_0000; x=0: BUCK discharge, x=1: RES discharge
	0x00_0000_0000_0000; x=0: continue discharge, x=1: single discharge
	00x0_0000_0000_0000; x=0: openloop, x=1: closedloop
*/
localparam BUCK_OR_RES_BIT = 15;
localparam CONTINUE_OR_SINGLE_BIT = 14;
localparam OPEN_OR_CLOSE_BIT = 13;

localparam WAVE_RES_CO_DISCHARGE = 16'b1000_0000_0000_0000; // 0x8000

localparam WAVE_BUCK_CC_RECTANGLE_DISCHARGE = 16'b0010_0000_0000_0001; // 0x2001
localparam WAVE_BUCK_CC_TRIANGLE_DISCHARGE = 16'b0010_0000_0000_0010; // 0x2002
localparam WAVE_BUCK_SC_RECTANGLE_DISCHARGE = 16'b0110_0000_0000_0001; // 0x6001
localparam WAVE_BUCK_SO_RECTANGLE_DISCHARGE = 16'b0100_0000_0000_0001; // 0x4001

reg signed [15:0] total_current;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		total_current <= 16'd0;
	else 
	begin
		total_current <= sample_current; // single path current multiply 2 as the total current
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
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		is_operation <= 1'b0;
	else if((is_overcurrent == 1'b0) && (is_machine == 1'b1))
		is_operation <= 1'b1;
	else 
		is_operation <= 1'b0;
end

/************************** timer define **************************/
reg [31:0] timer_wait_breakdown; // in S_WAIT_BREAKDOWN every 10ns ++, reset when leave S_WAIT_BREAKDOWN

reg [31:0] timer_deion; // in S_DEION every 10ns ++, reset when leave S_DEION
reg [63:0] timer_deion_single_buck; // in S_DEION_SINGLE_BUCK every 10ns ++, reset when leave S_DEION_SINGLE_BUCK

reg [15:0] timer_after_start_single; // in S_DEION_SINGLE_BUCK, after will_single_discharge == 1'b1, every 10ns ++
wire [15:0] timer_after_breakdown; // in S_WAIT_BREAKDOWN after is_breakdown == 1'b1, every 10ns ++, reset when go into S_BUCK_INTERLEAVE

// buck wave timer
reg [15:0] timer_cycle_num;
reg [15:0] timer_buck_4us_0; // in S_BUCK_INTERLEAVE every 10ns ++, reset every 4us
reg [15:0] timer_buck_4us_180; // reset when timer_buck_4us_0 reaches 2us, ends in inductor_charging_time_0 + DEAD_TIME + DEAD_TIME

reg [31:0] timer_buck_interleave; // in S_BUCK_INTERLEAVE every 10ns ++, reset when leave S_BUCK_INTERLEAVE

// res discharge timer
reg [31:0] timer_res_discharge; // in S_RES_DISCHARGE every 10ns ++, reset when leave S_RES_DISCHARGE

// Ton Toff
reg [31:0] Ton_timer;
reg [31:0] Toff_timer;

// induction charging time
wire [15:0] inductor_charging_time_0;
wire [15:0] inductor_charging_time_0_openloop;
reg [15:0] inductor_charging_time_180;
reg [15:0] inductor_charging_time_180_openloop;

/******************* state shift *******************/
localparam S_WAIT_BREAKDOWN = 		8'b00000001;
localparam S_DEION = 				8'b10000000;
localparam S_DEION_SINGLE_BUCK = 	8'b00000000;

// BUCK discharge
localparam S_BUCK_INTERLEAVE = 		8'b00000010;
// resister discharge
localparam S_RES_DISCHARGE = 		8'b00000100;

`ifdef DEBUG_MODE
	(* preserve *) reg [7:0] current_state;
	(* preserve *) reg [7:0] next_state;
`else
    reg [7:0] current_state;
	reg [7:0] next_state;
`endif

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
			if (
				waveform == WAVE_RES_CO_DISCHARGE
				|| waveform == WAVE_BUCK_CC_RECTANGLE_DISCHARGE
				|| waveform == WAVE_BUCK_CC_TRIANGLE_DISCHARGE
				|| waveform == WAVE_BUCK_SC_RECTANGLE_DISCHARGE
				|| waveform == WAVE_BUCK_SO_RECTANGLE_DISCHARGE
				)
			begin
				if(waveform[CONTINUE_OR_SINGLE_BIT] == 1'b1 
					&& timer_deion >= Toff_timer && is_operation == 1'b1)
					next_state <= S_DEION_SINGLE_BUCK;
				else if(timer_deion >= Toff_timer && is_operation == 1'b1)
					next_state <= S_WAIT_BREAKDOWN;
				else
					next_state <= S_DEION;
			end
			else 
				next_state <= S_DEION;
		end

		S_DEION_SINGLE_BUCK:
		begin	
			if(is_operation == 1'b1 && timer_after_start_single >= DEAD_TIME)
				next_state <= S_WAIT_BREAKDOWN;
			else 
				next_state <= S_DEION_SINGLE_BUCK;
		end

		S_WAIT_BREAKDOWN:
		begin
			if(
				(timer_wait_breakdown <= WAIT_BREAKDOWN_MAXTIME)
				&& (timer_after_breakdown >= BUCK_INTERLEAVE_DELAY_TIME)
				&& (is_breakdown == 1'b1)
				&& (is_operation == 1'b1)
				&& (waveform == WAVE_BUCK_CC_RECTANGLE_DISCHARGE // continue closeloop buck rectangle discharge
					|| waveform == WAVE_BUCK_CC_TRIANGLE_DISCHARGE // continue closeloop buck triangle discharge
					|| waveform == WAVE_BUCK_SC_RECTANGLE_DISCHARGE // single closeloop buck rectangle discharge
					|| waveform == WAVE_BUCK_SO_RECTANGLE_DISCHARGE) // single openloop buck rectangle discharge
				)
				next_state <= S_BUCK_INTERLEAVE;

			else if(
				(timer_wait_breakdown <= WAIT_BREAKDOWN_MAXTIME)
				&& (is_breakdown == 1'b1)
				&& (is_operation == 1'b1)
				&& (waveform == WAVE_RES_CO_DISCHARGE) // resister discharge
				)
				next_state <= S_RES_DISCHARGE;
			
			else if(
				(is_breakdown == 1'b0)
				&& (timer_wait_breakdown > WAIT_BREAKDOWN_MAXTIME)
				|| (is_operation == 1'b0)
				)
				next_state <= S_DEION;
			
			else
				next_state <= S_WAIT_BREAKDOWN;
		end	

		S_BUCK_INTERLEAVE:
		begin
			if(timer_buck_interleave >= Ton_timer && waveform[CONTINUE_OR_SINGLE_BIT] == 1'b1) 
				next_state <= S_DEION_SINGLE_BUCK;
			else if(timer_buck_interleave >= Ton_timer) 
				next_state <= S_DEION; 
			else 
				next_state <= S_BUCK_INTERLEAVE;
		end

		// resister discharge
		S_RES_DISCHARGE:
		begin
			if(timer_res_discharge >= Ton_timer || is_operation == 1'b0) 
				next_state <= S_DEION;
			else
				next_state <= S_RES_DISCHARGE;
		end

		default:
			next_state <= S_DEION;
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
					if(mosfet_buck1 == 2'b10) // only can be 2'b10 or 2'b01
						mosfet_buck1 <= 2'b00;
					if(mosfet_buck2 <= 2'b10)
						mosfet_buck2 <= 2'b00;
					
					mosfet_res1 <= 2'b01;
					mosfet_res2 <= 2'b01;
				end
				else if(timer_deion >= Toff_timer - DEAD_TIME) // before into S_WAIT_BREAKDOWN, turn off all mosfet to ensure dead time
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

			S_DEION_SINGLE_BUCK:
			begin
				// deal with dead time
				if(timer_deion_single_buck < DEAD_TIME)
				begin
					if(mosfet_buck1 == 2'b10) // only can be 2'b10 or 2'b01
						mosfet_buck1 <= 2'b00;
					if(mosfet_buck2 <= 2'b10)
						mosfet_buck2 <= 2'b00;
					
					mosfet_res1 <= 2'b01;
					mosfet_res2 <= 2'b01;
				end
				else if(timer_deion_single_buck >= Toff_timer && timer_after_start_single <= DEAD_TIME && timer_after_start_single != 16'b0)
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
			
			/******************* buck wave *******************/
			S_BUCK_INTERLEAVE:
			begin
				if ( waveform[OPEN_OR_CLOSE_BIT] == 1'b1 ) // closedloop
				begin
					// buck1, wait DEAD_TIME before turn on mosfet
					if(timer_buck_4us_0 >= 16'd0 && timer_buck_4us_0 < DEAD_TIME)
						mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qdown turn off
					else if(timer_buck_4us_0 >= DEAD_TIME && timer_buck_4us_0 < inductor_charging_time_0 + DEAD_TIME) /* !first entry! */
					begin
						mosfet_buck1 <= 2'b10; // charge inductor
					end
					else if(timer_buck_4us_0 >= inductor_charging_time_0 + DEAD_TIME && timer_buck_4us_0 < inductor_charging_time_0 + DEAD_TIME + DEAD_TIME)
						mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qup turn off
					else if(timer_buck_4us_0 >= inductor_charging_time_0 + DEAD_TIME + DEAD_TIME)
						mosfet_buck1 <= 2'b01; // discharge inductor
												
					// buck2, wait DEAD_TIME before turn on mosfet
					if(timer_buck_4us_180 >= 16'd0 && timer_buck_4us_180 < DEAD_TIME)
						mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qdown turn off
					else if(timer_buck_4us_180 >= DEAD_TIME && timer_buck_4us_180 < inductor_charging_time_180 + DEAD_TIME)
						mosfet_buck2 <= 2'b10; // charge inductor
					else if(timer_buck_4us_180 >= inductor_charging_time_180 + DEAD_TIME && timer_buck_4us_180 < inductor_charging_time_180 + DEAD_TIME + DEAD_TIME)
						mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qup turn off
					else if(timer_buck_4us_180 >= inductor_charging_time_180 + DEAD_TIME + DEAD_TIME
							&& timer_cycle_num >= 1) /* !first entry! */
						mosfet_buck2 <= 2'b01; // discharge inductor
				end
				else if ( waveform[OPEN_OR_CLOSE_BIT] == 1'b0 ) // openloop
				begin
					// buck1, wait DEAD_TIME before turn on mosfet
					if(timer_buck_4us_0 >= 16'd0 && timer_buck_4us_0 < DEAD_TIME)
						mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qdown turn off
					else if(timer_buck_4us_0 >= DEAD_TIME && timer_buck_4us_0 < inductor_charging_time_0_openloop + DEAD_TIME) /* !first entry! */
					begin
						mosfet_buck1 <= 2'b10; // charge inductor
					end
					else if(timer_buck_4us_0 >= inductor_charging_time_0_openloop + DEAD_TIME && timer_buck_4us_0 < inductor_charging_time_0_openloop + DEAD_TIME + DEAD_TIME)
						mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qup turn off
					else if(timer_buck_4us_0 >= inductor_charging_time_0_openloop + DEAD_TIME + DEAD_TIME)
						mosfet_buck1 <= 2'b01; // discharge inductor
												
					// buck2, wait DEAD_TIME before turn on mosfet
					if(timer_buck_4us_180 >= 16'd0 && timer_buck_4us_180 < DEAD_TIME)
						mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qdown turn off
					else if(timer_buck_4us_180 >= DEAD_TIME && timer_buck_4us_180 < inductor_charging_time_180_openloop + DEAD_TIME)
						mosfet_buck2 <= 2'b10; // charge inductor
					else if(timer_buck_4us_180 >= inductor_charging_time_180_openloop + DEAD_TIME && timer_buck_4us_180 < inductor_charging_time_180_openloop + DEAD_TIME + DEAD_TIME)
						mosfet_buck2 <= 2'b00; // wait DEAD_TIME for Qup turn off
					else if(timer_buck_4us_180 >= inductor_charging_time_180_openloop + DEAD_TIME + DEAD_TIME
							&& timer_cycle_num >= 1) /* !first entry! */
						mosfet_buck2 <= 2'b01; // discharge inductor
				end
			end

			/******************* res discharge *******************/
			S_RES_DISCHARGE:
			begin
				if(timer_res_discharge <= Ton_timer)
					mosfet_res1 <= 2'b10;
				else
					mosfet_res1 <= 2'b01;
			end
		
		endcase
	end
end

// signle discharge signal
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		will_single_discharge <= 1'b0;
	else if(
		((current_state == S_BUCK_INTERLEAVE && next_state == S_DEION_SINGLE_BUCK) 
		&& waveform[CONTINUE_OR_SINGLE_BIT] == 1'b1)
		|| is_machine == 1'b0
		)
		will_single_discharge <= 1'b0;
	else if(
		is_machine == 1'b1
		&& signle_discharge_button_pressed == 1'b1
		&& waveform[CONTINUE_OR_SINGLE_BIT] == 1'b1 )
		will_single_discharge <= 1'b1;
end

// timer
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		Ton_timer <= 32'd0;
		Toff_timer <= 32'd0;
	end
	else
	begin
		Ton_timer <= Ton * 100;
		Toff_timer <= Toff * 100;
	end
end

// timer_deion
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_deion <= 32'd0;
	else if(current_state == S_DEION && timer_deion < Toff_timer)
		timer_deion <= timer_deion + 1'b1; // per 10ns +1
	else if(timer_deion >= Toff_timer)
		timer_deion <= 32'd0;
	else
		timer_deion <= 32'd0;
end

// timer_deion_single_buck
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_deion_single_buck <= 64'd0;
	else if(current_state == S_DEION_SINGLE_BUCK && will_single_discharge == 1'b0)
		timer_deion_single_buck <= timer_deion_single_buck + 1'b1; // per 10ns +1
	else
		timer_deion_single_buck <= 64'd0;
end
// timer_after_start_single
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_after_start_single <= 16'd0;
	else if(current_state == S_DEION_SINGLE_BUCK && will_single_discharge == 1'b1)
		timer_after_start_single <= timer_after_start_single + 1'b1; // per 10ns +1
	else
		timer_after_start_single <= 16'd0;
end

// timer_after_breakdown
reg timer_after_breakdown_reset;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_after_breakdown_reset <= 1'b0;
	else if(current_state == S_WAIT_BREAKDOWN && next_state == S_BUCK_INTERLEAVE)
		timer_after_breakdown_reset <= 1'b1;
	else
		timer_after_breakdown_reset <= 1'b0;
end

// timer_wait_breakdown
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_wait_breakdown <= 32'd0;
	else if(current_state == S_WAIT_BREAKDOWN)
		timer_wait_breakdown <= timer_wait_breakdown + 1'b1; // per 10ns +1
	else
		timer_wait_breakdown <= 32'd0;
end
// timer_buck_4us_0
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_4us_0 <= 16'd0;
	else if(current_state == S_BUCK_INTERLEAVE)
	begin
		if (timer_buck_4us_0 == 16'd399) // reset timer_buck_4us_0 per 4us
			timer_buck_4us_0 <= 16'd0;
		else
			timer_buck_4us_0 <= timer_buck_4us_0 + 1'd1; // per 10ns +1
	end
	else
		timer_buck_4us_0 <= 16'd0;
end
// reg [15:0] timer_cycle_num
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_cycle_num <= 16'd0;
    else if (current_state == S_DEION || current_state == S_DEION_SINGLE_BUCK)
        timer_cycle_num <= 16'd0;
	else if (timer_buck_4us_0 == 16'd399)
		timer_cycle_num <= timer_cycle_num + 16'd1;
end
// timer_buck_4us_180
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_4us_180 <= 400; // set initial value exceed inductor_charging_time_0 + DEAD_TIME*2, make sure timer_buck_4us_180 is invalid before timer_buck_4us_0 reset it at 2us
	else if(current_state == S_BUCK_INTERLEAVE)
	begin
		if(timer_buck_4us_0 == 16'd199) // timer_buck_4us_0 at 2us reset timer_buck_4us_180
			timer_buck_4us_180 <= 16'd0;
		else if(timer_buck_4us_180 <= 399)
			timer_buck_4us_180 <= timer_buck_4us_180 + 1'd1; // per 10ns +1
	end
	else
		timer_buck_4us_180 <= 400;
end
/******************* buck wave timer *******************/
// timer_buck_interleave
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_interleave <= 32'd0;
	else if(current_state == S_BUCK_INTERLEAVE)
		timer_buck_interleave <= timer_buck_interleave + 1'b1; // per 10ns +1
	else
		timer_buck_interleave <= 32'd0;
end
/******************* res discharge timer *******************/
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_res_discharge <= 32'd0;
	else if(current_state == S_RES_DISCHARGE)
		timer_res_discharge <= timer_res_discharge + 1'b1; // per 10ns +1
	else
		timer_res_discharge <= 32'd0;
end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
wire [15:0] i_set;
// one_cycle_control
reg [15:0] shift_reg_1[199:0];
reg [15:0] shift_reg_2[199:0];
integer i;

always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
	begin
        for (i = 0; i < 200; i = i + 1)
            shift_reg_1[i] <= 16'd0;
        inductor_charging_time_180 <= 16'd0;
    end 
	else 
	begin
        shift_reg_1[0] <= inductor_charging_time_0;
        for (i = 1; i < 200; i = i + 1)
            shift_reg_1[i] <= shift_reg_1[i - 1];
        inductor_charging_time_180 <= shift_reg_1[199];
    end
end

always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
	begin
        for (i = 0; i < 200; i = i + 1)
            shift_reg_2[i] <= 16'd0;
        inductor_charging_time_180_openloop <= 16'd0;
    end 
	else 
	begin
        shift_reg_2[0] <= inductor_charging_time_0_openloop;
        for (i = 1; i < 200; i = i + 1)
            shift_reg_2[i] <= shift_reg_2[i - 1];
        inductor_charging_time_180_openloop <= shift_reg_2[199];
    end
end

one_cycle_control
#(
	.Vin( INPUT_VOL ), // input voltage 120V
	.L( INDUCTANCE ), // inductance(uH) 3.3uH = 3300nH
	.fs( 16'd250 ), // frequency 250kHz (Ts = 4us)
	.V_GAP_FIXED( V_GAP_FIXED ) // discharge gap voltage
) one_cycle_control_inst
(
	.clk( clk ),
	.rst_n( rst_n ),

	.sample_current( sample_current ),
	.sample_voltage( sample_voltage ),

	.timer_buck_4us_0( timer_buck_4us_0 ),

	.i_set( i_set ), // iref=i_set/2

	.inductor_charging_time( inductor_charging_time_0 )
);

// I_set generation
i_set_generation iset_generation_inst
(
	.clk( clk ),
	.rst_n( rst_n ),

	.waveform( waveform ),
	.Ton_timer( Ton_timer ),
	.Ip( Ip ),
	.timer_buck_interleave( timer_buck_interleave ),

	.i_set( i_set )
);

// breakdown_detect
breakdown_detect
#(
	.DEION_THRESHOLD_VOL( DEION_THRESHOLD_VOL ),
	.BREAKDOWN_THRESHOLD_CUR( BREAKDOWN_THRESHOLD_CUR ),
	.BREAKDOWN_THRESHOLD_VOL( BREAKDOWN_THRESHOLD_VOL ),
    .BREAKDOWN_THRESHOLD_TIME( BREAKDOWN_THRESHOLD_TIME )
) breakdown_detect_inst
(
	.clk( clk ), // 100MHz 10ns
	.rst_n( rst_n ),
	
	// adc
	.sample_current( sample_current ), // (A)
	.sample_voltage( sample_voltage ), // (V)

    // state
    .current_state( current_state ), // S_WAIT_BREAKDOWN = 8'b00000001
	.timer_wait_breakdown( timer_wait_breakdown ),
	.waveform( waveform ),

    .is_breakdown( is_breakdown )
);

openloop_control
#(
	.CURRENT_STAND_CHARGING_TIMES( CURRENT_STAND_CHARGING_TIMES ),
    .CURRENT_RISE_CHARGING_TIMES( CURRENT_RISE_CHARGING_TIMES ),
    .CURRENT_RISE_CYCLE_TIMES( CURRENT_RISE_CYCLE_TIMES )
) openloop_control_inst
(
	.clk(clk),
	.rst_n(rst_n),

    .timer_cycle_num(timer_cycle_num),
	.inductor_charging_time_0_openloop(inductor_charging_time_0_openloop)
);

pulse_start_timer
#(
    .WIDTH( 16 ),
    .INIT_VALUE( 0 )
)
pulse_start_timer_inst
(
    .clk( clk ),
    .rst_n( rst_n ),
    .timer_reset( timer_after_breakdown_reset ),
    .timer_stand( 1'b0 ),
    .timer_start( is_breakdown ),
	.timer_restart( 1'b0 ),
    .output_timer( timer_after_breakdown )
);
endmodule
