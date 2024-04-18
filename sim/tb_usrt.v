`timescale 1ns/1ns
module tb_usrt();
// wire define
reg rxd;
wire txd;

// reg define
reg clk_50M;
reg sys_rst_n;

initial 
begin
    sys_rst_n <= 1'b0;
    clk_50M <= 1'b1;
    rxd <= 1'b1;
    #20;
    sys_rst_n = 1'b1;
end

always #10 clk_50M = ~clk_50M;

initial 
begin
    #200
    rx_byte();
end

task rx_byte();
    integer j;
    for(j = 0; j < 8; j = j + 1)
        rx_bit(j);
endtask

task rx_bit(input [7:0] data);
    integer i;
    for(i=0; i<10; i=i+1)
    begin
        case(i)
            0: rxd <= 1'b0;
            1: rxd <= data[0];
            2: rxd <= data[1];
            3: rxd <= data[2];
            4: rxd <= data[3];
            5: rxd <= data[4];
            6: rxd <= data[5];
            7: rxd <= data[6];
            8: rxd <= data[7];
            9: rxd <= 1'b1;
        endcase
        #(5208*40);
    end
endtask

// instantiation
fpga_slave fpga_slave_inst
(
    .clk_50M(clk_50M),
	.sys_rst_n(sys_rst_n),
    
    /** USART **/
	.uart_rx(rxd),
	.uart_tx(txd)

    /** ADC **/

    /** SPI_SLAVE **/
);
endmodule