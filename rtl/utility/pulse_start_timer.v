/*
pulse_start_timer
#(
    .WIDTH( 16 ),
    .INIT_VALUE( 0 )
)
pulse_start_timer_inst
(
    .clk(  ),
    .rst_n(  ),
    .timer_reset(  ),
    .start_pulse(  ),
    .output_timer(  )
);
*/

module pulse_start_timer
#(
    parameter WIDTH = 16,
    parameter INIT_VALUE = 0
)
(
    input wire clk,
    input wire rst_n,
    input wire timer_reset,
    input wire start_pulse,
    output wire [WIDTH-1:0] output_timer
);

localparam IDLE = 1'b0;
localparam COUNTING = 1'b1;

reg state;
reg [WIDTH-1:0] count_value;

always @(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
    begin
        state <= IDLE;
    end 
    else 
    begin
        case (state)
            IDLE:
                if (start_pulse) 
                begin
                    state <= COUNTING;
                end
            COUNTING:
                if (timer_reset) 
                begin
                    state <= IDLE;
                end
        endcase
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) 
    begin
        count_value <= INIT_VALUE;
    end 
    else 
    begin
        case (state)
            IDLE:
                count_value <= INIT_VALUE;
            COUNTING:
                count_value <= count_value + 1;
        endcase
    end
end

assign output_timer = count_value;

endmodule
