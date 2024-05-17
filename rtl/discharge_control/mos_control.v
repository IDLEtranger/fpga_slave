module mos_control
#(
	parameter DEAD_TIME = 16'd10, // Because of the extra diodes, the dead time can be long but not short.
	parameter WAIT_BREAKDOWN_MAXTIME = 16'd1000,
	parameter WAIT_BREAKDOWN_MINTIME = 16'd50,
	parameter MAX_CURRENT_LIMIT = 16'd38,
	parameter BREAKDOWN_THRESHOLD_CUR = 16'd10,
	parameter BREAKDOWN_THRESHOLD_VOL = 12'd30
)
(
	input clk, // 100MHz 10ns
	input rst_n,

	// pulse generate parameter
	input is_machine, // 1'b1: machine start, 1'b0: machine stop
	input [15:0] waveform,
	/*
		16'b1000 0000 0000 0000 : resister discharge
		16'b0000 0000 0000 0001 : buck rectangle discharge
		16'b0000 0000 0000 0010 : buck triangle discharge
	*/
	input [15:0] Ip, // specified current	
	input [15:0] Ton, // discharge time (us)
	input [15:0] Toff, // Ts = Twaitbreakdown + Ton + Tofff (a discharge cycle) (us)
	
	// adc
	input signed [16:0] sample_current,
	input signed [16:0] sample_voltage,
	
	// output mosfet control signal
	output reg [1:0] mosfet_buck1, // Buck1:上管 下管
	output reg [1:0] mosfet_buck2, // Buck2:上管 下管
	output reg [1:0] mosfet_res1, // Res1:上管 下管
	output reg [1:0] mosfet_res2, // Res2:上管 下管
	output reg mosfet_deion // Qoff 消电离回路
);

// current correction
reg signed [15:0] corrected_current;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		corrected_current <= 15'd0;
	else 
		corrected_current <= sample_current;
end

reg signed [15:0] total_current;
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
	else if((is_overcurrent) || (is_machine == 1'b0))
		is_operation <= 1'b0;
	else 
		is_operation <= 1'b1;
end

/************************** timer define **************************/
reg [15:0] timer_wait_breakdown; // in S_WAIT_BREAKDOWN every 10ns ++, reset when leave S_WAIT_BREAKDOWN
reg [15:0] timer_deion; // in S_DEION every 10ns ++, reset when leave S_DEION

// buck wave timer
reg [15:0] timer_buck_4us_0; // in S_BUCK_INTERLEAVE every 10ns ++, reset every 4us
reg [15:0] timer_buck_4us_180; // reset when timer_buck_4us_0 reaches 2us, ends in inductor_charging_time_0 + DEAD_TIME + DEAD_TIME

reg [15:0] timer_buck_interleave; // in S_BUCK_INTERLEAVE every 10ns ++, reset when leave S_BUCK_INTERLEAVE

// res discharge timer
reg [15:0] timer_res_discharge; // in S_RES_DISCHARGE every 10ns ++, reset when leave S_RES_DISCHARGE

// Ton Toff
reg [15:0] Ton_timer;
reg [15:0] Toff_timer;

// induction charging time
wire [15:0] inductor_charging_time_0;
reg [15:0] inductor_charging_time_180;

/******************* state shift *******************/
localparam S_WAIT_BREAKDOWN = 	8'b00000001;
localparam S_DEION = 			8'b10000000;
// BUCK discharge
localparam S_BUCK_INTERLEAVE = 	8'b00000010;
// resister discharge
localparam S_RES_DISCHARGE = 	8'b00000100;

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
			if(timer_deion >= Toff_timer && is_operation == 1'b1)
				next_state <= S_WAIT_BREAKDOWN;
			else 
				next_state <= S_DEION;
		end

		S_WAIT_BREAKDOWN:
		begin
			if((timer_wait_breakdown > WAIT_BREAKDOWN_MINTIME)
				&& (timer_wait_breakdown < WAIT_BREAKDOWN_MAXTIME)
				&& (corrected_current >= BREAKDOWN_THRESHOLD_CUR)
				&& (sample_voltage < BREAKDOWN_THRESHOLD_VOL)
				&& (is_operation == 1'b1)
				&& (waveform[15] == 1'b0))
				next_state <= S_BUCK_INTERLEAVE;

			else if((timer_wait_breakdown > WAIT_BREAKDOWN_MINTIME)
				&& (timer_wait_breakdown < WAIT_BREAKDOWN_MAXTIME)
				&& (corrected_current >= BREAKDOWN_THRESHOLD_CUR)
				&& (sample_voltage < BREAKDOWN_THRESHOLD_VOL)
				&& (is_operation == 1'b1)
				&& (waveform[15] == 1'b1))
				next_state <= S_RES_DISCHARGE;
			
			else if( timer_wait_breakdown >= WAIT_BREAKDOWN_MAXTIME || is_operation == 1'b0 ) 
				next_state <= S_DEION;
			else
				next_state <= S_WAIT_BREAKDOWN; 
		end	

		S_BUCK_INTERLEAVE:
		begin
			if(timer_buck_interleave >= Ton_timer) 
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
			
			/******************* buck wave *******************/
			S_BUCK_INTERLEAVE:
			begin
				// buck1, wait DEAD_TIME before turn on mosfet
				if(timer_buck_4us_0 >= 16'd0 && timer_buck_4us_0 < DEAD_TIME)
					mosfet_buck1 <= 2'b00; // wait DEAD_TIME for Qdown turn off
				else if(timer_buck_4us_0 >= DEAD_TIME && timer_buck_4us_0 < inductor_charging_time_0 + DEAD_TIME) /* !first entry! */
				begin
					mosfet_buck1 <= 2'b10; // charge inductor
					mosfet_res1 <= 2'b00;
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
				else if(timer_buck_4us_180 >= inductor_charging_time_180 + DEAD_TIME + DEAD_TIME) /* !first entry! */
					mosfet_buck2 <= 2'b01; // discharge inductor
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

// timer
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		Ton_timer <= 16'd0;
		Toff_timer <= 16'd0;
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
// timer_buck_4us_180
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_4us_180 <= inductor_charging_time_0 + DEAD_TIME + DEAD_TIME + 1; // set initial value exceed inductor_charging_time_0 + DEAD_TIME*2, make sure timer_buck_4us_180 is invalid before timer_buck_4us_0 reset it at 2us
	else if(current_state == S_BUCK_INTERLEAVE)
	begin
		if(timer_buck_4us_0 == 16'd199) // timer_buck_4us_0 at 2us reset timer_buck_4us_180
			timer_buck_4us_180 <= 16'd0;
		else if(timer_buck_4us_180 <= inductor_charging_time_0 + DEAD_TIME + DEAD_TIME)
			timer_buck_4us_180 <= timer_buck_4us_180 + 1'd1; // per 10ns +1
		else
			timer_buck_4us_180 <= timer_buck_4us_180;
	end
	else
		timer_buck_4us_180 <= inductor_charging_time_0 + DEAD_TIME + DEAD_TIME + 1;
end
/******************* buck wave timer *******************/
// timer_buck_interleave
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_buck_interleave <= 16'd0;
	else if(current_state == S_BUCK_INTERLEAVE)
		timer_buck_interleave <= timer_buck_interleave + 1'b1; // per 10ns +1
	else
		timer_buck_interleave <= 16'd0;
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

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
wire [15:0] i_set;
// one_cycle_control
reg [15:0] shift_reg[199:0];
integer i;
always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
	begin
        for (i = 0; i < 200; i = i + 1)
            shift_reg[i] <= 16'd0;
        inductor_charging_time_180 <= 16'd0;
    end 
	else 
	begin
        shift_reg[0] <= inductor_charging_time_0;
        for (i = 1; i < 200; i = i + 1)
            shift_reg[i] <= shift_reg[i - 1];
        inductor_charging_time_180 <= shift_reg[199];
    end
end

one_cycle_control
#(
	.Vin( 16'd120 ), // input voltage 120V
	.L( 16'd3300 ), // inductance(uH) 3.3uH = 3300nH
	.fs( 16'd250 ) // frequency 250kHz (Ts = 4us)
) one_cycle_control_inst
(
	.clk( clk ),
	.rst_n( rst_n ),
	
	.sample_current( corrected_current ),
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

endmodule
