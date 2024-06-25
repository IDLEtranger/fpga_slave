module i_set_generation
(
    input clk,
    input rst_n,

    input [15:0] waveform, // specified waveform
    /*
        if waveform[15] == 1
		    resister discharge
        else
            waveform[0] == 1 : buck rectangle discharge
            waveform[1] == 1 : buck triangle discharge
	*/
    input [31:0] Ton_timer, // discharge time (us)
    input [15:0] Ip, // specified current
    input [31:0] timer_buck_interleave,

    output reg [15:0] i_set
);
localparam IDLE = 8'b00000000;
localparam RECTANGLE_WAVE_STATE = 8'b00000001;
localparam TRIANGLE_WAVE_STATE = 8'b00000010;

localparam WAVE_BUCK_CC_RECTANGLE_DISCHARGE = 16'b0010_0000_0000_0001; // 0x2001
localparam WAVE_BUCK_CC_TRIANGLE_DISCHARGE = 16'b0010_0000_0000_0010; // 0x2002
localparam WAVE_BUCK_SC_RECTANGLE_DISCHARGE = 16'b0110_0000_0000_0001; // 0x6001

reg [7:0] current_state;
reg [7:0] next_state;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0) 
		current_state <= IDLE;
	else 
		current_state <= next_state;
end

always@(*)
begin
	case(current_state)
		IDLE:
		begin
            if(timer_buck_interleave == 0)
                next_state <= IDLE;
            else if(
                waveform == WAVE_BUCK_SC_RECTANGLE_DISCHARGE
                && waveform == WAVE_BUCK_CC_RECTANGLE_DISCHARGE
                )
                next_state <= RECTANGLE_WAVE_STATE;
            else if(
                waveform == WAVE_BUCK_CC_TRIANGLE_DISCHARGE
                )
                next_state <= TRIANGLE_WAVE_STATE;
            else
                next_state <= IDLE;
		end

		RECTANGLE_WAVE_STATE:
		begin
            if(timer_buck_interleave >= Ton_timer)
                next_state <= IDLE;
            else
                next_state <= RECTANGLE_WAVE_STATE;
        end

        TRIANGLE_WAVE_STATE:
		begin
            if (timer_buck_interleave >= Ton_timer)
                next_state <= IDLE;
            else
                next_state <= TRIANGLE_WAVE_STATE;   
        end

        default:
            next_state <= IDLE;

    endcase
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        i_set <= 16'd0;
    end
    else
    begin
        if(current_state == IDLE)
            i_set <= 16'd0;
        else if(current_state == RECTANGLE_WAVE_STATE)
            i_set <= Ip;
        else if(current_state == TRIANGLE_WAVE_STATE)
        begin
            if (timer_buck_interleave < (Ton_timer >> 1))
                i_set <= (Ip * timer_buck_interleave) / (Ton_timer >> 1);
            else
                i_set <= Ip - (Ip * (timer_buck_interleave - (Ton_timer >> 1) )) / (Ton_timer >> 1);
        end
    end
end

endmodule
