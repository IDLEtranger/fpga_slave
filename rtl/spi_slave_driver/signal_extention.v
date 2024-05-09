/*
    extend signal to sustain for a few cycles
*/
module signal_extension #(
    parameter SUSTAIN_CYCLES = 7
)
(
    input clk,
    input rst_n,
    input signal,
    output reg signal_extended
);

localparam COUNTER_WIDTH = $clog2(SUSTAIN_CYCLES + 1); // 计算所需的计数器位宽

reg [COUNTER_WIDTH-1:0] counter;
reg start_count;

always @(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
    begin
        signal_extended <= 1'b0;
        counter <= 0;
        start_count <= 1'b0;
    end 
    else 
    begin
        if (signal) 
        begin
            start_count <= 1'b1;
        end
        
        if (start_count) 
        begin
            if (counter < SUSTAIN_CYCLES) 
            begin
                counter <= counter + 1;
                signal_extended <= 1'b1;
            end 
            else 
            begin
                start_count <= 1'b0;
                counter <= 0;
                signal_extended <= 1'b0;
            end
        end 
        
        else
        begin
            signal_extended <= 1'b0;
        end
    end
end

endmodule