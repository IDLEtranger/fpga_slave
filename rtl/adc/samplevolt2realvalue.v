/*
    board current --- AD1
    gap voltage --- AD2
*/

module samplevolt2realvalue
( 
    input clk, // 50MHz
    input rst_n,

    input wire [15:0] volt_ch1,
    input wire [15:0] volt_ch2,

    output reg [15:0] sample_current,
    output reg [15:0] sample_voltage
);

always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        sample_current <= 16'b0;
        sample_voltage <= 16'b0;
    end
    else
    begin
        sample_current <= {volt_ch1[15], volt_ch1[14:0] / 125}; // sample(mV) to real(A)
        sample_voltage <= {volt_ch2[15], volt_ch2[14:0] * 28 / 1000}; // sample(mV) to real(V)
    end
end

endmodule