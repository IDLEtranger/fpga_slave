module breakdown_detect
#(
    parameter IS_OPEN_CUR_DETECT = 1'b0,
    parameter DEION_THRESHOLD_VOL = 16'd8,
	parameter BREAKDOWN_THRESHOLD_CUR = 16'd10,
	parameter BREAKDOWN_THRESHOLD_VOL = 16'd35,
    parameter BREAKDOWN_THRESHOLD_TIME = 16'd10
)
(
	input clk, // 100MHz 10ns
	input rst_n,
	
	// adc
	input signed [15:0] sample_current, // (A)
	input signed [15:0] sample_voltage, // (V)

    // state
    input wire [7:0] current_state, // S_WAIT_BREAKDOWN = 8'b00000001

    output reg is_breakdown
);
reg [15:0] timer_cur_on_threshold;
reg [15:0] timer_vol_on_threshold;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		timer_cur_on_threshold <= 16'b0;
	else if (current_state == 8'b00000001) // S_WAIT_BREAKDOWN
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
	else if (current_state == 8'b00000001) // S_WAIT_BREAKDOWN
		begin
            if ( sample_voltage <= BREAKDOWN_THRESHOLD_VOL && sample_voltage >= DEION_THRESHOLD_VOL) // discriminate deion state and breakdown state
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
    else if (current_state == 8'b00000001) // S_WAIT_BREAKDOWN
    begin
        if(IS_OPEN_CUR_DETECT == 1'b0)
            begin
                if(timer_vol_on_threshold >= BREAKDOWN_THRESHOLD_TIME)
                    is_breakdown <= 1'b1;
                else
                    is_breakdown <= 1'b0;
            end
        else if(IS_OPEN_CUR_DETECT == 1'b1)
            begin
                if(timer_vol_on_threshold >= BREAKDOWN_THRESHOLD_TIME && timer_vol_on_threshold >= BREAKDOWN_THRESHOLD_TIME)
                    is_breakdown <= 1'b1;
                else
                    is_breakdown <= 1'b0;
            end
    end
    else
        is_breakdown <= 1'b0;
end

endmodule