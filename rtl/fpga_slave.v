`timescale 1ns/1ns
module fpga_slave
(
    input wire clk_50M,
	input wire sys_rst_n,
    
    /** USART **/
	input wire uart_rx,
	output wire uart_tx,

    /** ADC **/
    output wire ad1_clk,
    output wire ad2_clk,
    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in

    /** SPI_SLAVE **/
);
/* pll output clock */
wire sys_clk; // system clock 100MHz
wire ad_clk; // adc clock 65MHz
assign ad1_clk = ad_clk;
assign ad2_clk = ad_clk;

/*********************************/
/************* USART *************/
/*********************************/
parameter                        CLK_FRE = 100; // Mhz

localparam                       IDLE =  3'd0;
localparam                       SEND =  3'd1;   // send HELLO ALINX\r\n
localparam                       WAIT =  3'd2;   // wait 1 second and send uart received data

reg[7:0]                         tx_data;
reg[7:0]                         tx_str;
reg                              tx_data_valid; // data to be sent is valid
wire                             tx_data_ready; // uart_tx module ready to sent new data
reg[7:0]                         tx_cnt;
wire[7:0]                        rx_data;
wire                             rx_data_valid; // received serial data is valid
wire                             rx_data_ready; // data receiver module ready to receive data
reg[31:0]                        wait_cnt;
reg[2:0]                         state;
reg[2:0]                         next_state;

assign rx_data_ready = 1'b1;//always can receive data

always@(posedge sys_clk or negedge sys_rst_n)
begin
    if (sys_rst_n == 1'b0)
        state <= IDLE;
    else
        state <= next_state;
end

// state
/* 测试程序设计FPGA为1秒向串口发送一次“AD1：xxxxmV\r\nAD2：xxxxmV”
不发送期间，如果接受到串口数据，直接把接收到的数据送到发送模块再返回 */
always@(*)
begin
    case(state)
        IDLE:
            next_state = SEND;
        SEND:
            if(tx_data_valid && tx_data_ready && tx_cnt == 8'd12)
                next_state = WAIT;
            else
                next_state = SEND;
        WAIT:
            if(wait_cnt >= CLK_FRE * 1000000) // wait for 1 second
                next_state = SEND;
            else
                next_state = WAIT;
        default:
            next_state = IDLE;
    endcase
end

// wait_cnt
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(sys_rst_n == 1'b0)
    begin
        wait_cnt <= 32'd0;
    end
    else if(state == WAIT)
        wait_cnt <= wait_cnt + 32'd1;
    else
        wait_cnt <= 32'd0;
end

// tx_data
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(sys_rst_n == 1'b0)
    begin
        tx_data <= 8'd0;
    end
    else if(state == SEND)
        tx_data <= tx_str;
    else if(state == WAIT && rx_data_valid)
        tx_data <= rx_data;

end

// tx_cnt
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(sys_rst_n == 1'b0)
    begin
        tx_cnt <= 8'd0;
    end
    else if(state == SEND && tx_data_valid && tx_data_ready && tx_cnt < 8'd15) //Send 12 bytes data
		tx_cnt <= tx_cnt + 8'd1; //Send data counter
	else if(state == SEND && tx_data_valid && tx_data_ready)//last byte sent is complete
		tx_cnt <= 8'd0;
end

// tx_data_valid
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(sys_rst_n == 1'b0)
    begin
        tx_data_valid <= 1'b0;
    end
    else if(state == SEND && tx_data_valid && tx_data_ready)//last byte sent is complete
        tx_data_valid <= 1'b0;
    else if(state == SEND && ~tx_data_valid)
        tx_data_valid <= 1'b1;
    else if(state == WAIT && tx_data_valid && tx_data_ready)
        tx_data_valid <= 1'b0;
    else if(state == WAIT && rx_data_valid) // 不发送WAIT状态下接收到数据, 直接发送
        tx_data_valid <= 1'b1;
end

always@(*)
begin
	case(tx_cnt)
		8'd0  :  tx_str <= 8'hff;
		8'd1  :  tx_str <= 8'h00;
		8'd2  :  tx_str <= 8'h00;
		8'd3  :  tx_str <= 8'hff;
		8'd4  :  tx_str <= {4'b0000, volt_ch1[11:8]};
		8'd5  :  tx_str <= volt_ch1[7:0];
		8'd6  :  tx_str <= 8'hff;
		8'd7  :  tx_str <= 8'h00;
		8'd8  :  tx_str <= 8'h00;
		8'd9  :  tx_str <= 8'h00;
		8'd10 :  tx_str <= 8'h00;
		8'd11 :  tx_str <= 8'hff;
		8'd12 :  tx_str <= {4'b0000, volt_ch2[11:8]};
		8'd13 :  tx_str <= volt_ch2[7:0];
		8'd14 :  tx_str <= 8'hff;
		8'd15 :  tx_str <= 8'h00;
		default:tx_str <= 8'd0;
	endcase
end
/*********************************/
/************** ADC **************/
/*********************************/
// ADC output data(mV)
wire [15:0] volt_ch1; // voltage channel 1
wire [15:0] volt_ch2;

/*************************************/
/************* SPI_SLAVE *************/
/*************************************/

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
pll	pll_inst 
(
	.inclk0 ( clk_50M ),
	.c0 ( sys_clk ), // sys_clk 100MHz
	.c1 ( ad_clk ) // ad_clk 65MHz
);

uart_rx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(115200)
) uart_rx_inst
(
	.clk                        (sys_clk                      ),
	.rst_n                      (sys_rst_n                    ),
	.rx_data                    (rx_data                  ),
	.rx_data_valid              (rx_data_valid            ),
	.rx_data_ready              (rx_data_ready            ),
	.rx_pin                     (uart_rx                  )
);

uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(115200)
) uart_tx_inst
(
	.clk                        (sys_clk                  ),
	.rst_n                      (sys_rst_n                    ),
	.tx_data                    (tx_data                  ),
	.tx_data_valid              (tx_data_valid            ),
	.tx_data_ready              (tx_data_ready            ),
	.tx_pin                     (uart_tx                  )
);

ad9238 adc_inst
( 
    .ad_clk (ad_clk),
    .sys_rst_n (sys_rst_n),
    .ad1_in (ad1_in),
    .ad2_in (ad2_in),

    .volt_ch1 (volt_ch1),
    .volt_ch2 (volt_ch2)
);

endmodule