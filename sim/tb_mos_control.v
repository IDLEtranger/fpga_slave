`timescale 1ns / 1ps

module tb_mos_control;

    // Inputs to the module
    reg clk;
    reg rst_n;
    reg is_machine_start;
    reg [15:0] waveform;
    reg [15:0] Ip;
    reg [15:0] Ton;
    reg [15:0] Toff;
    reg signed [16:0] sample_current;
    reg signed [16:0] sample_voltage;
    reg [15:0] timer_buck_interleave;

    // Outputs from the module
    wire [1:0] mosfet_buck1;
    wire [1:0] mosfet_buck2;
    wire [1:0] mosfet_res1;
    wire [1:0] mosfet_res2;
    wire mosfet_deion;

    // Instantiate the Unit Under Test (UUT)
    mos_control #(
        .DEAD_TIME(16'd10),
        .WAIT_BREAKDOWN_MAXTIME(16'd5000),
        .WAIT_BREAKDOWN_MINTIME(16'd50),
        .MAX_CURRENT_LIMIT(16'd60),
        .CURRENT_FALL_THRESHOLD(16'd5),
        .BREAKDOWN_THRESHOLD_CUR(16'd10),
        .BREAKDOWN_THRESHOLD_VOL(12'd30)
    ) mos_control_inst (
        .clk(clk),
        .rst_n(rst_n),
        .is_machine_start(is_machine_start),
        .waveform(waveform),
        .Ip(Ip),
        .Ton(Ton),
        .Toff(Toff),
        .sample_current(sample_current),
        .sample_voltage(sample_voltage),
        .mosfet_buck1(mosfet_buck1),
        .mosfet_buck2(mosfet_buck2),
        .mosfet_res1(mosfet_res1),
        .mosfet_res2(mosfet_res2),
        .mosfet_deion(mosfet_deion)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock, 10 ns period
    end

    // Test stimulus
    initial begin
        // Initialize Inputs
        rst_n = 0;
        is_machine_start = 0;
        waveform = 16'h0001;  // Buck rectangle discharge
        Ip = 100;
        Ton = 30;
        Toff = 20;
        sample_current = 5;
        sample_voltage = 120;
        timer_buck_interleave = 0;

        // Reset pulse
        #100;
        rst_n = 1;
        is_machine_start = 1;
        #10;

        // Simulate current and voltage behavior during breakdown
        #5000;
        sample_current = 30; // Transition to breakdown current
        sample_voltage = 20; // Voltage during breakdown
        #30000;
        sample_current = 0;  // Post breakdown current falls to 0
        sample_voltage = 0;  // Voltage falls to 0 post deion

        #10000;
        $finish;
    end

endmodule