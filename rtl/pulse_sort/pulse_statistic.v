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
	.short_pulse_rate(),
    .interval_pulse_rate()
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

    output reg [5:0] normal_pulse_rate,
    output reg [5:0] arc_pulse_rate,
    output reg [6:0] open_pulse_rate,
	output reg [5:0] short_pulse_rate,
    output reg [6:0] interval_pulse_rate
);

// pulse state define
localparam NORMAL_DIS = 0; 
localparam OPEN_DIS = 1; 
localparam SHORT_DIS = 2;
localparam INTERVAL = 3;

// pulse type record
reg [2:0] current_pulse_type;
reg [15:0] open_dis_state_count;
reg [2:0] last_pulse_type;

// pulse count
reg [31:0] normal_pulse_count;
reg [31:0] arc_pulse_count;
reg [31:0] open_pulse_count;
reg [31:0] short_pulse_count;
reg [31:0] interval_pulse_count;
reg [31:0] total_count;

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
            open_dis_state_count <= open_dis_state_count + 1'b1;
        else
            open_dis_state_count <= 16'd0;
    end
end

always@(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0)
    begin
        normal_pulse_count <= 32'd0;
        arc_pulse_count <= 32'd0;
        open_pulse_count <= 32'd0;
        short_pulse_count <= 32'd0;
        interval_pulse_count <= 32'd0;

        total_count <= 32'd0;
    end 
    else if (feedback_finished == 1'b1)
    begin
        normal_pulse_count <= 32'd0;
        arc_pulse_count <= 32'd0;
        open_pulse_count <= 32'd0;
        short_pulse_count <= 32'd0;
        interval_pulse_count <= 32'd0;

        total_count <= 32'd0;
    end
    else if (is_machine == 1'b1)
    case (current_pulse_type)
        NORMAL_DIS: 
        begin
            if ( open_dis_state_count < NORMAL_DISCHARGE_DELAY )
            begin
                arc_pulse_count <= arc_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
            else
            begin
                normal_pulse_count <= normal_pulse_count + 32'd1;
                total_count <= total_count + 32'd1;
            end
        end
        OPEN_DIS:
        begin
            open_pulse_count <= open_pulse_count + 32'd1;
            total_count <= total_count + 32'd1;
        end
        SHORT_DIS: 
        begin
            short_pulse_count <= short_pulse_count + 32'd1;
            total_count <= total_count + 32'd1;
        end
        INTERVAL: 
        begin
            interval_pulse_count <= interval_pulse_count + 32'd1;
            total_count <= total_count + 32'd1;
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
wire [31:0] interval_pulse_rate_temp;

always@(posedge clk)
begin
    if (normal_pulse_rate_temp > 6'b111111)
        normal_pulse_rate <= 6'b111111;
    else
        normal_pulse_rate <= normal_pulse_rate_temp;
end
always@(posedge clk)
begin
    if (arc_pulse_rate_temp > 6'b111111)
        arc_pulse_rate <= 6'b111111;
    else
        arc_pulse_rate <= arc_pulse_rate_temp;
end
always@(posedge clk)
begin
    if (open_pulse_rate_temp > 7'b1111111)
        open_pulse_rate <= 7'b1111111;
    else
        open_pulse_rate <= open_pulse_rate_temp;
end
always@(posedge clk)
begin
    if (short_pulse_rate_temp > 6'b111111)
        short_pulse_rate <= 6'b111111;
    else
        short_pulse_rate <= short_pulse_rate_temp;
end
always@(posedge clk)
begin
    if (interval_pulse_rate_temp > 7'b1111111)
        interval_pulse_rate <= 7'b1111111;
    else
        interval_pulse_rate <= interval_pulse_rate_temp;
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
divider_32d32	divider_32d32_interval_pulse_rate
(
    .aclr ( feedback_finished ),
	.clock ( clk ),
	.denom ( total_count ),
	.numer ( scaled_interval_pulse_count ),
	.quotient ( interval_pulse_rate_temp ),
	.remain (  )
);

endmodule