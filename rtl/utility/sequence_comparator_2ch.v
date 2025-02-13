`timescale 1ns / 1ps

/*
    sequence_comparator_2ch #(.width(),.filt_sequence0(),.filt_sequence1()) SC0(
        .seq_posedge(),
        .seq_negedge(),
        .sequence_in(),
        .clk(),
        .rst_n()
        );
*/

module sequence_comparator_2ch #(parameter width = 2,filt_sequence0 = 2'b01,filt_sequence1 = 2'b10)
(
    output reg seq_posedge,
    output reg seq_negedge,
    input sequence_in,
    input clk,
    input rst_n
);
    
    reg[width:0] sequence_shift;
    
    always@(posedge clk or negedge rst_n)
    begin
        if(rst_n == 0)
            sequence_shift <= 0;
        else
            sequence_shift <= {sequence_shift[width-1:0],sequence_in};
    end
    
    always@(*)
    begin
        if(rst_n == 0)
            seq_posedge = 0;
        else if(sequence_shift[width:1] == filt_sequence0)
            seq_posedge = 1;
        else
            seq_posedge = 0;
    end
    
    always@(*)
    begin
        if(rst_n == 0)
            seq_negedge = 0;
        else if(sequence_shift[width:1] == filt_sequence1)
            seq_negedge = 1;
        else
            seq_negedge = 0;
    end
    
endmodule
