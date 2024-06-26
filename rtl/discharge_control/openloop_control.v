/*
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
*/

module openloop_control
#(
	parameter CURRENT_STAND_CHARGING_TIMES = 16'd80, // one cycle current stand
    parameter CURRENT_RISE_CHARGING_TIMES = 16'd120, // one cycle current rise 5A
    parameter CURRENT_RISE_CYCLE_TIMES = 16'd3 // current rise 5A
)
(
	input clk,
	input rst_n,

    input wire [15:0] timer_cycle_num,
		
	output reg [15:0] inductor_charging_time_0_openloop
);
localparam S_WAIT_BREAKDOWN = 		8'b00000001;
localparam S_DEION = 				8'b10000000;
localparam S_DEION_SINGLE_BUCK = 	8'b00000000;
// BUCK discharge
localparam S_BUCK_INTERLEAVE = 		8'b00000010;
// resister discharge
localparam S_RES_DISCHARGE = 		8'b00000100;

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