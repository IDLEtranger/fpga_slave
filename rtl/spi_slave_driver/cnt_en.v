`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: ���-Tiso��Bվͬ����
// 
// Create Date: 2024/01/19 17:53:48
// Design Name: 
// Module Name: cnt_en
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
    cnt_en #(.cnt_mode(),.max_value()) CNT0(
        .cnt_value(),
        .en(),
        .clk(),
        .rst()
        );
*/

//cnt_mode���ƼӼ���0Ϊ�ӷ�����������Ϊ0��Ϊ����������
//����maxvalue����Զ�����width�������width����ֵ
//����enʹ�ܶˣ�ֱ�Ӱ�������en�ˣ���Ҫ����clk��������߼���·�ˣ�
module cnt_en #(parameter cnt_mode = 0,max_value = 10,width = max_value > 0 ? $clog2(max_value) : 1)(
    output reg[width-1:0] cnt_value,
    input en,
    input clk,
    input rst
    );
    
    always@(posedge clk or posedge rst)
    begin
        if(cnt_mode == 0) begin
            if(rst)
                cnt_value <= 0;
            else if(en) begin
                if(cnt_value >= max_value - 1)
                    cnt_value <= 0;
                else
                    cnt_value <= cnt_value + 1;  
            end  
        end
        else begin
            if(rst)
                cnt_value <= max_value - 1;
            else if(en) begin
                if(cnt_value == 0)
                    cnt_value <= max_value - 1;
                else
                    cnt_value <= cnt_value - 1;
            end
        end
    end
    
endmodule

