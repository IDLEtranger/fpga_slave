`timescale 1ns/1ns
module tb_dig_volt();
// wire define
wire led1;
wire led2;

// reg define
reg sys_clk;
reg sys_rst_n;
reg [11:0] ad1_in;
reg [11:0] ad2_in;
reg data_en;

initial 
begin
    sys_rst_n = 1'b0;
    sys_clk = 1'b0;
    #200
    sys_rst_n = 1'b1;
end

always #10 sys_clk = ~sys_clk;


always @(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
    begin
        ad1_in <= 12'b0;
        ad2_in <= 12'b0;
    end
    else
    begin
        ad1_in <= {$random} % 4096;
        ad2_in <= {$random} % 4096;
    end

// instantiation
fpga_slave fpga_slave_inst
(
    .clk_50M(sys_clk),
    .sys_rst_n(sys_rst_n),
    .ad1_in(ad1_in),
    .ad2_in(ad2_in),

    .led1(led1),
    .led2(led2)
);
endmodule