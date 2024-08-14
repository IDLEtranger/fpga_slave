/*
    pulse classification
    U & I
    if (U < v_open)
        if (U > v_short)
            if (I > i_discharge)
                    pulse_type = NORMAL_DIS;
            else
                    pulse_type = OPEN_DIS;
        else 
            if (I > i_discharge)
                    pulse_type = SHORT_DIS;
            else
                    pulse_type = INTERVAL;
    else
        pulse_type = OPEN_DIS;
*/

/*

module pulse_statistic
#(
    .V_OPEN(60),  // sample_voltage higher than V_OPEN means no load
    .V_SHORT(5),  // sample_voltage lower than V_SHORT means short circuit
    .I_DISCHARGE(5), // sample_current higher than I_DISCHARGE means discharge
    .NORMAL_DISCHARGE_DELAY(10) // in normal discharge, before breakdown, it has a short delay time in no load state.
)
( 
    .clk(),
    .rst_n(),

    .sample_current(),
    .sample_voltage(),

    .is_machine(),

    .feedback_finished(),

    .normal_pulse_rate(),
    .arc_pulse_rate(),
    .open_pulse_rate(),
	.short_pulse_rate()
);

*/

module pulse_statistic
#(
    // threshold define
    parameter signed [15:0] V_OPEN = 60,  // sample_voltage higher than V_OPEN means no load
    parameter signed [15:0] V_SHORT = 5,  // sample_voltage lower than V_SHORT means short circuit
    parameter signed [15:0] I_DISCHARGE = 5, // sample_current higher than I_DISCHARGE means discharge
    parameter NORMAL_DISCHARGE_DELAY = 10 // in normal discharge, before breakdown, it has a short delay time in no load state.
)
( 
    input clk,
    input rst_n,

    input wire signed [15:0] sample_current,
    input wire signed [15:0] sample_voltage,

    input wire is_machine,

    input wire feedback_finished,

    output reg [7:0] normal_pulse_rate,
    output reg [7:0] arc_pulse_rate,
    output reg [7:0] open_pulse_rate,
	output reg [7:0] short_pulse_rate
);

// pulse state define
localparam NORMAL_DIS = 3'd0;
localparam ARC_DIS = 3'd1;
localparam OPEN_DIS = 3'd2; 
localparam SHORT_DIS = 3'd3;
localparam INTERVAL = 3'd4;

// pulse type record
reg [2:0] current_pulse_type;
reg [2:0] last_pulse_type;
reg [15:0] open_dis_state_count;

// pulse count
reg [31:0] normal_pulse_count;
reg [31:0] arc_pulse_count;
reg [31:0] open_pulse_count;
reg [31:0] short_pulse_count;
reg [31:0] interval_pulse_count;
reg [31:0] total_count;

// pulse count overflow
reg is_overflow;

always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) 
    begin
        current_pulse_type = INTERVAL;
    end 
    else 
    begin
        last_pulse_type <= current_pulse_type;
        if (sample_voltage < V_OPEN) 
        begin
            if (sample_voltage > V_SHORT) 
            begin
                if (sample_current > I_DISCHARGE) 
                begin
                    if (open_dis_state_count < NORMAL_DISCHARGE_DELAY)
                        if (last_pulse_type == NORMAL_DIS)
                            current_pulse_type = NORMAL_DIS;
                        else
                            current_pulse_type = ARC_DIS;
                    else
                        current_pulse_type = NORMAL_DIS;
                end 
                else 
                begin
                    current_pulse_type = OPEN_DIS;
                end
            end 
            else 
            begin
                if (sample_current > I_DISCHARGE) 
                begin
                    current_pulse_type = SHORT_DIS;
                end 
                else 
                begin
                    current_pulse_type = INTERVAL;
                end
            end
        end 
        else 
            current_pulse_type = OPEN_DIS;
    end
end

always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0)
        open_dis_state_count <= 16'd0;
    else
    begin
        if (current_pulse_type == OPEN_DIS) 
            if (open_dis_state_count == 16'hFFFF)
                open_dis_state_count <= 16'hFFFF;
            else
                open_dis_state_count <= open_dis_state_count + 1'b1;
        else
            open_dis_state_count <= 16'd0;
    end
end

always@(posedge clk or negedge rst_n or posedge feedback_finished) 
begin
    if (rst_n == 1'b0)
    begin
        normal_pulse_count <= 32'd0;
        arc_pulse_count <= 32'd0;
        open_pulse_count <= 32'd0;
        short_pulse_count <= 32'd0;
        interval_pulse_count <= 32'd0;

        total_count <= 32'd0;
        is_overflow <= 1'b0;
    end 
    else if (feedback_finished == 1'b1)
    begin
        normal_pulse_count <= 32'd0;
        arc_pulse_count <= 32'd0;
        open_pulse_count <= 32'd0;
        short_pulse_count <= 32'd0;
        interval_pulse_count <= 32'd0;

        total_count <= 32'd0;

        is_overflow <= 1'b0;
    end
    else
    case (current_pulse_type)
        NORMAL_DIS: 
        begin
            if (normal_pulse_count == 32'hFFFFFFFF)
                is_overflow <= 1'b1;
            else
            begin
                normal_pulse_count <= normal_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
        ARC_DIS:
        begin
            if (arc_pulse_count == 32'hFFFFFFFF)
                is_overflow <= 1'b1;
            else
            begin
                arc_pulse_count <= arc_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
        OPEN_DIS:
        begin
            if (open_pulse_count == 32'hFFFFFFFF)
                is_overflow <= 1'b1;
            else
            begin
                open_pulse_count <= open_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
        SHORT_DIS: 
        begin
            if (short_pulse_count == 32'hFFFFFFFF)
                is_overflow <= 1'b1;
            else
            begin
                short_pulse_count <= short_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
        INTERVAL: 
        begin
            if (interval_pulse_count == 32'hFFFFFFFF)
                is_overflow <= 1'b1;
            else
            begin
                interval_pulse_count <= interval_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
    endcase
end

wire [31:0] scaled_normal_pulse_count;
assign scaled_normal_pulse_count = normal_pulse_count * 32'd100;
wire [31:0] scaled_arc_pulse_count;
assign scaled_arc_pulse_count = arc_pulse_count * 32'd100;
wire [31:0] scaled_open_pulse_count;
assign scaled_open_pulse_count = open_pulse_count * 32'd100;
wire [31:0] scaled_short_pulse_count;
assign scaled_short_pulse_count = short_pulse_count * 32'd100;
wire [31:0] scaled_interval_pulse_count;
assign scaled_interval_pulse_count = interval_pulse_count * 32'd100;

wire [31:0] normal_pulse_rate_temp;
wire [31:0] arc_pulse_rate_temp;
wire [31:0] open_pulse_rate_temp;
wire [31:0] short_pulse_rate_temp;

always@(posedge clk)
begin
    if (normal_pulse_rate_temp > 8'h64 || is_overflow == 1'b1)
        normal_pulse_rate <= 8'hFF;
    else
        normal_pulse_rate <= normal_pulse_rate_temp[7:0];
end
always@(posedge clk)
begin
    if (arc_pulse_rate_temp > 8'h64 || is_overflow == 1'b1)
        arc_pulse_rate <= 8'hFF;
    else
        arc_pulse_rate <= arc_pulse_rate_temp[7:0];
end
always@(posedge clk)
begin
    if (open_pulse_rate_temp > 8'h64 || is_overflow == 1'b1)
        open_pulse_rate <= 8'hFF;
    else
        open_pulse_rate <= open_pulse_rate_temp[7:0];
end
always@(posedge clk)
begin
    if (short_pulse_rate_temp > 8'h64 || is_overflow == 1'b1)
        short_pulse_rate <= 8'hFF;
    else
        short_pulse_rate <= short_pulse_rate_temp[7:0];
end

divider_32d32	divider_32d32_normal_pulse_rate
(
    .aclr ( feedback_finished ),
	.clock ( clk ),
	.denom ( total_count ),
	.numer ( scaled_normal_pulse_count ),
	.quotient ( normal_pulse_rate_temp ),
	.remain (  )
);
divider_32d32	divider_32d32_arc_pulse_rate
(
    .aclr ( feedback_finished ),
	.clock ( clk ),
	.denom ( total_count ),
	.numer ( scaled_arc_pulse_count ),
	.quotient ( arc_pulse_rate_temp ),
	.remain (  )
);
divider_32d32	divider_32d32_open_pulse_rate
(
    .aclr ( feedback_finished ),
	.clock ( clk ),
	.denom ( total_count ),
	.numer ( scaled_open_pulse_count ),
	.quotient ( open_pulse_rate_temp ),
	.remain (  )
);
divider_32d32	divider_32d32_short_pulse_rate
(
    .aclr ( feedback_finished ),
	.clock ( clk ),
	.denom ( total_count ),
	.numer ( scaled_short_pulse_count ),
	.quotient ( short_pulse_rate_temp ),
	.remain (  )
);

endmodule