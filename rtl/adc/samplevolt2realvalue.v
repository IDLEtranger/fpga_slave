/*
    board current --- AD1
    gap voltage --- AD2
*/

module samplevolt2realvalue
( 
    input ad_clk,
    input rst_n,

    input wire signed [15:0] volt_ch1, // real vol multiple 1024
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
        sample_current_reg <= (volt_ch1 * 50); // 50A/V
        sample_voltage_reg <= (volt_ch2 * 500); // 500V/V
    end
end

assign sample_current = sample_current_reg >>> 10;
assign sample_voltage = sample_voltage_reg >>> 10;

endmodule