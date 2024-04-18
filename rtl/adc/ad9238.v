module ad9238
( 
    input ad_clk, // 65MHz
    input sys_rst_n,
    input [11:0] ad1_in,
    input [11:0] ad2_in,

    output reg [11:0] volt_ch1,
    output reg [11:0] volt_ch2
);

reg [11:0] ad_ch1;
reg [11:0] ad_ch2;
wire volt_sign_ch1;
wire volt_sign_ch2;
reg [50:0] volt_ch1_reg;
reg [50:0] volt_ch2_reg;

/* reverse data */
always @(posedge ad_clk) 
begin 
    ad_ch1[11] <= ad1_in[0];
    ad_ch1[10] <= ad1_in[1];
    ad_ch1[9] <= ad1_in[2];
    ad_ch1[8] <= ad1_in[3];
    ad_ch1[7] <= ad1_in[4];
    ad_ch1[6] <= ad1_in[5];
    ad_ch1[5] <= ad1_in[6];
    ad_ch1[4] <= ad1_in[7];
    ad_ch1[3] <= ad1_in[8];
    ad_ch1[2] <= ad1_in[9];
    ad_ch1[1] <= ad1_in[10];
    ad_ch1[0] <= ad1_in[11]; 
end

always @(posedge ad_clk) 
begin 
    ad_ch2[11] <= ad2_in[0];
    ad_ch2[10] <= ad2_in[1];
    ad_ch2[9] <= ad2_in[2];
    ad_ch2[8] <= ad2_in[3];
    ad_ch2[7] <= ad2_in[4];
    ad_ch2[6] <= ad2_in[5];
    ad_ch2[5] <= ad2_in[6];
    ad_ch2[4] <= ad2_in[7];
    ad_ch2[3] <= ad2_in[8];
    ad_ch2[2] <= ad2_in[9];
    ad_ch2[1] <= ad2_in[10];
    ad_ch2[0] <= ad2_in[11]; 
end

// 确定正负符号位 1为负
assign volt_sign_ch1 = (ad_ch1 < 12'b100000000000) ? 1'b1 : 1'b0;
assign volt_sign_ch2 = (ad_ch2 < 12'b100000000000) ? 1'b1 : 1'b0;

// 计算实际电压
always @(posedge ad_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
    begin
        volt_ch1 <= 12'b0;
        volt_ch2 <= 12'b0;
    end
    else // 将电压值放大2^13 x 1000倍，即8192000，原始精度为10V/4096，得20000，随后移位13代表除以2^13，得到mV单位的电压
    begin
        if (volt_sign_ch1 == 1'b1)
            volt_ch1_reg <= ((12'b100000000000 - ad_ch1) * 20000 ) >> 13;
        else
            volt_ch1_reg <= ((ad_ch1 - 12'b100000000000) * 20000 ) >> 13;
        
        if (volt_sign_ch2 == 1'b1)
            volt_ch2_reg <= ((12'b100000000000 - ad_ch2) * 20000 ) >> 13;
        else
            volt_ch2_reg <= ((ad_ch2 - 12'b100000000000) * 20000 ) >> 13;

        volt_ch1 <= volt_ch1_reg[11:0];
        volt_ch2 <= volt_ch2_reg[11:0];
    end
    
endmodule