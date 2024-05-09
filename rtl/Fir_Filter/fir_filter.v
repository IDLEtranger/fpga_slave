`timescale 1 ns / 1 ns
module fir_filter
               (
                i_fpga_clk ,
                i_rst_n    ,
                i_filter_in,
                o_filter_out
                );
input                   i_fpga_clk  ; //50MHz
input                   i_rst_n     ;
input   signed      [11:0] i_filter_in ; //数据速率50Mh
output  signed      [11:0] o_filter_out; //滤波输出
//==============================================================
//16阶滤波器系数，共17个系数，系数对称
//==============================================================

//Fs=50M Fpass=500k Fstop=5M order=16
/* wire signed[15:0] coeff1 = 16'd406;
wire signed[15:0] coeff2 = 16'd721;
wire signed[15:0] coeff3 = 16'd1060;
wire signed[15:0] coeff4 = 16'd1636;
wire signed[15:0] coeff5 = 16'd2091;
wire signed[15:0] coeff6 = 16'd2655;
wire signed[15:0] coeff7 = 16'd3003;
wire signed[15:0] coeff8 = 16'd3335;
wire signed[15:0] coeff9 = 16'd3370; */


//Fir Equiripple Fs=50M Fpass=500k Fstop=5M order=27 扩大2**15
wire signed[15:0] coeff1 = 16'd20;
wire signed[15:0] coeff2 = 16'd49;
wire signed[15:0] coeff3 = 16'd108;
wire signed[15:0] coeff4 = 16'd200;
wire signed[15:0] coeff5 = 16'd334;
wire signed[15:0] coeff6 = 16'd511;
wire signed[15:0] coeff7 = 16'd731;
wire signed[15:0] coeff8 = 16'd986;
wire signed[15:0] coeff9 = 16'd1265;
wire signed[15:0] coeff10 = 16'd1547;
wire signed[15:0] coeff11 = 16'd1812;
wire signed[15:0] coeff12 = 16'd2038;
wire signed[15:0] coeff13 = 16'd2199;
wire signed[15:0] coeff14 = 16'd2284;


reg signed [11:0] ad_reg;
always@(posedge i_fpga_clk or negedge i_rst_n)
begin
	if(~i_rst_n) ad_reg <= 12'd0;
	//else ad_reg <= i_filter_in + 12'd2048;//滤波输入+2048
	else ad_reg <= i_filter_in;//滤波输入不+2048
end
//===============================================================延时1
//    延时链
//===============================================================
reg signed [11:0] delay_pipeline1 ;
reg signed [11:0] delay_pipeline2 ;
reg signed [11:0] delay_pipeline3 ;
reg signed [11:0] delay_pipeline4 ;
reg signed [11:0] delay_pipeline5 ;
reg signed [11:0] delay_pipeline6 ;
reg signed [11:0] delay_pipeline7 ;
reg signed [11:0] delay_pipeline8 ;
reg signed [11:0] delay_pipeline9 ;
reg signed [11:0] delay_pipeline10 ;
reg signed [11:0] delay_pipeline11 ;
reg signed [11:0] delay_pipeline12 ;
reg signed [11:0] delay_pipeline13 ;
reg signed [11:0] delay_pipeline14 ;
reg signed [11:0] delay_pipeline15 ;
reg signed [11:0] delay_pipeline16 ;
reg signed [11:0] delay_pipeline17 ;
reg signed [11:0] delay_pipeline18 ;
reg signed [11:0] delay_pipeline19 ;
reg signed [11:0] delay_pipeline20 ;
reg signed [11:0] delay_pipeline21 ;
reg signed [11:0] delay_pipeline22 ;
reg signed [11:0] delay_pipeline23 ;
reg signed [11:0] delay_pipeline24 ;
reg signed [11:0] delay_pipeline25 ;
reg signed [11:0] delay_pipeline26 ;
reg signed [11:0] delay_pipeline27 ;

always@(posedge i_fpga_clk or negedge i_rst_n)
       if(!i_rst_n)
                begin
                    delay_pipeline1 <= 12'b0 ;
                    delay_pipeline2 <= 12'b0 ;
                    delay_pipeline3 <= 12'b0 ;
                    delay_pipeline4 <= 12'b0 ;
                    delay_pipeline5 <= 12'b0 ;
                    delay_pipeline6 <= 12'b0 ;
                    delay_pipeline7 <= 12'b0 ;
                    delay_pipeline8 <= 12'b0 ;
					delay_pipeline9  <= 12'b0 ;
					delay_pipeline10 <= 12'b0 ;
					delay_pipeline11 <= 12'b0 ;
					delay_pipeline12 <= 12'b0 ;
					delay_pipeline13 <= 12'b0 ;
					delay_pipeline14 <= 12'b0 ;
					delay_pipeline15 <= 12'b0 ;
					delay_pipeline16 <= 12'b0 ;
					delay_pipeline17 <= 12'b0 ;
					delay_pipeline18 <= 12'b0 ;
					delay_pipeline19 <= 12'b0 ;
					delay_pipeline20 <= 12'b0 ;
					delay_pipeline21 <= 12'b0 ;
					delay_pipeline22 <= 12'b0 ;
					delay_pipeline23 <= 12'b0 ;
					delay_pipeline24 <= 12'b0 ;
					delay_pipeline25 <= 12'b0 ;
					delay_pipeline26 <= 12'b0 ;
					delay_pipeline27 <= 12'b0 ;
					
                end
       else
                begin
                    delay_pipeline1  <= ad_reg;//提前加上2048
                    delay_pipeline2 <= delay_pipeline1 ;
                    delay_pipeline3 <= delay_pipeline2 ;
                    delay_pipeline4 <= delay_pipeline3 ;
                    delay_pipeline5 <= delay_pipeline4 ;
                    delay_pipeline6 <= delay_pipeline5 ;
                    delay_pipeline7 <= delay_pipeline6 ;
                    delay_pipeline8 <= delay_pipeline7 ;
					delay_pipeline9  <= delay_pipeline8 ;
					delay_pipeline10 <= delay_pipeline9 ;
					delay_pipeline11 <= delay_pipeline10;
					delay_pipeline12 <= delay_pipeline11;
					delay_pipeline13 <= delay_pipeline12;
					delay_pipeline14 <= delay_pipeline13;
					delay_pipeline15 <= delay_pipeline14;
					delay_pipeline16 <= delay_pipeline15;
					delay_pipeline17 <= delay_pipeline16; 
					delay_pipeline18 <= delay_pipeline17; 
					delay_pipeline19 <= delay_pipeline18; 
					delay_pipeline20 <= delay_pipeline19; 
					delay_pipeline21 <= delay_pipeline20; 
					delay_pipeline22 <= delay_pipeline21; 
					delay_pipeline23 <= delay_pipeline22; 
					delay_pipeline24 <= delay_pipeline23; 
					delay_pipeline25 <= delay_pipeline24; 
					delay_pipeline26 <= delay_pipeline25; 
					delay_pipeline27 <= delay_pipeline26; 
                end
     
//================================================================延时2
//加法，对称结构，减少乘法器的数目
//================================================================
reg signed [12:0] add_data1;
reg signed [12:0] add_data2;
reg signed [12:0] add_data3;
reg signed [12:0] add_data4;
reg signed [12:0] add_data5;
reg signed [12:0] add_data6;
reg signed [12:0] add_data7;
reg signed [12:0] add_data8;
reg signed [12:0] add_data9;
reg signed [12:0] add_data10;
reg signed [12:0] add_data11;
reg signed [12:0] add_data12;
reg signed [12:0] add_data13;
reg signed [12:0] add_data14;

always@(posedge i_fpga_clk or negedge i_rst_n) //x(0)+x(8)
       if(!i_rst_n)      
			begin
			add_data1 <= 13'b0 ;
			add_data2 <= 13'b0 ;
			add_data3 <= 13'b0 ;
			add_data4 <= 13'b0 ;
			add_data5 <= 13'b0 ;
			add_data6 <= 13'b0 ;
			add_data7 <= 13'b0 ;
			add_data8 <= 13'b0 ;
			add_data9 <= 13'b0 ;
			add_data10 <= 13'b0 ;
			add_data11 <= 13'b0 ;
			add_data12 <= 13'b0 ;
			add_data13 <= 13'b0 ;
			add_data14 <= 13'b0 ;
			end
       else
			begin
            add_data1 <= ad_reg + delay_pipeline27;
			add_data2 <= delay_pipeline1 + delay_pipeline26;
			add_data3 <= delay_pipeline2 + delay_pipeline25;
			add_data4 <= delay_pipeline3 + delay_pipeline24;
			add_data5 <= delay_pipeline4 + delay_pipeline23;
			add_data6 <= delay_pipeline5 + delay_pipeline22;
			add_data7 <= delay_pipeline6 + delay_pipeline21;
			add_data8 <= delay_pipeline7 + delay_pipeline20;
			add_data9 <= delay_pipeline8 + delay_pipeline19;
			add_data10 <= delay_pipeline9 + delay_pipeline18;
			add_data11 <= delay_pipeline10 + delay_pipeline17;
			add_data12 <= delay_pipeline11 + delay_pipeline16;
			add_data13 <= delay_pipeline12 + delay_pipeline15;
			add_data14 <= delay_pipeline13 + delay_pipeline14;			
			 end
 
//===================================================================延时3
//乘法器
//====================================================================
reg signed [28:0] multi_data1 ;
reg signed [28:0] multi_data2 ;
reg signed [28:0] multi_data3 ;
reg signed [28:0] multi_data4 ;
reg signed [28:0] multi_data5 ;
reg signed [28:0] multi_data6 ;
reg signed [28:0] multi_data7 ;
reg signed [28:0] multi_data8 ;
reg signed [28:0] multi_data9 ;
reg signed [28:0] multi_data10 ;
reg signed [28:0] multi_data11 ;
reg signed [28:0] multi_data12 ;
reg signed [28:0] multi_data13 ;
reg signed [28:0] multi_data14 ;
always@(posedge i_fpga_clk or negedge i_rst_n) //（x(0)+x(8)）*h(0)
       if(!i_rst_n) 
			begin
            multi_data1 <= 29'b0 ;
			multi_data2 <= 29'b0 ;
			multi_data3 <= 29'b0 ;
			multi_data4 <= 29'b0 ;
			multi_data5 <= 29'b0 ;
			multi_data6 <= 29'b0 ;
			multi_data7 <= 29'b0 ;
			multi_data8 <= 29'b0 ;
			multi_data9 <= 29'b0 ;
			multi_data10 <= 29'b0 ;
			multi_data11 <= 29'b0 ;
			multi_data12 <= 29'b0 ;
			multi_data13 <= 29'b0 ;
			multi_data14 <= 29'b0 ;
			 end
       else
			begin
			multi_data1 <= add_data1 * coeff1 ;
			multi_data2 <= add_data2 * coeff2 ;
			multi_data3 <= add_data3 * coeff3 ;
			multi_data4 <= add_data4 * coeff4 ;
			multi_data5 <= add_data5 * coeff5 ;
			multi_data6 <= add_data6 * coeff6 ;
			multi_data7 <= add_data7 * coeff7 ;
			multi_data8 <= add_data8 * coeff8 ;
			multi_data9 <= add_data9 * coeff9 ;
			multi_data10 <= add_data10 * coeff10 ;
			multi_data11 <= add_data11 * coeff11 ;
			multi_data12 <= add_data12 * coeff12 ;
			multi_data13 <= add_data13 * coeff13 ;
			multi_data14 <= add_data14 * coeff14 ;
			  
			end

//========================================================================延时4
//流水线累加
//========================================================================
reg signed[29:0] add_level1_1;//1级
reg signed[29:0] add_level1_2;//1级
reg signed[29:0] add_level1_3;//1级
reg signed[29:0] add_level1_4;//1级
reg signed[29:0] add_level1_5;//1级
reg signed[29:0] add_level1_6;//1级
reg signed[29:0] add_level1_7;//1级


always@(posedge i_fpga_clk or negedge i_rst_n) //（x(0)+x(8)）*h(0)+（x(1)+x(7)）*h(1)
       if(!i_rst_n) 
			begin
			add_level1_1 <= 30'b0 ;
			add_level1_2 <= 30'b0 ;
			add_level1_3 <= 30'b0 ;
			add_level1_4 <= 30'b0 ;
			add_level1_5 <= 30'b0 ;
			add_level1_6 <= 30'b0 ;
			add_level1_7 <= 30'b0 ;
			end
       else
			begin
            add_level1_1 <= multi_data1 + multi_data2 ;
			add_level1_2 <= multi_data3 + multi_data4 ;
			add_level1_3 <= multi_data5 + multi_data6 ;
			add_level1_4 <= multi_data7 + multi_data8 ;
			add_level1_5 <= multi_data9 + multi_data10 ;
			add_level1_6 <= multi_data11 + multi_data12 ;
			add_level1_7 <= multi_data13 + multi_data14 ;			
			end

//==2级加法																								延时5
reg signed [30:0] add_level2_1 ;
reg signed [30:0] add_level2_2 ;
reg signed [30:0] add_level2_3 ;
reg signed [30:0] add_level2_4 ;

always@(posedge i_fpga_clk or negedge i_rst_n) //（x(0)+x(8)）*h(0)+（x(1)+x(7)）*h(1)+（x(2)+x(6)）*h(2)+（x(3)+x(5)）*h(3)
       if(!i_rst_n) 
			begin
            add_level2_1 <= 31'b0 ;
			add_level2_2 <= 31'b0 ;
			add_level2_3 <= 31'b0 ;
			add_level2_4 <= 31'b0 ;
			end
       else
			begin
            add_level2_1 <= add_level1_1+add_level1_2 ;
			add_level2_2 <= add_level1_3+add_level1_4 ;
			add_level2_3 <= add_level1_5+add_level1_6 ;
			add_level2_4 <= {add_level1_7[29],add_level1_7} ;
			end

//-===3级																								延时6
reg signed [31:0] add_level3_1 ;
reg signed [31:0] add_level3_2 ;
always@(posedge i_fpga_clk or negedge i_rst_n)
       if(!i_rst_n) 
			begin
			add_level3_1 <= 32'b0 ;
            add_level3_2 <= 32'b0 ;
			end
       else
			begin
            add_level3_1 <= add_level2_1+add_level2_2;
			add_level3_2 <= add_level2_3+add_level2_4;
			end
			  

//-===4级			  																						延时7
reg signed [32:0] add_level4_1 ;
always@(posedge i_fpga_clk or negedge i_rst_n)
       if(!i_rst_n) 
			begin
			add_level4_1 <= 33'b0 ;
			end
       else
			begin
            add_level4_1 <= add_level3_1+add_level3_2;
			end
			  
//================================================================================延时8
// 5、output         ------>按自己理解的截位                                                        
//================================================================================
// reg signed  [26:0]  r_filter_out ;
//always@(posedge i_fpga_clk or negedge i_rst_n)
//	if(!i_rst_n)                                   
//		r_filter_out <= 27'b0 ;
//	else
//		begin
//			if((add_level4_1[32:26]==7'b0_000_000) /*|| (add_level4_1[32:26]==7'b1_111_111)*/) r_filter_out <= add_level4_1[26:0];
//			else if(add_level4_1[32:26]==7'b1_111_111) r_filter_out <= 27'd0;
//			else r_filter_out <= (add_level4_1[32])?27'd0:27'd6710_8863;
//		end

reg signed  [26:0]  r_filter_out ;
always@(posedge i_fpga_clk or negedge i_rst_n)
	if(!i_rst_n)                                   
		r_filter_out <= 27'b0 ;
	else
		begin
			if((add_level4_1[32:26]==7'b0_000_000) || (add_level4_1[32:26]==7'b1_111_111)) r_filter_out <= add_level4_1[26:0];
			else r_filter_out <= (add_level4_1[32])?27'd6710_8863:27'd6710_8863;
		end

//================================================================================
// 6、output   因为系数扩大了2**15，因此输出结果右移15                                                              
//================================================================================
 assign o_filter_out  = r_filter_out[26:15];			  
			  

 
endmodule
