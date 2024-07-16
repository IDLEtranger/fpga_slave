module discharge_control 
#(
	parameter DEAD_TIME = 16'd12, // Because of the extra diodes, the dead time can be long but not short.
	parameter WAIT_BREAKDOWN_MAXTIME = 16'd10000, // 100us, wait breakdown max timer count (10ns)
	parameter WAIT_BREAKDOWN_MINTIME = 16'd300, // 3us, wait breakdown min timer count (10ns)
	parameter MAX_CURRENT_LIMIT = 16'd78, // 78A, max current limit (A)

	parameter IS_OPEN_CUR_DETECT = 1'b0, // 0 means breakdown detection do not consider sample current
	parameter DEION_THRESHOLD_VOL = 16'd8, // below it means deion
	parameter signed BREAKDOWN_THRESHOLD_CUR = 16'd15, // current rise threshold(A), above it means breakdown &&
	parameter signed BREAKDOWN_THRESHOLD_VOL = 16'd30, // voltage fall threshold(A), below it means breakdown
	parameter signed BREAKDOWN_THRESHOLD_TIME = 16'd10,

	parameter INPUT_VOL = 16'd120, // input voltage 120V
	parameter INDUCTANCE = 16'd3300, // inductance(uH) 3.3uH = 3300nH
	parameter V_GAP_FIXED = 16'd20, // discharge gap voltage

	parameter CURRENT_STAND_CHARGING_TIMES = 16'd80, // current stand duty cycle
    parameter CURRENT_RISE_CHARGING_TIMES = 16'd120, // current rise duty cycle
    parameter CURRENT_RISE_CYCLE_TIMES = 16'd3, // current rise cycles
	parameter BUCK_INTERLEAVE_DELAY_TIME = 16'd10
)
(
	input clk, // 100MHz 10ns
	input rst_n,

	// parameter in
    input wire machine_start_ack_spi,
    input wire machine_stop_ack_spi,
	input wire machine_start_ack_key,
    input wire machine_stop_ack_key,

    input wire change_Ton_ack,
    input wire [15:0] Ton_data_async,
    
    input wire change_Toff_ack,
    input wire [15:0] Toff_data_async,

    input wire change_Ip_ack,
    input wire [15:0] Ip_data_async,
    
    input wire change_waveform_ack,
    input wire [15:0] waveform_data_async,

	// sampling data
	input signed [15:0] sample_current,
	input signed [15:0] sample_voltage,

	// signle_discharge_button
	input wire signle_discharge_button_pressed,
	
	// output mosfet control signal
	output wire [1:0] mosfet_buck1, // Buck1:上管 下管
	output wire [1:0] mosfet_buck2, // Buck2:上管 下管
	output wire [1:0] mosfet_res1, // Res1:上管 下管
	output wire [1:0] mosfet_res2, // Res2:上管 下管
	output wire mosfet_deion, // Qoff 消电离回路

	// opeartion indicator
	output wire is_operation,
	output wire will_single_discharge,
	output is_breakdown,
	output is_machine
);

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
// input signal
`ifdef DEBUG_MODE
	(* preserve *) reg is_machine_key;
    (* preserve *) wire is_machine_spi;
	(* preserve *) wire [15:0] Ton_data;
	(* preserve *) wire [15:0] Toff_data;
	(* preserve *) wire [15:0] Ip_data;
	(* preserve *) wire [15:0] waveform_data;
`else
	reg is_machine_key;
    wire is_machine_spi;
	wire [15:0] Ton_data;
	wire [15:0] Toff_data;
	wire [15:0] Ip_data;
	wire [15:0] waveform_data;
`endif

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		is_machine_key <= 1'b1;
	else if(machine_start_ack_key == 1'b1)
		is_machine_key <= 1'b1;
	else if(machine_stop_ack_key == 1'b1)
		is_machine_key <= 1'b0;
end

assign is_machine = (is_machine_spi && is_machine_key);

mos_control
#(
	.DEAD_TIME( DEAD_TIME ), // Because of the extra diodes, the dead time can be long but not short.
	.WAIT_BREAKDOWN_MAXTIME( WAIT_BREAKDOWN_MAXTIME ), // 100us, wait breakdown max timer count (10ns)
	.WAIT_BREAKDOWN_MINTIME( WAIT_BREAKDOWN_MINTIME ), // 3us, wait breakdown min timer count (10ns)
	.MAX_CURRENT_LIMIT( MAX_CURRENT_LIMIT ), // 78A, max current limit (A)

	.IS_OPEN_CUR_DETECT( IS_OPEN_CUR_DETECT ), // 0 means breakdown detection do not consider sample current
	.DEION_THRESHOLD_VOL( DEION_THRESHOLD_VOL ), // below it means deion
	.BREAKDOWN_THRESHOLD_CUR( BREAKDOWN_THRESHOLD_CUR ), // current rise threshold(A), above it means breakdown &&
	.BREAKDOWN_THRESHOLD_VOL( BREAKDOWN_THRESHOLD_VOL ), // voltage fall threshold(A), below it means breakdown
	.BREAKDOWN_THRESHOLD_TIME( BREAKDOWN_THRESHOLD_TIME ),

	.INPUT_VOL( INPUT_VOL ), // input voltage 120V
	.INDUCTANCE ( INDUCTANCE ), // inductance(uH) 3.3uH = 3300nH
	.V_GAP_FIXED( V_GAP_FIXED ), // discharge gap voltage
	
	.CURRENT_STAND_CHARGING_TIMES( CURRENT_STAND_CHARGING_TIMES ), // current stand duty cycle
    .CURRENT_RISE_CHARGING_TIMES( CURRENT_RISE_CHARGING_TIMES ), // current rise duty cycle
    .CURRENT_RISE_CYCLE_TIMES( CURRENT_RISE_CYCLE_TIMES ), // current rise cycles
	.BUCK_INTERLEAVE_DELAY_TIME( BUCK_INTERLEAVE_DELAY_TIME )
)  mos_control_instance
(
	.clk(clk), // 100MHz 10ns
	.rst_n(rst_n),

	// pulse generate parameter
	.is_machine(is_machine), // 1'b1: machine start, 1'b0: machine stop
	
	.waveform(waveform_data),
	/*
		16'b1000 0000 0000 0000 : resister discharge
		16'b0000 0000 0000 0001 : buck rectangle discharge
		16'b0000 0000 0000 0010 : buck triangle discharge
	*/
	.Ip(Ip_data), // specified current
	.Ton(Ton_data), // discharge time (us)
	.Toff(Toff_data), // Ts = Twaitbreakdown + Ton + Tofff (a discharge cycle) (us)

	// sampling data
	.sample_current(sample_current),
	.sample_voltage(sample_voltage),

	// single discharge key press
	.signle_discharge_button_pressed(signle_discharge_button_pressed),

	// output mosfet control signal
	.mosfet_buck1(mosfet_buck1),
	.mosfet_buck2(mosfet_buck2),
	.mosfet_res1(mosfet_res1),
	.mosfet_res2(mosfet_res2),
	.mosfet_deion(mosfet_deion),

	// opeartion indicator
	.is_operation(is_operation),
	.will_single_discharge(will_single_discharge),
	.is_breakdown(is_breakdown)
);

parameter_generator param_gen_inst
(
	.clk(clk),
	.rst_n(rst_n),

	.machine_start_ack_spi(machine_start_ack_spi),
	.machine_stop_ack_spi(machine_stop_ack_spi),
	.is_machine_spi(is_machine_spi),

	.change_Ton_ack(change_Ton_ack),
	.Ton_data_async(Ton_data_async),
	.Ton_data(Ton_data),

	.change_Toff_ack(change_Toff_ack),
	.Toff_data_async(Toff_data_async),
	.Toff_data(Toff_data),

	.change_Ip_ack(change_Ip_ack),
	.Ip_data_async(Ip_data_async),
	.Ip_data(Ip_data),

	.change_waveform_ack(change_waveform_ack),
	.waveform_data_async(waveform_data_async),
	.waveform_data(waveform_data)
);

endmodule
