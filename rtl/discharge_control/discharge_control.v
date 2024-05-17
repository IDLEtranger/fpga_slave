module discharge_control 
(
	input clk, // 100MHz 10ns
	input rst_n,

	// parameter in
    input wire machine_start_ack,
    input wire machine_stop_ack,

    input wire change_Ton_ack,
    input wire [15:0] Ton_data_async,
    
    input wire change_Toff_ack,
    input wire [15:0] Toff_data_async,

    input wire change_Ip_ack,
    input wire [15:0] Ip_data_async,
    
    input wire change_waveform_ack,
    input wire [15:0] waveform_data_async,

	// sampling data
	input signed [16:0] sample_current,
	input signed [16:0] sample_voltage,
	
	// output mosfet control signal
	output wire [1:0] mosfet_buck1, // Buck1:上管 下管
	output wire [1:0] mosfet_buck2, // Buck2:上管 下管
	output wire [1:0] mosfet_res1, // Res1:上管 下管
	output wire [1:0] mosfet_res2, // Res2:上管 下管
	output wire mosfet_deion // Qoff 消电离回路
);

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
// input signal
wire is_machine;
wire [15:0] Ton_data;
wire [15:0] Toff_data;
wire [15:0] Ip_data;
wire [15:0] waveform_data;

mos_control
#(
	.DEAD_TIME( 16'd10 ), // Because of the extra diodes, the dead time can be long but not short.
	.WAIT_BREAKDOWN_MAXTIME( 16'd8000 ), // 80us, wait breakdown max timer count (10ns)
	.WAIT_BREAKDOWN_MINTIME( 16'd300 ), // 3us, wait breakdown min timer count (10ns)
	.MAX_CURRENT_LIMIT( 16'd80 ), // 80A, max current limit (A)
	.BREAKDOWN_THRESHOLD_CUR( 16'd15 ), // 15A, current rise threshold(A), above it means breakdown &&
	.BREAKDOWN_THRESHOLD_VOL( 12'd30 ) // 30V, voltage fall threshold(A), below it means breakdown
)  mos_control_instance
(
	.clk(clk), // 100MHz 10ns
	.rst_n(rst_n),

	// pulse generate parameter
	.is_machine(is_machine), // 1'b1: machine start, 1'b0: machine stop
	
	.waveform(waveform),
	/*
		16'b1000 0000 0000 0000 : resister discharge
		16'b0000 0000 0000 0001 : buck rectangle discharge
		16'b0000 0000 0000 0010 : buck triangle discharge
	*/
	.Ip(Ip), // specified current
	.Ton(Ton), // discharge time (us)
	.Toff(Toff), // Ts = Twaitbreakdown + Ton + Tofff (a discharge cycle) (us)

	// sampling data
	.sample_current(sample_current),
	.sample_voltage(sample_voltage),

	// output mosfet control signal
	.mosfet_buck1(mosfet_buck1),
	.mosfet_buck2(mosfet_buck2),
	.mosfet_res1(mosfet_res1),
	.mosfet_res2(mosfet_res2),
	.mosfet_deion(mosfet_deion)
);

parameter_generator param_gen_inst
(
	.clk(clk),
	.rst_n(rst_n),

	.machine_start_ack(machine_start_ack),
	.machine_stop_ack(machine_stop_ack),
	.is_machine(is_machine),

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



