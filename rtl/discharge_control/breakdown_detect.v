module breakdown_detect
#(
    parameter IS_OPEN_CUR_DETECT = 1'b0,
    parameter DEION_THRESHOLD_VOL = 16'd8,
	parameter BREAKDOWN_THRESHOLD_CUR = 16'd10,
	parameter BREAKDOWN_THRESHOLD_VOL = 16'd35,
    parameter BREAKDOWN_THRESHOLD_TIME = 16'd10,
    parameter AFTER_KEY_PRESSED_DELAY = 32'd100000000
)
(
	input clk, // 100MHz 10ns
	input rst_n,
	
	// adc
	input signed [15:0] sample_current, // (A)
	input signed [15:0] sample_voltage, // (V)

    // state
    input wire [7:0] current_state, // S_WAIT_BREAKDOWN = 8'b00000001

    // key
    input wire signle_discharge_button_pressed,

    output reg is_breakdown
);
reg [15:0] timer_cur_on_threshold;
reg [15:0] timer_vol_on_threshold;

wire [31:0] timer_after_key_pressed;
reg timer_after_key_pressed_stand;
reg timer_after_key_pressed_reset;

localparam S_WAIT_BREAKDOWN = 		8'b00000001;
localparam S_DEION = 				8'b10000000;
localparam S_DEION_SINGLE_BUCK = 	8'b00000000;

// BUCK discharge
localparam S_BUCK_INTERLEAVE = 		8'b00000010;
// resister discharge
localparam S_RES_DISCHARGE = 		8'b00000100;

// reg timer_after_key_pressed_stand;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) 
		timer_after_key_pressed_stand <= 1'b0;
    else if ( timer_after_key_pressed == AFTER_KEY_PRESSED_DELAY + 32'd1 )
        timer_after_key_pressed_stand <= 1'b1;
end
// timer_after_key_pressed_reset;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) 
		timer_after_key_pressed_reset <= 1'b0;
    else if ( signle_discharge_button_pressed == 1'b1 )
        timer_after_key_pressed_reset <= 1'b1;
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		timer_cur_on_threshold <= 16'b0;
	else if (current_state == S_WAIT_BREAKDOWN)
		begin
            if ( sample_current >= BREAKDOWN_THRESHOLD_CUR )
                timer_cur_on_threshold <= timer_cur_on_threshold + 16'd1;
            else
                timer_cur_on_threshold <= 16'd0;
        end
    else 
        timer_cur_on_threshold <= 16'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		timer_vol_on_threshold <= 16'b0;
	else if ( current_state == S_WAIT_BREAKDOWN )
		begin
            if ( sample_voltage <= BREAKDOWN_THRESHOLD_VOL && sample_voltage >= DEION_THRESHOLD_VOL
                && timer_after_key_pressed >= AFTER_KEY_PRESSED_DELAY ) // discriminate deion state and breakdown state
                timer_vol_on_threshold <= timer_vol_on_threshold + 16'd1;
            else
                timer_vol_on_threshold <= 16'd0;
        end
    else
        timer_vol_on_threshold <= 16'd0;
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) 
        is_breakdown <= 1'b0;
    else if (current_state == S_WAIT_BREAKDOWN)
    begin
        if(IS_OPEN_CUR_DETECT == 1'b0)
            begin
                if(timer_vol_on_threshold == BREAKDOWN_THRESHOLD_TIME)
                    is_breakdown <= 1'b1;
            end
        else if(IS_OPEN_CUR_DETECT == 1'b1)
            begin
                if(timer_cur_on_threshold == BREAKDOWN_THRESHOLD_TIME && timer_vol_on_threshold == BREAKDOWN_THRESHOLD_TIME)
                    is_breakdown <= 1'b1;
            end
    end
    else if ( current_state == S_DEION || current_state == S_DEION_SINGLE_BUCK )
        is_breakdown <= 1'b0;
end

pulse_start_timer
#(
    .WIDTH( 32 ),
    .INIT_VALUE( 0 )
)
pulse_start_timer_inst
(
    .clk( clk ),
    .rst_n( rst_n ),
    .timer_reset( timer_after_key_pressed_reset ),
    .timer_stand( timer_after_key_pressed_stand ),
    .timer_start( signle_discharge_button_pressed ),
    .output_timer( timer_after_key_pressed )
);

endmodule