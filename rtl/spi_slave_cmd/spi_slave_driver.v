`timescale 1ns / 1ps
`define DEBUG_MODE

/*
spi_slave_driver #(.mode(2'b00))
spi_slave_inst
(
    .clk(),
    .rst_n()
    .rec_data(),
    .rec_valid(),
    .miso(),
    .mosi(),
    .sclk(),
    .cs_n(),
    .response_data()
);
*/

/*
全双工SPI从机驱动
全局时钟clk至少是sclk可能出现的最高频率的两倍起才可正常运行（建议四倍起）
rec_data为主机发过来的数据，由于在运行中rec_data会一直变化
所以在rec_valid为高电平时需要将rec_data取出保存并另存
response_data为从机响应主机数据
mode需要和主机mode保持一致
mode[1] == 1时，上升沿采样
mode[0] == 1时, 时钟空闲时为低
*/

module spi_slave_driver
#(parameter mode = 2'b00)
(
    output reg[7:0] rec_data,
    output reg rec_valid,
    
    output reg miso,
    input mosi,
    input sclk,
    input cs_n,
    
    input[7:0] response_data,
    input clk,
    input rst_n
);
    
    localparam IDLE = 0,
               WR_RD = 1;
               
    wire finish_edge;
    wire[2:0] finish_cnt;
    wire[2:0] cnt_rise,cnt_fall;
    
    `ifdef DEBUG_MODE
        (* keep *) wire sclk_rise;
        (* keep *) wire sclk_fall;
    `else
        wire sclk_rise;
        wire sclk_fall;
    `endif
    
    reg state;
    
    assign finish_edge = mode[1] ? sclk_rise : sclk_fall;
    assign finish_cnt = mode[1] ? cnt_rise : cnt_fall;
    wire cnt_rst;
    assign cnt_rst = state == IDLE;
    reg [7:0] timer_idle;
    
    always@(posedge clk or negedge rst_n)
    begin
        if(rst_n == 0)
            state <= IDLE;
        else if(state == IDLE && !cs_n && timer_idle > 8'd3)
            state <= WR_RD;
        else if(state == WR_RD && finish_edge && finish_cnt == 0 || cs_n)
            state <= IDLE;
    end

    always@(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
            timer_idle <= 8'd0;
        else if(state == IDLE)
            timer_idle <= timer_idle + 8'b1; // per 10ns +1
        else
            timer_idle <= 8'd0;
    end
    
    always@(posedge clk or negedge rst_n)
    begin
        if(rst_n == 0) begin
            miso <= 0;
            rec_data <= 0;
        end
        else if(state == IDLE) begin
            miso <= response_data[7];
            rec_data <= rec_data;
        end
        else begin
            case(mode)
                2'b00: begin
                    if(sclk_fall) begin
                        miso <= response_data[cnt_rise];
                    end
                    if(sclk_rise) begin
                        rec_data[cnt_rise] <= mosi;
                    end
                end
                2'b01: begin
                    if(sclk_rise) begin
                        miso <= response_data[cnt_rise];
                    end
                    if(sclk_fall) begin
                        rec_data[cnt_fall] <= mosi;
                    end
                end
                2'b10: begin
                    if(sclk_rise) begin
                        miso <= response_data[cnt_fall];
                    end
                    if(sclk_fall) begin
                        rec_data[cnt_fall] <= mosi;
                    end
                end
                2'b11: begin
                    if(sclk_fall) begin
                        miso <= response_data[cnt_fall];
                    end
                    if(sclk_rise) begin
                        rec_data[cnt_rise] <= mosi;
                    end
                end
            endcase
        end
    end
    
    always@(posedge clk or negedge rst_n)
    begin
        if(rst_n == 0)
            rec_valid <= 0;
        else if(state == WR_RD && finish_edge && finish_cnt == 0)
            rec_valid <= 1;
        else
            rec_valid <= 0;
    end
    
    sequence_comparator_2ch #(.width(2),.filt_sequence0(2'b01),.filt_sequence1(2'b10)) SC0(
        .seq_posedge(sclk_rise),
        .seq_negedge(sclk_fall),
        .sequence_in(sclk),
        .clk(clk),
        .rst_n(rst_n)
        );
        
    cnt_en #(.cnt_mode(1),.max_value(8)) CNT0(
        .cnt_value(cnt_rise),
        .en(sclk_rise),
        .clk(clk),
        .rst(cnt_rst)
        );
        
    cnt_en #(.cnt_mode(1),.max_value(8)) CNT1(
        .cnt_value(cnt_fall),
        .en(sclk_fall),
        .clk(clk),
        .rst(cnt_rst)
        );
    
endmodule
