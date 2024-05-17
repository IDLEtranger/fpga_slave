`timescale 1ns / 1ps

module tb_i_set_generation;

    // Inputs
    reg clk;
    reg rst_n;
    reg [15:0] waveform;
    reg [15:0] Ton_timer;
    reg [15:0] Ip;
    reg [15:0] timer_buck_interleave;

    // Outputs
    wire [15:0] i_set;

    // 实例化被测试模块
    i_set_generation i_set_generation_inst (
        .clk(clk),
        .rst_n(rst_n),
        .waveform(waveform),
        .Ton_timer(Ton_timer),
        .Ip(Ip),
        .timer_buck_interleave(timer_buck_interleave),
        .i_set(i_set)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 100 MHz
    end

    // 测试用例
    initial begin
        // 初始化输入
        rst_n = 0;
        waveform = 0;
        Ton_timer = 4000;
        Ip = 100;  // 假设Ip为100
        timer_buck_interleave = 0;

        // 重置过程
        #100;
        rst_n = 1;
        #30;

        // 测试 RECTANGLE WAVE
        waveform = 16'h0002; // RECTANGLE WAVE
        repeat (4000) begin
            timer_buck_interleave = timer_buck_interleave + 1;
            #20;
        end
        #50;

        // 测试 TRIANGLE WAVE
        waveform = 16'h0004; // TRIANGLE WAVE
        timer_buck_interleave = 0;
        repeat (4000) begin
            timer_buck_interleave = timer_buck_interleave + 1;
            #20;
        end
        #50;

        // 测试无波形
        waveform = 16'h8000;
        timer_buck_interleave = 0;
        repeat (4000) begin
            timer_buck_interleave = timer_buck_interleave + 1;
            #20;
        end
        #50;
        
        $finish;
    end

endmodule