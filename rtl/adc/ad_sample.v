module ad_sample
(
    input sys_clk,
    input ad_clk, // 65MHz
    input rst_n,

    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in,

    output wire signed [15:0] sample_current_fifo_out,
    output wire signed [15:0] sample_voltage_fifo_out
);
wire signed [15:0] volt_ch1;
wire signed [15:0] volt_ch2;

wire signed [15:0] sample_current;
wire signed [15:0] sample_voltage;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
    ad9238 ad9238_inst
    (
        .ad_clk(ad_clk),
        .rst_n(rst_n),
        .ad1_in(ad1_in),
        .ad2_in(ad2_in),
        .volt_ch1(volt_ch1),
        .volt_ch2(volt_ch2)
    );

    samplevolt2realvalue samplevolt2realvalue_inst
    (
        .ad_clk(ad_clk),
        .rst_n(rst_n),
        .volt_ch1(volt_ch1),
        .volt_ch2(volt_ch2),
        .sample_current(sample_current),
        .sample_voltage(sample_voltage)
    );

    fifo_32bits fifo_32bits_inst 
    (
        .data ( {sample_current, sample_voltage} ),
        .rdclk ( sys_clk ),
        .rdreq ( 1'b1 ),
        .wrclk ( ad_clk ),
        .wrreq ( 1'b1 ),
        .q ( {sample_current_fifo_out, sample_voltage_fifo_out} )
	);

endmodule