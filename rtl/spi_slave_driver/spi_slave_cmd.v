module spi_slave_cmd
(
input wire clk,
input wire rst,

// spi interface
output wire miso,
input mosi,
input sclk,
input cs_n,

output reg machine_start,
output reg machine_stop,

output reg [15:0] Ton_data,
output reg [15:0] Toff_data,
output reg [15:0] Ip_data,
output reg [15:0] waveform_data,

input wire [15:0] feedback_data
);

localparam IDLE =  3'd0;
localparam START =  3'd1;
localparam STOP =  3'd2;
localparam CHANGE_TON =  3'd3;
localparam CHANGE_TOFF =  3'd4;
localparam CHANGE_IP =  3'd5;
localparam CHANGE_WAVEFORM =  3'd6;
localparam FEEDBACK =  3'd7;

(* preserve *) reg[2:0] state;
reg[2:0] next_state;
reg start_finished;
reg stop_finished;
reg change_Ton_finished;
reg change_Toff_finished;
reg change_Ip_finished;
reg change_waveform_finished;
reg feedback_finished;

wire [7:0] received_data;
wire received_data_valid;
reg [3:0] received_data_cnt;
reg [7:0] response_data;

/******************* state *******************/
always@(posedge clk or negedge rst)
begin
    if (rst == 1'b0)
        state <= IDLE;
    else
        state <= next_state;
end

always@(*)
begin
    case(state)
        IDLE:
            if(received_data_valid)
            begin
                case(received_data)
                    8'h06: next_state = START;
                    8'h04: next_state = STOP;
                    8'h91: next_state = CHANGE_TON;
                    8'h9E: next_state = CHANGE_TOFF;
                    8'h93: next_state = CHANGE_IP;
                    8'h9C: next_state = CHANGE_WAVEFORM;
                    8'hAB: next_state = FEEDBACK;
                    default: next_state = IDLE;
                endcase
            end
        START:
            if(start_finished)
                next_state = IDLE;
        STOP:
            if(stop_finished)
                next_state = IDLE;
        CHANGE_TON:
            if(change_Ton_finished)
                next_state = IDLE;
        CHANGE_TOFF:
            if(change_Toff_finished)
                next_state = IDLE;
        CHANGE_IP:
            if(change_Ip_finished)
                next_state = IDLE;
        CHANGE_WAVEFORM:
            if(change_waveform_finished)
                next_state = IDLE;
        FEEDBACK:
            if(feedback_finished)
                next_state = IDLE;
        default:
            next_state = IDLE;
    endcase
end

// received_data_cnt
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        received_data_cnt <= 4'd0;
    else if(state == IDLE)
        received_data_cnt <= 4'd0;
    else if(received_data_valid)
        received_data_cnt <= received_data_cnt + 4'd1;
end

// output reg machine_start
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        machine_start <= 1'b0;
    else if(state == START)
        machine_start <= 1'b1;
    else
        machine_start <= 1'b0;
end
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        start_finished <= 1'b0;
    else if(state == START)
        start_finished <= 1'b1;
    else
        start_finished <= 1'b0;
end

// output reg machine_stop
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        machine_stop <= 1'b0;
    else if(state == STOP)
        machine_stop <= 1'b1;
    else
        machine_stop <= 1'b0;
end
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        stop_finished <= 1'b0;
    else if(state == STOP)
        stop_finished <= 1'b1;
    else
        stop_finished <= 1'b0;
end

// output reg [15:0] Ton_data
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        Ton_data <= 16'd0;
    else if(state == CHANGE_TON)
    begin
        if(received_data_valid && received_data_cnt == 4'd1)
            Ton_data[7:0] <= received_data;
        else if(received_data_valid && received_data_cnt == 4'd2)
            Ton_data[15:8] <= received_data;
    end
end
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        change_Ton_finished <= 1'b0;
    else if(state == CHANGE_TON && received_data_valid && received_data_cnt == 4'd3)
        change_Ton_finished <= 1'b1;
    else
        change_Ton_finished <= 1'b0;
end

// reg [7:0] response_data;
always@(posedge clk or negedge rst)
begin
    if(rst == 1'b0)
        response_data <= 8'hff;
    else if(state == FEEDBACK)
        response_data <= feedback_data[7:0];
    else if(state == FEEDBACK && received_data_valid && received_data_cnt == 4'd1)
        response_data <= feedback_data[15:8];
    else
        response_data <= 8'hff;
end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
spi_slave_driver #(.mode(2'b00))
spi_slave_inst
(
    .clk(clk),
    .rst(rst),
    .rec_data(received_data),
    .rec_valid(received_data_valid),
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .cs_n(cs_n),
    .response_data(response_data)
);

endmodule