/*
    board current --- AD1
    gap voltage --- AD2
*/

module samplevolt2realvalue
( 
    input ad_clk, // 50MHz
    input rst_n,

    input wire signed [15:0] volt_ch1,
    input wire signed [15:0] volt_ch2,

    output reg signed [15:0] sample_current,
    output reg signed [15:0] sample_voltage
);
reg [31:0] sample_voltage_reg;

always @(posedge ad_clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        sample_current <= 16'b0;
        sample_voltage <= 16'b0;
        sample_voltage_reg <= 32'b0;
    end
    else
    begin
        sample_current <= (volt_ch1 * -4 + 20000) / 1000; // sample(mV) to real(A)
        sample_voltage_reg <= (volt_ch2 * 28) / 1000; // sample(mV) to real(V)
        sample_voltage <= sample_voltage_reg[15:0];
    end
end

endmodule