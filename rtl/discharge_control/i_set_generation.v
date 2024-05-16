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
    input [15:0] Ton, // discharge time (us)
    input [15:0] Ip, // specified current
    input [15:0] timer_buck_interleave;

    output reg [15:0] i_set
);
localparam IDLE = 	8'b00000000;
localparam RECTANGLE_WAVE = 8'b10000001;
localparam TRIANGLE_WAVE = 8'b00000010;

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
			if(waveform[15] != 1'b1)
            begin
                if(waveform == 16'h0002)
                    next_state <= RECTANGLE_WAVE;
                else if(waveform == 16'h0004)
                    next_state <= TRIANGLE_WAVE;
                else
                    next_state <= IDLE;
            end
		end

		RECTANGLE_WAVE:
		begin
            if(timer_buck_interleave >= Ton)
                next_state <= IDLE;
        end

        TRIANGLE_WAVE:
		begin
            if (timer_buck_interleave >= Ton)
                next_state <= IDLE;
        end

    endcase
end

reg [15:0] current_ip;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        current_ip <= 16'd0;
    end
    else
    begin
        if(current_state == TRIANGLE_WAVE && timer_buck_interleave < Ton)
        begin
            if (timer_buck_interleave < Ton / 2)
                current_ip <= (Ip * timer_buck_interleave) / (Ton / 2);
            else
                current_ip <= Ip - (Ip * (timer_buck_interleave - Ton / 2)) / (Ton / 2);
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        i_set <= 16'd0;
    else if(current_state == RECTANGLE_WAVE)
        i_set <= Ip;
    else if(current_state == TRIANGLE_WAVE)
        i_set <= current_ip;
    else
        i_set <= 16'd0;
end

endmodule
