// Timestamp Interpolator Module
module timestamp_interpolator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [127:0] data_in,
    input  logic        valid_in,
    input  logic [127:0] prev_data,
    input  logic        prev_valid,
    input  logic [63:0] target_time,
    output logic [63:0] data_out,
    output logic        valid_out
);
    typedef struct packed {
        logic signed [15:0] ax, ay, az, gx;
    } imu_data_t;

    imu_data_t curr_d, prev_d, out_d;
    logic [63:0] t1, t2, t_target;
    logic [31:0] ratio;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            data_out <= '0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in && prev_valid) begin
                prev_d = prev_data[127:64];
                curr_d = data_in[127:64];
                t1 = prev_data[63:0];
                t2 = data_in[63:0];
                t_target = target_time;

                if (t2 != t1) begin
                    ratio = ((t_target - t1) << 16) / (t2 - t1);
                    out_d.ax = prev_d.ax + $signed((ratio * (curr_d.ax - prev_d.ax)) >>> 16);
                    out_d.ay = prev_d.ay + $signed((ratio * (curr_d.ay - prev_d.ay)) >>> 16);
                    out_d.az = prev_d.az + $signed((ratio * (curr_d.az - prev_d.az)) >>> 16);
                    out_d.gx = prev_d.gx + $signed((ratio * (curr_d.gx - prev_d.gx)) >>> 16);
                    data_out = out_d;
                    valid_out = 1'b1;
                end
            end
        end
    end
endmodule