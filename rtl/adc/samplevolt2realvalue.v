/*
    board current --- AD1
    gap voltage --- AD2
*/

module samplevolt2realvalue
( 
    input ad_clk,
    input rst_n,

    input wire signed [15:0] volt_ch1,
    input wire signed [15:0] volt_ch2,

    output wire signed [15:0] sample_current,
    output wire signed [15:0] sample_voltage
);

reg signed [31:0] sample_current_reg;
reg signed [31:0] sample_voltage_reg;

always @(posedge ad_clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        sample_current_reg <= 32'b0;
        sample_voltage_reg <= 32'b0;
    end
    else
    begin
        sample_current_reg <= (volt_ch1 - 2500); // sample(mV) to real(A)
        sample_voltage_reg <= (volt_ch2 * 28); // sample(mV) to real(V)
    end
end

divider_32d16	divider_32d16_inst2 
(
	.clock ( ad_clk ),
	.denom ( 16'd50 ),
	.numer ( -sample_current_reg ),
	.quotient ( sample_current ),
	.remain (  )
);

divider_32d16	divider_32d16_inst1 
(
	.clock ( ad_clk ),
	.denom ( 16'd1000 ),
	.numer ( -sample_voltage_reg ),
	.quotient ( sample_voltage ),
	.remain (  )
);

endmodule