`timescale 1ns / 1ns

module tb_occ;

reg clk;
reg rst_n;
reg [15:0] sample_current;
reg [15:0] sample_voltage;
reg [15:0] timer_buck_4us_0;
reg [15:0] timer_buck_interleave;
reg [15:0] i_set;
wire [15:0] inductor_charging_time;

// 实例化被测试模块
one_cycle_control one_cycle_control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .sample_current(sample_current),
    .sample_voltage(sample_voltage),
    .timer_buck_4us_0(timer_buck_4us_0),
    .i_set(i_set),
    .inductor_charging_time(inductor_charging_time)
);

// 时钟生成
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz 时钟，周期10ns
end

// 测试序列
initial begin
    rst_n = 0;
    sample_current = 0;
    sample_voltage = 25;  // 电压保持在25
    timer_buck_4us_0 = 0;
    timer_buck_interleave = 0;
    i_set = 60;  // 设定电流为30

    // 重置
    #100;
    rst_n = 1;

    // 模拟 sample_current 上升、保持、下降
    // 上升阶段
    repeat (2) 
    begin
        #4000 sample_current = sample_current + 15;  // 每4us增加15，模拟上升
    end
    // 保持阶段
    repeat (10) 
    begin
        #40000;  // 保持30，每4us一个周期
    end
    // 下降阶段
    repeat (2) 
    begin
        #4000 sample_current = sample_current - 15;  // 每4us减少15，模拟下降
    end

    // 结束测试
    #1000;
    $stop;
end

// Timer buck 4us_0 管理
initial begin
    timer_buck_4us_0 = 0;  // 初始化
    #100;  // 等待100个时钟周期
    while (1) 
    begin
        #10 timer_buck_4us_0 = timer_buck_4us_0 + 1;  // 每个时钟周期加1
        if (timer_buck_4us_0 >= 400)
            timer_buck_4us_0 = 0;  // 计数到400，重置为0
    end
end

// Timer buck interleave 管理
initial begin
    timer_buck_interleave = 0;  // 初始化
    #100;  // 等待100个时钟周期
    while (1) 
    begin
        #10 timer_buck_interleave = timer_buck_interleave + 1;  // 每个时钟周期加1
        if (timer_buck_interleave >= 4000)  // 因为是10个timer_buck_4us_0周期
            timer_buck_interleave = 0;  // 计数到4000，重置为0
    end
end

endmodule