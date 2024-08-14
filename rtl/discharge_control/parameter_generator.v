module parameter_generator
(
    input wire clk,
    input wire rst_n,

    input wire machine_start_ack_spi,
    input wire machine_stop_ack_spi,
    output reg is_machine_spi,

    input wire change_Ton_ack,
    input wire [15:0] Ton_data_async,
    output reg [15:0] Ton_data,
    
    input wire change_Toff_ack,
    input wire [15:0] Toff_data_async,
    output reg [15:0] Toff_data,

    input wire change_Ip_ack,
    input wire [15:0] Ip_data_async,
    output reg [15:0] Ip_data,
    
    input wire change_waveform_ack,
    input wire [15:0] waveform_data_async,
    output reg [15:0] waveform_data
);

reg [2:0] machine_start_ack_stage;
reg [2:0] machine_stop_ack_stage;
reg [2:0] change_Ton_ack_stage;
reg [2:0] change_Toff_ack_stage;
reg [2:0] change_Ip_ack_stage;
reg [2:0] change_waveform_ack_stage;

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        machine_start_ack_stage <= 3'b0;
        machine_stop_ack_stage <= 3'b0;
        change_Ton_ack_stage <= 3'b0;
        change_Toff_ack_stage <= 3'b0;
        change_Ip_ack_stage <= 3'b0;
        change_waveform_ack_stage <= 3'b0;
    end
    else
    begin
        machine_start_ack_stage <= {machine_start_ack_stage[1:0], machine_start_ack_spi};
        machine_stop_ack_stage <= {machine_stop_ack_stage[1:0], machine_stop_ack_spi};
        change_Ton_ack_stage <= {change_Ton_ack_stage[1:0], change_Ton_ack};
        change_Toff_ack_stage <= {change_Toff_ack_stage[1:0], change_Toff_ack};
        change_Ip_ack_stage <= {change_Ip_ack_stage[1:0], change_Ip_ack};
        change_waveform_ack_stage <= {change_waveform_ack_stage[1:0], change_waveform_ack};
    end
end

// synchronize pulse parameter to sys_clk
always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        is_machine_spi <= 1'b0;
    else if( machine_start_ack_stage[2] == 1'b1 )
        is_machine_spi <= 1'b1;
    else if( machine_stop_ack_stage[2] == 1'b1 )
        is_machine_spi <= 1'b0;
end

always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Ton_data <= 16'd0;
    else if( change_Ton_ack_stage[2] == 1'b1 )
        Ton_data <= Ton_data_async;
end

always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Toff_data <= 16'd0;
    else if( change_Toff_ack_stage[2] == 1'b1 )
        Toff_data <= Toff_data_async;
end

always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        Ip_data <= 16'd0;
    else if( change_Ip_ack_stage[2] == 1'b1 )
        Ip_data <= Ip_data_async;
end

always @(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        waveform_data <= 16'h0000;
    else if( change_waveform_ack_stage[2] == 1'b1 )
        waveform_data <= waveform_data_async;
end


endmodule