module FirFilter_top(
					//system
					input clk,
					input rst_n,
					
					//ad9226 input
					input [11:0] ad_ch1,
					input [11:0] ad_ch2,
					
					//fir output
					output [11:0] filtered_wave,
					output [11:0] filtered_vol
); 



wire signed [11:0] o_filter_out;
fir_filter u_fir_filter
               (
                .i_fpga_clk(clk) ,
                .i_rst_n (rst_n)   ,
                .i_filter_in(ad_ch1),
                .o_filter_out(o_filter_out)
                );




Fir_Error_Compensation u_Fir_Error_Compensation(
									 .clk(clk),
									 .rst_n(rst_n),
									
									//fir output
									 .o_filter_out(o_filter_out),
									
									//after compensation
									 .o_filter_acc(filtered_wave)
									
);


AvgFilter u_AvgFilter
(
	.clk(clk),
	.rst_n(rst_n),
	
	.ad_ch2(ad_ch2),
	.filtered_vol(filtered_vol)
);






endmodule 