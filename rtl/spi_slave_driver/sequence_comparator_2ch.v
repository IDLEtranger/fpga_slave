`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Çç¿Õ-Tiso£¨BÕ¾Í¬Ãû£©
// 
// Create Date: 2024/03/03 00:07:31
// Design Name: 
// Module Name: sequence_comparator_2ch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
    sequence_comparator_2ch #(.width(),.filt_sequence0(),.filt_sequence1()) SC0(
        .result0(),
        .result1(),
        .sequence_in(),
        .clk(),
        .rst()
        );
*/

module sequence_comparator_2ch #(parameter width = 8,filt_sequence0 = 8'h0f,filt_sequence1 = 8'hf0)(
    output reg result0,
    output reg result1,
    input sequence_in,
    input clk,
    input rst
    );
    
    reg[width-2:0] sequence_shift;
    
    always@(posedge clk or posedge rst)
    begin
        if(rst)
            sequence_shift <= 0;
        else
            sequence_shift <= {sequence_shift[width-2:0],sequence_in};
    end
    
    always@(*)
    begin
        if(rst)
            result0 = 0;
        else if({sequence_shift[width-2:0],sequence_in} == filt_sequence0)
            result0 = 1;
        else
            result0 = 0;
    end
    
    always@(*)
    begin
        if(rst)
            result1 = 0;
        else if({sequence_shift[width-2:0],sequence_in} == filt_sequence1)
            result1 = 1;
        else
            result1 = 0;
    end
    
endmodule
