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
    .timer_stand(  ),
    .timer_start(  ),
    .timer_restart(  ),
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
    input wire timer_stand,
    input wire timer_start,
    input wire timer_restart,
    output wire [WIDTH-1:0] output_timer
);

localparam IDLE = 2'b00;
localparam COUNTING = 2'b10;
localparam STAND = 2'b01;

reg [2:0] state;
reg [WIDTH-1:0] count_value;

wire start_pulse_posedge;
wire reset_pulse_posedge;
wire stand_pulse_posedge;

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
                if ( start_pulse_posedge ) 
                    state <= COUNTING;
                else if ( stand_pulse_posedge )
                    state <= STAND;
                else if ( restart_pulse_posedge )
                    state <= COUNTING;
            COUNTING:
                if ( reset_pulse_posedge ) 
                    state <= IDLE;
                else if ( stand_pulse_posedge )
                    state <= STAND;
            STAND:
                if ( reset_pulse_posedge ) 
                    state <= IDLE;
                else if ( start_pulse_posedge ) 
                    state <= COUNTING;
                else if (restart_pulse_posedge)
                    state <= COUNTING;
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
        if (restart_pulse_posedge == 1'b1)
            count_value <= INIT_VALUE;
        case (state)
            IDLE:
                count_value <= INIT_VALUE;
            COUNTING:
                count_value <= count_value + 1;
        endcase
    end
end

assign output_timer = count_value;

sequence_comparator_2ch sequence_comparator_start
(
    .seq_posedge(start_pulse_posedge),
    .seq_negedge(),
    .sequence_in(timer_start),
    .clk(clk),
    .rst_n(rst_n)
);

sequence_comparator_2ch sequence_comparator_reset
(
    .seq_posedge(reset_pulse_posedge),
    .seq_negedge(),
    .sequence_in(timer_reset),
    .clk(clk),
    .rst_n(rst_n)
);

sequence_comparator_2ch sequence_comparator_stand
(
    .seq_posedge(stand_pulse_posedge),
    .seq_negedge(),
    .sequence_in(timer_stand),
    .clk(clk),
    .rst_n(rst_n)
);

sequence_comparator_2ch sequence_comparator_restart
(
    .seq_posedge(restart_pulse_posedge),
    .seq_negedge(),
    .sequence_in(timer_restart),
    .clk(clk),
    .rst_n(rst_n)
);
endmodule
