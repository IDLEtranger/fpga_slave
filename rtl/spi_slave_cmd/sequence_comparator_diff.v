`timescale 1ns / 1ps
// 不支持跨时钟域信号
// 归零不判断为不同
/*
    sequence_comparator_diff #(.width()) SC0(
        .seq_diff(),
        .seq_reset(),
        .sequence_in(),
        .clk(),
        .rst_n()
        );
*/

module sequence_comparator_diff #(parameter width = 2)
(
    output reg seq_diff,
    output reg seq_reset,
    input wire[width-1:0] sequence_in,
    input clk,
    input rst_n
);
    
reg [width-1:0] sequence_shift;

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 0)
    begin
        sequence_shift <= 0;
    end
    else
    begin
        sequence_shift <= sequence_in;
    end
end
    
always@(*)
begin
    if(rst_n == 0)
        seq_diff <= 0;
    else if(sequence_shift != sequence_in)
        seq_diff <= 1;
    else
        seq_diff <= 0;
end

always@(*)
begin
    if(rst_n == 0)
        seq_reset <= 0;
    else if(sequence_in == 0)
        seq_reset <= 1;
    else
        seq_reset <= 0;
end
    
endmodule
