`timescale 1ns / 1ps

module tb_fpga_slave;

    reg clk_in;
    reg sys_rst_n;
    reg key_start;
    reg key_stop;
    reg signle_discharge_button;
    reg mosi;
    reg sclk;
    reg cs_n;
    wire miso;
    reg [11:0] ad1_in;
    reg [11:0] ad2_in;

    wire [1:0] mosfet_buck1;
    wire [1:0] mosfet_buck2;
    wire [1:0] mosfet_res1;
    wire [1:0] mosfet_res2;
    wire mosfet_deion;

    wire operation_indicator;
    wire will_single_discharge_indicator;
    wire is_breakdown;
    
    // Instantiate the FPGA Slave
    fpga_slave fpga_slave_inst (
        .clk_in(clk_in),
        .sys_rst_n(sys_rst_n),
        .key_start(key_start),
        .key_stop(key_stop),
        .mosi(mosi),
        .sclk(sclk),
        .cs_n(cs_n),
        .miso(miso),
        .ad1_in(ad1_in),
        .ad2_in(ad2_in),
        .signle_discharge_button(signle_discharge_button),
        .mosfet_buck1(mosfet_buck1),
        .mosfet_buck2(mosfet_buck2),
        .mosfet_res1(mosfet_res1),
        .mosfet_res2(mosfet_res2),
        .mosfet_deion(mosfet_deion),
        .operation_indicator(operation_indicator),
        .will_single_discharge_indicator(will_single_discharge_indicator),
        .is_breakdown(is_breakdown)
    );

    // Clock generation for FPGA
    initial begin
        clk_in = 0;
        forever #10 clk_in = ~clk_in;  // Generates a 50MHz clock (20 ns period)
    end

    // Reset and initial conditions
    initial begin
        sys_rst_n = 0;
        mosi = 0;
        cs_n = 1;
        key_start = 1;
        key_stop = 1;
        signle_discharge_button = 1;
        ad1_in = 12'h000;
        ad2_in = 12'h000;
        
        #1000;
        sys_rst_n = 1;  // Release reset

        // Send SPI Commands
        #1000;  // Wait for system initialization
        spi_transaction(8'h91);  // Ton 100us
        spi_transaction(8'h64);  // 
        spi_transaction(8'h00);  // 

        spi_transaction(8'h9E);  // Toff 50us
        spi_transaction(8'h32);  //
        spi_transaction(8'h00);  //

        /*
        localparam WAVE_RES_CO_DISCHARGE = 16'b1000_0000_0000_0000; // 0x8000
        localparam WAVE_BUCK_CC_RECTANGLE_DISCHARGE = 16'b0010_0000_0000_0001; // 0x2001
        localparam WAVE_BUCK_CC_TRIANGLE_DISCHARGE = 16'b0010_0000_0000_0010; // 0x2002
        localparam WAVE_BUCK_SC_RECTANGLE_DISCHARGE = 16'b0110_0000_0000_0001; // 0x6001
        localparam WAVE_BUCK_SO_RECTANGLE_DISCHARGE = 16'b0100_0000_0000_0001; // 0x4001
        */
        spi_transaction(8'h9C);  // waveform
        spi_transaction(8'h01);  // single test discharge
        spi_transaction(8'h40);  // 
        /*
        spi_transaction(8'h00);  // buck reac discharge
        spi_transaction(8'h01);  // 
        */
        spi_transaction(8'h93);  // Ip 60/2 = 30A
        spi_transaction(8'h3C);   
        spi_transaction(8'h00);  

        spi_transaction(8'h06);  // Machine start command

        // Key
        #1000;
        //key_start = 0;
        signle_discharge_button = 0;
        #1000000; // key press 1ms
        //key_start = 1;
        signle_discharge_button = 1;
        #2000000; // key release 2ms
        signle_discharge_button = 0;
        #1000000; // key press 1ms
        signle_discharge_button = 1;
    end

    // AD input simulation over time
    initial begin
        #5000;
        // deion
        ad1_in = 12'h866 - 12'd80; // 0.1V approximation (5A)
        ad2_in = 12'h8F5 + 12'd94; // 0.24V approximation (120V)
        #1000000; // 1ms + DEAD_TIME
        
        //discharge
        ad1_in = 12'hA64 - 12'd80; // 0.6V (30A)
        ad2_in = 12'h833 + 12'd94; // 0.05V (25V)
        #100000; // 100us
        
        // deion
        ad1_in = 12'h800 - 12'd80; // 0V (0A)
        ad2_in = 12'h800 + 12'd94; // 0V (0V)
        #2899990;
        
        // wait breakdown
        ad1_in = 12'h866 - 12'd80; // 0.1V approximation (5A)
        ad2_in = 12'h8F5 + 12'd94; // 0.24V approximation (120V)
        #50000; // 50us

        //discharge
        ad1_in = 12'hA64 - 12'd80; // 0.6V (30A)
        ad2_in = 12'h833 + 12'd94; // 0.05V (25V)
        #100000; // 100us

    end

    // SPI Protocol Helper Task
    task spi_transaction;
        input [7:0] data;
        integer i;
        begin
            cs_n = 0;
            sclk = 0;
            #100;  // CS setup time
            for (i = 7; i >= 0; i = i - 1) 
            begin
                mosi = data[i];
                #30; sclk = 1;  // Set up to clock on falling edge
                #30; sclk = 0;  // Clock high
            end
            #100;
            cs_n = 1;  // CS hold time
            #100;  // Time between transactions
        end
    endtask

endmodule