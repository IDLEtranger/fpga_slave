/* 
    output volt_ch1 volt_ch2 is the real voltage(-5000mV ~ +5000mV) sampled at ADC board 
    format: 16-bit signed integer (two's complement)

    board current --- AD1
    gap voltage --- AD2
*/
module ad9238
( 
    input ad_clk, // 65MHz
    input rst_n,
    input [11:0] ad1_in,
    input [11:0] ad2_in,

    output reg signed [15:0] volt_ch1,
    output reg signed [15:0] volt_ch2
);

reg [11:0] ad1_in_reg;
reg [11:0] ad2_in_reg;
reg [31:0] volt_ch1_reg;
reg [31:0] volt_ch2_reg;

// 计算实际电压
always @(posedge ad_clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        volt_ch1 <= 16'b0;
        volt_ch2 <= 16'b0;
    end
    else // 将电压值乘以原始精度为4V/4096(1/1024等于右移10位), 不移动相当于得到1024倍的电压
    begin
        ad1_in_reg <= ad1_in + 12'd80; // offset got by experiment
        ad2_in_reg <= ad2_in - 12'd94;

        if (ad1_in_reg < 12'b100000000000)
        begin
            volt_ch1_reg <= (12'b100000000000 - ad1_in_reg);
            volt_ch1 <= -volt_ch1_reg[15:0];
        end
        else
        begin
            volt_ch1_reg <= (ad1_in_reg - 12'b100000000000);
            volt_ch1 <= volt_ch1_reg[15:0];
        end
        
        if (ad2_in_reg < 12'b100000000000)
        begin
            volt_ch2_reg <= (12'b100000000000 - ad2_in_reg);
            volt_ch2 <= -volt_ch2_reg[15:0];
        end
        else
        begin
            volt_ch2_reg <= (ad2_in_reg - 12'b100000000000);
            volt_ch2 <= volt_ch2_reg[15:0];
        end
    end
end
    
endmodule