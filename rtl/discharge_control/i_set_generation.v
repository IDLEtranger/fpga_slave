module i_set_generation
(
    input clk,
    input rst_n,

    input [15:0] waveform, // specified waveform
    /*
        if waveform[15] == 1
		    resister discharge
        else
            waveform[1] == 1 : buck rectangle discharge
            waveform[2] == 1 : buck triangle discharge
	*/
    input [15:0] Ton_timer, // discharge time (us)
    input [15:0] Ip, // specified current
    input [15:0] timer_buck_interleave,

    output reg [15:0] i_set
);
localparam IDLE = 	8'b00000000;
localparam RECTANGLE_WAVE = 8'b00000001;
localparam TRIANGLE_WAVE = 8'b00000010;

localparam BUCK_RECTANGLE_WAVE = 16'b0000_0000_0000_0001;
localparam BUCK_TRIANGLE_WAVE = 16'b0000_0000_0000_0010;
localparam RESISTOR_DISCHARGE_WAVE = 16'b1000_0000_0000_0000;

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
			else if(waveform != RESISTOR_DISCHARGE_WAVE)
            begin
                if(waveform == BUCK_RECTANGLE_WAVE)
                    next_state <= RECTANGLE_WAVE;
                else if(waveform == BUCK_TRIANGLE_WAVE)
                    next_state <= TRIANGLE_WAVE;
                else
                    next_state <= IDLE;
            end
            else
                next_state <= IDLE;
		end

		RECTANGLE_WAVE:
		begin
            if(timer_buck_interleave >= Ton_timer)
                next_state <= IDLE;
        end

        TRIANGLE_WAVE:
		begin
            if (timer_buck_interleave >= Ton_timer)
                next_state <= IDLE;
        end

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
            i_set <= Ip;
        else if(current_state == RECTANGLE_WAVE)
            i_set <= Ip;
        else if(current_state == TRIANGLE_WAVE)
        begin
            if (timer_buck_interleave < Ton_timer / 2)
                i_set <= (Ip * timer_buck_interleave) / (Ton_timer / 2);
            else
                i_set <= Ip - (Ip * (timer_buck_interleave - Ton_timer / 2)) / (Ton_timer / 2);
        end
    end
end

endmodule
