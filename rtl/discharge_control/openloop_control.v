module openloop_control
#(
	parameter CURRENT_STAND_CHARGING_TIMES = 16'd80, // one cycle current stand
    parameter CURRENT_RISE_CHARGING_TIMES = 16'd120, // one cycle current rise 5A
    parameter CURRENT_RISE_CYCLE_TIMES = 16'd3 // current rise 5A
)
(
	input clk,
	input rst_n,

	input [15:0] timer_buck_4us_0,

    input wire [7:0] current_state, // S_WAIT_BREAKDOWN = 8'b00000001
		
	output reg [15:0] inductor_charging_time_0_openloop
);
localparam S_WAIT_BREAKDOWN = 		8'b00000001;
localparam S_DEION = 				8'b10000000;
localparam S_DEION_SINGLE_BUCK = 	8'b00000000;
// BUCK discharge
localparam S_BUCK_INTERLEAVE = 		8'b00000010;
// resister discharge
localparam S_RES_DISCHARGE = 		8'b00000100;

reg [15:0]timer_cycle_num;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		timer_cycle_num <= 16'd0;
    else if (current_state == S_DEION || current_state == S_DEION_SINGLE_BUCK)
        timer_cycle_num <= 16'd0;
	else if (timer_buck_4us_0 == 16'd399)
		timer_cycle_num <= timer_cycle_num + 16'd1;
end

always@(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0)
        inductor_charging_time_0_openloop <= 16'd0;
    else
    begin
        if (timer_cycle_num < CURRENT_RISE_CYCLE_TIMES)
            inductor_charging_time_0_openloop <= CURRENT_RISE_CHARGING_TIMES;
        else
            inductor_charging_time_0_openloop <= CURRENT_STAND_CHARGING_TIMES;
    end
end


endmodule