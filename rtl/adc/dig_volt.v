module dig_volt
(
    input wire clk_50M,
    input wire sys_rst_n,
    input wire [11:0] ad1_in,
    input wire [11:0] ad2_in,
    // usart
    input   wire    sys_clk     ,   //系统时钟100MHz
    input   wire    rx          ,   //串口接收数据
    output  wire    tx              //串口发送数据


);
//********************************************************************//
//************************Internal Signal ****************************//
//********************************************************************//
wire ad_clk;

wire volt_sign_ch1;
wire volt_sign_ch2;
wire [11:0] volt_ch1;
wire [11:0] volt_ch2;

//parameter define
parameter   UART_BPS    =   14'd9600        ,   //比特率
            CLK_FREQ    =   26'd50_000_000  ;   //时钟频率
//wire  define
wire    [7:0]   po_data;
wire            po_flag;

assign po_data = volt_ch1[7:0]
//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
ad9238 adc_inst
(
    .ad_clk(ad_clk),
    .sys_rst_n(sys_rst_n),
    .ad1_in(ad1_in),
    .ad2_in(ad2_in),
    .volt_ch1(volt_ch1),
    .volt_ch2(volt_ch2)
);

pll	pll_inst (
	.inclk0 ( clk_50M ),
	.c0 ( sys_clk ),
	.c1 ( ad_clk )
	);

uart_rx
#(
    .UART_BPS    (UART_BPS  ),  //串口波特率
    .CLK_FREQ    (CLK_FREQ  )   //时钟频率
)
uart_rx_inst
(
    .sys_clk    (sys_clk    ),  //input             sys_clk
    .sys_rst_n  (sys_rst_n  ),  //input             sys_rst_n
    .rx         (rx         ),  //input             rx
            
    .po_data    (po_data    ),  //output    [7:0]   po_data
    .po_flag    (po_flag    )   //output            po_flag
);

uart_tx
#(
    .UART_BPS    (UART_BPS  ),  //串口波特率
    .CLK_FREQ    (CLK_FREQ  )   //时钟频率
)
uart_tx_inst
(
    .sys_clk    (sys_clk    ),  //input             sys_clk
    .sys_rst_n  (sys_rst_n  ),  //input             sys_rst_n
    .pi_data    (po_data    ),  //input     [7:0]   pi_data
    .pi_flag    (po_flag    ),  //input             pi_flag
                
    .tx         (tx         )   //output            tx
);

endmodule