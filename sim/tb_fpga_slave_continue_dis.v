`timescale 1ns / 1ps

module tb_fpga_slave_continue_dis;

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
        spi_transaction(8'h20);  // 
        /*
        spi_transaction(8'h00);  // buck reac discharge
        spi_transaction(8'h01);  // 
        */
        spi_transaction(8'h93);  // Ip 60
        spi_transaction(8'h50);   
        spi_transaction(8'h00);  

        spi_transaction(8'h06);  // Machine start command
    end

    // AD input simulation over time
    initial begin
        #100000;
        // wait breakdown
        ad_in(5, 120, 10000); // 5A, 120V, 10us
        //discharge
        ad_in(30, 25, 100000); // 5A, 120V, 100us
        // deion
        ad_in(0, 0, 50000); // 0A, 0V, 50us

        // wait breakdown
        ad_in(5, 120, 10000); // 5A, 120V, 10us
        //discharge
        ad_in(30, 25, 100000); // 5A, 120V, 100us
        // deion
        ad_in(0, 0, 50000); // 0A, 0V, 50us

        //discharge
        ad_in(30, 25, 100000);
        // deion
        ad_in(0, 0, 50000); // 0A, 0V, 50us

        // //short
        // ad_in(95, 5, 100000);
        // // deion
        // ad_in(0, 0, 50000);
        spi_transaction(8'hAB);  // get feedback 360ns
        spi_transaction(8'hFF);
        spi_transaction(8'hFF);
        spi_transaction(8'hFF);
        spi_transaction(8'hFF);



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
            // cs_n = 1;  // CS hold time
            #100;  // Time between transactions
        end
    endtask

    // ADC IN Helper Task
    task ad_in;
        input signed [15:0] current;
        input signed [15:0] voltage;
        input integer duration;
        begin
            ad1_in = 12'h800 + (current * 1024 / 50) - 12'd80;
            ad2_in = 12'h800 + (voltage * 1024 / 500) + 12'd94;
            #duration;
        end
    endtask

endmodule