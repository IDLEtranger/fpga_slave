`timescale 1ns / 1ps

module tb_pulse_statistic;

    // Parameters
    parameter V_OPEN = 60;
    parameter V_SHORT = 5;
    parameter I_DISCHARGE = 10;
    parameter NORMAL_DISCHARGE_DELAY = 10;

    // Inputs
    reg clk;
    reg rst_n;
    reg signed [15:0] sample_current;
    reg signed [15:0] sample_voltage;
    reg is_machine;
    reg feedback_finished;

    // Outputs
    wire [7:0] normal_pulse_rate;
    wire [7:0] arc_pulse_rate;
    wire [7:0] open_pulse_rate;
    wire [7:0] short_pulse_rate;

    // Instantiate the Unit Under Test (UUT)
    pulse_statistic #(
        .V_OPEN(V_OPEN),
        .V_SHORT(V_SHORT),
        .I_DISCHARGE(I_DISCHARGE),
        .NORMAL_DISCHARGE_DELAY(NORMAL_DISCHARGE_DELAY)
    ) uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .sample_current(sample_current), 
        .sample_voltage(sample_voltage), 
        .is_machine(is_machine),
        .feedback_finished(feedback_finished),
        .normal_pulse_rate(normal_pulse_rate),
        .arc_pulse_rate(arc_pulse_rate),
        .open_pulse_rate(open_pulse_rate),
        .short_pulse_rate(short_pulse_rate)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz Clock
    end

    // Stimulus: Apply test vectors
    initial begin
        // Initialize inputs
        rst_n = 0;
        sample_current = 0;
        sample_voltage = 0;
        is_machine = 1;
        feedback_finished = 0;

        // Reset the system
        #100;
        rst_n = 1;
        
        // Test 1: Normal pulse
        apply_pulse(0, 0, 50000);
        apply_pulse(3, 120, 100000);
        apply_pulse(30, 25, 100000);
        apply_pulse(0, 0, 50000);

        // Test 2: Arc pulse
        apply_pulse(0, 0, 100000);
        apply_pulse(30, 20, 100000);
        apply_pulse(0, 0, 50000);

        // Test 3: Open pulse
        apply_pulse(0, 0, 50000);
        apply_pulse(3, 120, 100000);
        apply_pulse(0, 0, 50000);

        // Test 4: Short pulse
        apply_pulse(0, 0, 50000);
        apply_pulse(50, 3, 100000);
        apply_pulse(0, 0, 50000);

        // Test 5: Interval pulse
        apply_pulse(0, 0, 100000);
    end

    // Task to apply pulse
    task apply_pulse;
        input signed [15:0] current;
        input signed [15:0] voltage;
        input integer duration;
        begin
            sample_current = current;
            sample_voltage = voltage;
            #(duration);
        end
    endtask

endmodule
