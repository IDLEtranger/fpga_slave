`timescale 1ns/1ns
/* 
    output volt_ch1 volt_ch2 is the real voltage(-5000mV ~ +5000mV) sampled at ADC board 
    format: bit 15 is sign bit, 0 is positive, 1 is negative, bit 14~0 is the voltage value
*/
module ad9238
( 
    input ad_clk, // 65MHz
    input rst_n,
    input [11:0] ad1_in,
    input [11:0] ad2_in,

    output reg [15:0] volt_ch1,
    output reg [15:0] volt_ch2
);

wire volt_sign_ch1;
wire volt_sign_ch2;
reg [31:0] volt_ch1_reg;
reg [31:0] volt_ch2_reg;

// 确定正负符号位 1为负
assign volt_sign_ch1 = (ad1_in < 12'b100000000000) ? 1'b1 : 1'b0;
assign volt_sign_ch2 = (ad2_in < 12'b100000000000) ? 1'b1 : 1'b0;

// 计算实际电压
always @(posedge ad_clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        volt_ch1 <= 15'b0;
        volt_ch2 <= 15'b0;
    end
    else // 将电压值放大2^13 x 1000倍，即8192000，原始精度为10V/4096，得20000，随后移位13代表除以2^13，得到mV单位的电压
    begin
        if (volt_sign_ch1 == 1'b1)
            volt_ch1_reg <= (((12'b100000000000 - ad1_in) * 20000 ) >> 13);
        else
            volt_ch1_reg <= (((ad1_in - 12'b100000000000) * 20000 ) >> 13);
        
        if (volt_sign_ch2 == 1'b1)
            volt_ch2_reg <= (((12'b100000000000 - ad2_in) * 20000 ) >> 13);
        else
            volt_ch2_reg <= (((ad2_in - 12'b100000000000) * 20000 ) >> 13);

        volt_ch1 <= {volt_sign_ch1, volt_ch1_reg[14:0]};
        volt_ch2 <= {volt_sign_ch2, volt_ch2_reg[14:0]};
    end
end
    
endmodule