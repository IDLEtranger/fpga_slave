`define DEBUG_MODE
/* 
waveform
x000_0000_0000_0000; x=0: BUCK discharge, x=1: RES discharge
0x00_0000_0000_0000; x=0: continue discharge, x=1: single discharge
00x0_0000_0000_0000; x=0: openloop, x=1: closedloop

localparam WAVE_RES_CO_DISCHARGE = 16'b1000_0000_0000_0000; // 0x8000
localparam WAVE_BUCK_CC_RECTANGLE_DISCHARGE = 16'b0010_0000_0000_0001; // 0x2001
localparam WAVE_BUCK_CC_TRIANGLE_DISCHARGE = 16'b0010_0000_0000_0010; // 0x2002
localparam WAVE_BUCK_SC_RECTANGLE_DISCHARGE = 16'b0110_0000_0000_0001; // 0x6001
localparam WAVE_BUCK_SO_RECTANGLE_DISCHARGE = 16'b0100_0000_0000_0001; // 0x4001
*/
module fpga_slave
(
    /** CLOCK & RESET **/
    input wire clk_in,
	input wire sys_rst_n,
    
    /** KEY **/
    input wire key_start,
    input wire key_stop,
    input wire signle_discharge_button,

    /** ADC **/
    output wire ad1_clk,
    output wire ad2_clk,
    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in,

    /** SPI_SLAVE **/
    input wire mosi,
    input wire sclk,
    input wire cs_n,
    output wire miso,

    /** MOSFET CONTROL SIGNAL **/
    output wire [1:0] mosfet_buck1, // Buck1:upper lower
	output wire [1:0] mosfet_buck2, // Buck2:upper lower
	output wire [1:0] mosfet_res1, // Res1:upper lower
	output wire [1:0] mosfet_res2, // Res2:upper lower
	output wire mosfet_deion, // Qoff: deion

    /** OPERATION INDICATOR **/
    output wire operation_indicator,
    output wire will_single_discharge_indicator,
    output is_breakdown
);
/* clock */
`ifdef DEBUG_MODE
    (* preserve *) wire clk_50M;
    (* preserve *) wire clk_65M;
    (* preserve *) wire clk_100M;
    (* preserve *) wire clk_216M;
`else
    wire clk_50M;
    wire clk_65M;
    wire clk_100M;
    wire clk_216M;
`endif

assign ad1_clk = clk_65M;
assign ad2_clk = clk_65M;

/*********************************/
/************** KEY **************/
/*********************************/
wire machine_stop_ack_key;
wire machine_start_ack_key;
wire signle_discharge_button_pressed;

/*********************************/
/************** ADC **************/
/*********************************/
`ifdef DEBUG_MODE
    (* preserve *) wire [15:0] sample_current;
    (* preserve *) wire [15:0] sample_voltage;
`else
    wire [15:0] sample_current;
    wire [15:0] sample_voltage;
`endif

/*************************************/
/************* SPI_SLAVE *************/
/*************************************/
// pulse_generator discharge signal
wire [15:0] Ton_data_async;
wire [15:0] Toff_data_async;
wire [15:0] Ip_data_async;
wire [15:0] waveform_data_async;

wire machine_start_ack_spi;
wire machine_stop_ack_spi;
wire change_Ton_ack;
wire change_Toff_ack;
wire change_Ip_ack;
wire change_waveform_ack;

/*********************************************/
/************* DISCHARGE CONTROL *************/
/*********************************************/
wire is_operation;
assign operation_indicator = ~is_operation;
wire will_single_discharge;
assign will_single_discharge_indicator = ~will_single_discharge;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
pll	pll_inst 
(
	.inclk0 ( clk_in ),
	.c0 ( clk_50M ),
	.c1 ( clk_65M ),
	.c2 ( clk_100M ),
	.c3 ( clk_216M )
);

ad_sample ad_sample_inst
(
    .sys_clk(clk_100M),
    .ad_clk(clk_65M),
    .rst_n(sys_rst_n),

    .ad1_in(ad1_in),
    .ad2_in(ad2_in),

    .sample_current_fifo_out(sample_current), // synchronized to sys_clk
    .sample_voltage_fifo_out(sample_voltage)
);

spi_slave_cmd spi_slave_cmd_inst
(
    .clk(clk_216M),
    .rst_n(sys_rst_n),

    // spi interface
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .cs_n(cs_n),

    .machine_start_ack(machine_start_ack_spi),
    .machine_stop_ack(machine_stop_ack_spi),

    .Ton_data_async(Ton_data_async),
    .change_Ton_ack(change_Ton_ack),
    .Toff_data_async(Toff_data_async),
    .change_Toff_ack(change_Toff_ack),
    .Ip_data_async(Ip_data_async),
    .change_Ip_ack(change_Ip_ack),
    .waveform_data_async(waveform_data_async),
    .change_waveform_ack(change_waveform_ack),

    .change_feedback_ack(1'b1),
    .feedback_data_async(32'h0F0F0F0F)
);

discharge_control 
#(
	.DEAD_TIME( 16'd10 ), // Because of the extra diodes, the dead time can be long but not short.
	.WAIT_BREAKDOWN_MAXTIME( 16'd10000 ), // 100us, wait breakdown max timer count (10ns)
	.WAIT_BREAKDOWN_MINTIME( 16'd300 ), // 3us, wait breakdown min timer count (10ns)
	.MAX_CURRENT_LIMIT( 16'd120 ), // 78A, max current limit (A)

	.IS_OPEN_CUR_DETECT( 1'b0 ), // 0 means breakdown detection do not consider sample current
    .DEION_THRESHOLD_VOL( 16'd5 ),
	.BREAKDOWN_THRESHOLD_CUR( 16'd15 ), // current rise threshold(A), above it means breakdown &&
	.BREAKDOWN_THRESHOLD_VOL( 16'd30 ), // voltage fall threshold(A), below it means breakdown
	.BREAKDOWN_THRESHOLD_TIME( 16'd30 ),

	.INPUT_VOL( 16'd100 ), // input voltage 120V
	.INDUCTANCE ( 16'd3300 ), // inductance(uH) 3.3uH = 3300nH
    .V_GAP_FIXED( 16'd20 ), // discharge gap voltage

    .CURRENT_STAND_CHARGING_TIMES( 16'd100 ),
    .CURRENT_RISE_CHARGING_TIMES( 16'd130 ),
    .CURRENT_RISE_CYCLE_TIMES( 16'd3 ),
    .BUCK_INTERLEAVE_DELAY_TIME( 16'd3 )
) discharge_ctrl_inst
(
    .clk(clk_100M),
    .rst_n(sys_rst_n),

    // parameter in
    .machine_start_ack_spi(machine_start_ack_spi),
    .machine_stop_ack_spi(machine_stop_ack_spi),
    .machine_start_ack_key(machine_start_ack_key),
    .machine_stop_ack_key(machine_stop_ack_key),

    .change_Ton_ack(change_Ton_ack),
    .Ton_data_async(Ton_data_async),

    .change_Toff_ack(change_Toff_ack),
    .Toff_data_async(Toff_data_async),

    .change_Ip_ack(change_Ip_ack),
    .Ip_data_async(Ip_data_async),

    .change_waveform_ack(change_waveform_ack),
    .waveform_data_async(waveform_data_async),

    // sampling data
    .sample_current(sample_current),
    .sample_voltage(sample_voltage),

    // signle_discharge_button
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

key_debounce key_start_debounce_inst
(
    .clk(clk_100M),
    .rst_n(sys_rst_n),
    .button_in(key_start),
    .button_posedge(  ),
    .button_negedge( machine_start_ack_key ),
    .button_out(  )
);
key_debounce key_stop_debounce_inst
(
    .clk(clk_100M),
    .rst_n(sys_rst_n),
    .button_in(key_stop),
    .button_posedge(  ),
    .button_negedge( machine_stop_ack_key ),
    .button_out(  )
); 

key_debounce key_sigle_discharge_debounce_inst
(
    .clk(clk_100M),
    .rst_n(sys_rst_n),
    .button_in( signle_discharge_button ),
    .button_posedge(  ),
    .button_negedge( signle_discharge_button_pressed ),
    .button_out(  )
); 
endmodule