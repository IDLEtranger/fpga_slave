module spi_slave_cmd
(
input wire clk,
input wire rst_n,

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

input wire [31:0] feedback_data
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
wire received_data_cnt_diff;
wire received_data_cnt_reset;
reg [7:0] response_data;
(*preserve*)reg [31:0] temp_feedback_data; 

/******************* state *******************/
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0)
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
            else
                next_state = IDLE;
        START:
            if(start_finished)
                next_state = IDLE;
            else
                next_state = START;
        STOP:
            if(stop_finished)
                next_state = IDLE;
            else
                next_state = STOP;
        CHANGE_TON:
            if(change_Ton_finished)
                next_state = IDLE;
            else
                next_state = CHANGE_TON;
        CHANGE_TOFF:
            if(change_Toff_finished)
                next_state = IDLE;
            else
                next_state = CHANGE_TOFF;
        CHANGE_IP:
            if(change_Ip_finished)
                next_state = IDLE;
            else
                next_state = CHANGE_IP;
        CHANGE_WAVEFORM:
            if(change_waveform_finished)
                next_state = IDLE;
            else
                next_state = CHANGE_WAVEFORM;
        FEEDBACK:
            if(feedback_finished)
                next_state = IDLE;
            else
                next_state = FEEDBACK;
        default:
            next_state = IDLE;
    endcase
end

// received_data_cnt
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        received_data_cnt <= 4'd0;
    else if(state == IDLE)
        received_data_cnt <= 4'd0;
    else if(received_data_valid)
        received_data_cnt <= received_data_cnt + 4'd1;
end

// output reg machine_start
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        machine_start <= 1'b0;
    else if(state == START)
        machine_start <= 1'b1;
    else
        machine_start <= 1'b0;
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        start_finished <= 1'b0;
    else if(state == START)
        start_finished <= 1'b1;
    else
        start_finished <= 1'b0;
end

// output reg machine_stop
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        machine_stop <= 1'b0;
    else if(state == STOP)
        machine_stop <= 1'b1;
    else
        machine_stop <= 1'b0;
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        stop_finished <= 1'b0;
    else if(state == STOP)
        stop_finished <= 1'b1;
    else
        stop_finished <= 1'b0;
end

// output reg [15:0] Ton_data
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Ton_data <= 16'd0;
    else if(state == CHANGE_TON)
    begin
        if(received_data_cnt == 4'd1 && received_data_cnt_diff)
            Ton_data[7:0] <= received_data;
        else if(received_data_cnt == 4'd2 && received_data_cnt_diff)
            Ton_data[15:8] <= received_data;
    end
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        change_Ton_finished <= 1'b0;
    else if(state == CHANGE_TON && received_data_cnt_diff && received_data_cnt == 4'd2)
        change_Ton_finished <= 1'b1;
    else
        change_Ton_finished <= 1'b0;
end

// output reg [15:0] Toff_data
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Toff_data <= 16'd0;
    else if(state == CHANGE_TOFF)
    begin
        if(received_data_cnt == 4'd1 && received_data_cnt_diff)
            Toff_data[7:0] <= received_data;
        else if(received_data_cnt == 4'd2 && received_data_cnt_diff)
            Toff_data[15:8] <= received_data;
    end
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        change_Toff_finished <= 1'b0;
    else if(state == CHANGE_TOFF && received_data_cnt_diff && received_data_cnt == 4'd2)
        change_Toff_finished <= 1'b1;
    else
        change_Toff_finished <= 1'b0;
end

// output reg [15:0] Ip_data
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Ip_data <= 16'd0;
    else if(state == CHANGE_IP)
    begin
        if(received_data_cnt == 4'd1 && received_data_cnt_diff)
            Ip_data[7:0] <= received_data;
        else if(received_data_cnt == 4'd2 && received_data_cnt_diff)
            Ip_data[15:8] <= received_data;
    end
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        change_Ip_finished <= 1'b0;
    else if(state == CHANGE_IP && received_data_cnt_diff && received_data_cnt == 4'd2)
        change_Ip_finished <= 1'b1;
    else
        change_Ip_finished <= 1'b0;
end

// output reg [15:0] waveform_data
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        waveform_data <= 16'd0;
    else if(state == CHANGE_WAVEFORM)
    begin
        if(received_data_cnt == 4'd1 && received_data_cnt_diff)
            waveform_data[7:0] <= received_data;
        else if(received_data_cnt == 4'd2 && received_data_cnt_diff)
            waveform_data[15:8] <= received_data;
    end
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        change_waveform_finished <= 1'b0;
    else if(state == CHANGE_WAVEFORM && received_data_cnt_diff && received_data_cnt == 4'd2)
        change_waveform_finished <= 1'b1;
    else
        change_waveform_finished <= 1'b0;
end

// reg [7:0] response_data;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        response_data <= 8'hff;
    else if(state == FEEDBACK)
    begin
        if(received_data_cnt == 4'd0)
            response_data <= temp_feedback_data[7:0];
        else if(received_data_cnt == 4'd1)
            response_data <= temp_feedback_data[15:8];
        else if(received_data_cnt == 4'd2)
            response_data <= temp_feedback_data[23:16];
        else if(received_data_cnt == 4'd3)
            response_data <= temp_feedback_data[31:24];
    end
end
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        temp_feedback_data <= 32'd0;
    else if(cs_n == 1'b1)
        temp_feedback_data <= feedback_data;
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        feedback_finished <= 1'b0;
    else if(state == FEEDBACK && received_data_cnt_diff && received_data_cnt == 4'd4)
        feedback_finished <= 1'b1;
    else
        feedback_finished <= 1'b0;
end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
    spi_slave_driver #(.mode(2'b11))
    spi_slave_inst
    (
        .clk(clk),
        .rst_n(rst_n),
        .rec_data(received_data),
        .rec_valid(received_data_valid),
        .miso(miso),
        .mosi(mosi),
        .sclk(sclk),
        .cs_n(cs_n),
        .response_data(response_data)
    );

    sequence_comparator_diff #(.width(4)) SC_received_data_cnt(
        .seq_reset(received_data_cnt_reset),
        .seq_diff(received_data_cnt_diff),
        .sequence_in(received_data_cnt),
        .clk(clk),
        .rst_n(rst_n)
        );
endmodule