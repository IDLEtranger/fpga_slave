`timescale 1ns/1ns
module tb_sequence_comparator();

reg sys_clk;
reg sys_rst_n;

reg sclk;
wire sclk_rise;
wire sclk_fall;

initial 
begin
    sys_rst_n = 1'b0;
    sys_clk = 1'b0;
    #200
    sys_rst_n = 1'b1;
end

always #10 sys_clk = ~sys_clk;

always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        sclk <= 1'b0;
    else
        sclk <= {$random} % 2;

sequence_comparator_2ch #(.width(2),.filt_sequence0(2'b01),.filt_sequence1(2'b10)) SC0(
    .seq_posedge(sclk_rise),
    .seq_negedge(sclk_fall),
    .sequence_in(sclk),
    .clk(sys_clk),
    .rst_n(sys_rst_n)
    );

endmodule