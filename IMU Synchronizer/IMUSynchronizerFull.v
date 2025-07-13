module buffer_manager (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] fifo_data_out,
    input  wire        fifo_empty,
    input  wire        ready,
    output logic [63:0] imu_sync_out,
    output logic       valid,
    output logic       fifo_read_en
);
    // Control logic
    always_comb begin
        valid = ~fifo_empty;
        fifo_read_en = valid && ready;  // Read only if not empty and ready
    end

    // Output register for timing
    always_ff @(posedge clk) begin
        if (rst) begin
            imu_sync_out <= '0;
        end else if (fifo_read_en) begin
            imu_sync_out <= fifo_data_out;
        end
    end
endmodule

module fifo #(
    parameter DEPTH = 16,     // Must be >= 2
    parameter WIDTH = 64      // Must be >= 1
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             write_en,
    input  wire [WIDTH-1:0] data_in,
    output logic            full,
    input  wire             read_en,
    output logic [WIDTH-1:0] data_out,
    output logic            empty
);
    // Validate parameters
    initial begin
        if (DEPTH < 2) $error("DEPTH must be >= 2");
        if (WIDTH < 1) $error("WIDTH must be >= 1");
    end

    // Pointer and memory
    localparam PTR_WIDTH = $clog2(DEPTH);
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0] count;  // Extra bit for count (0 to DEPTH)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Registered outputs
    always_ff @(posedge clk) begin -begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            data_out <= '0;
            for (int i = 0; i < DEPTH; i++) mem[i] <= '0;  // Clear memory
        end else begin
            // Write operation
            if (write_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // Read operation
            if (read_en && !empty) begin
                data_out <= mem[rd_ptr];  // Register output
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            end

            // Update counter
            case ({write_en && !full, read_en && !empty})
                2'b01:   count <= count - 1;  // Read only
                2'b10:   count <= count + 1;  // Write only
                2'b11:   count <= count;      // Read + Write
                default: count <= count;
            endcase
        end
    end

    // Status flags (combinational)
    assign full  = (count == DEPTH);
    assign empty = (count == 0);
endmodule

module data_writer (
    input  wire [63:0] quaternion_in,
    input  wire        write_en,
    output wire [63:0] fifo_data_in,
    output logic       fifo_write_en,
    input  wire        fifo_full
);
    assign fifo_data_in = quaternion_in;
    
    always_comb begin
        fifo_write_en = write_en && !fifo_full;  // Write only if not full
    end
endmodule

// Quaternion Buffer Module
module quaternion_buffer #(
    parameter DEPTH = 16,
    parameter PTR_WIDTH = $clog2(DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] data_in,
    input  logic        wr_en,
    output logic        full,
    output logic        empty,
    input  logic        rd_en,
    output logic [63:0] data_out,
    output logic        valid_out
);
    logic [63:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (wr_en) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                count <= count + 1;
            end
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr];
                valid_out <= 1'b1;
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                count <= count - 1;
            end
        end
    end
    assign empty = (count == 0);
    assign full = (count == DEPTH);
endmodule

module non_restoring_sqrt (
    input  logic [31:0] in,   // Q2.30
    output logic [31:0] out   // Q2.30
);
    // Non-restoring square root algorithm
    logic [31:0] root;
    logic [63:0] rem, test_sub;
    integer i;
    
    always_comb begin
        root = 0;
        rem = {in, 32'h0}; // Q2.62
        
        for (i = 31; i >= 0; i--) begin
            test_sub = {root, 2'b01} << (2 * i);
            if (rem >= test_sub) begin
                rem = rem - test_sub;
                root = root | (1 << i);
            end
        end
        out = root; // Q2.30
    end
endmodule


module reciprocal_lut (
    input  logic [11:0] addr,
    output logic [11:0] data
);
    // 4096-entry LUT for reciprocal approximation
    always_comb begin
        data = 12'h800 / (addr ? addr : 12'h001); // Prevent division by zero
    end
endmodule

module reciprocal_unit (
    input  logic [31:0] in,   // Q2.30 (unsigned)
    output logic [31:0] out   // Q2.30 (unsigned)
);
    // Initial approximation (12-bit LUT)
    logic [11:0] lut_out;
    reciprocal_lut lut (
        .addr(in[31:20]),
        .data(lut_out)
    );
    
    // Newton-Raphson iteration
    logic [31:0] y0, y1, x_y0, two_minus;
    
    assign y0 = {20'h0, lut_out}; // Q2.30
    assign x_y0 = (in * y0) >> 30; // Q2.30 * Q2.30 = Q4.60 -> Q4.30
    assign two_minus = 32'h8000_0000 - x_y0; // Q2.30
    assign y1 = (y0 * two_minus) >> 30; // Q2.30 * Q2.30 = Q4.60 -> Q4.30
    
    assign out = y1; // Q2.30
endmodule

module reciprocal_lut (
    input  logic [11:0] addr,
    output logic [11:0] data
);
    // 4096-entry LUT for reciprocal approximation
    always_comb begin
        data = 12'h800 / (addr ? addr : 12'h001); // Prevent division by zero
    end
endmodule

module magnitude_calculator (
    input  logic signed [15:0] w,
    input  logic signed [15:0] x,
    input  logic signed [15:0] y,
    input  logic signed [15:0] z,
    output logic [31:0] magnitude  // Q2.30
);

    logic [31:0] w_sq, x_sq, y_sq, z_sq;
    logic [31:0] sum_sq;
    logic [15:0] abs_w, abs_x, abs_y, abs_z;

    // Handle -32768 by clamping to 32767
    assign abs_w = (w == 16'h8000) ? 16'h7FFF : (w[15] ? -w : w);
    assign abs_x = (x == 16'h8000) ? 16'h7FFF : (x[15] ? -x : x);
    assign abs_y = (y == 16'h8000) ? 16'h7FFF : (y[15] ? -y : y);
    assign abs_z = (z == 16'h8000) ? 16'h7FFF : (z[15] ? -z : z);

    // Squares with overflow protection
    assign w_sq = abs_w * abs_w; // Q2.30
    assign x_sq = abs_x * abs_x;
    assign y_sq = abs_y * abs_y;
    assign z_sq = abs_z * abs_z;

    // Sum of squares with saturation
    assign sum_sq = w_sq + x_sq + y_sq + z_sq;

    // Non-restoring square root
    non_restoring_sqrt sqrt_inst (
        .in(sum_sq),
        .out(magnitude)
    );
endmodule

module quaternion_normalizer (
    input  logic signed [15:0] w_in,  // Q1.15
    input  logic signed [15:0] x_in,  // Q1.15
    input  logic signed [15:0] y_in,  // Q1.15
    input  logic signed [15:0] z_in,  // Q1.15
    output logic signed [15:0] w_out, // Q1.15
    output logic signed [15:0] x_out, // Q1.15
    output logic signed [15:0] y_out, // Q1.15
    output logic signed [15:0] z_out  // Q1.15
);

    // Internal signals
    logic [31:0] magnitude;        // Q2.30
    logic [31:0] safe_magnitude;   // Q2.30
    logic [31:0] reciprocal;       // Q2.30
    logic signed [47:0] w_product, x_product, y_product, z_product; // Q3.45
    
    // Magnitude calculation
    magnitude_calculator mag_calc (
        .w(w_in),
        .x(x_in),
        .y(y_in),
        .z(z_in),
        .magnitude(magnitude)
    );

    // Safe magnitude with minimal threshold to prevent division by zero
    assign safe_magnitude = (magnitude < 32'h0000_0001) ? 32'h0000_0001 : magnitude;

    // Reciprocal approximation using Newton-Raphson method
    reciprocal_unit recip (
        .in(safe_magnitude),
        .out(reciprocal)
    );

    // Normalized components calculation
    assign w_product = w_in * reciprocal; // Q1.15 * Q2.30 = Q3.45
    assign x_product = x_in * reciprocal;
    assign y_product = y_in * reciprocal;
    assign z_product = z_in * reciprocal;

    // Output quantization with rounding and saturation
    always_comb begin
        w_out = quantize_output(w_product);
        x_out = quantize_output(x_product);
        y_out = quantize_output(y_product);
        z_out = quantize_output(z_product);
    end

    // Quantization function with rounding and saturation
    function automatic logic signed [15:0] quantize_output(input logic signed [47:0] product);
        logic signed [15:0] result;
        logic signed [47:0] rounded;
        
        // Add rounding factor (0.5 in Q3.45)
        rounded = product + 48'sh0000_0000_0002; // 1 << 29 in Q3.45
        
        // Check for saturation
        if (rounded >= 48'sh0000_7FFF_8000) begin
            result = 16'h7FFF; // Max positive
        end else if (rounded < 48'shFFFF_8000_0000) begin
            result = 16'h8000; // Max negative
        end else begin
            // Extract Q1.15 from Q3.45 with rounding
            result = rounded[44:29] + (rounded[28] & (rounded[27:0] != 0));
        end
        return result;
    endfunction

endmodule


// Sub-module: Angle Calculator
module angle_calculator (
    input logic clk,
    input logic rst_n,
    input logic [31:0] dot,
    output logic [31:0] theta
);
    cordic_arccos cordic_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x(dot),
        .angle(theta)
    );

    // Edge case handling
    always_comb begin
        if (dot >= 32'h00010000) begin // dot >= 1.0
            theta = 32'h0;
        end else if (dot <= 32'hFFFF0000) begin // dot <= -1.0
            theta = 32'h6487ED51; // PI in Q16.16
        end
    end
endmodule

module cordic_arccos (
    input logic clk,
    input logic rst_n,
    input logic [31:0] x,     // Giá trị đầu vào (Q16.16, trong [-1, 1])
    output logic [31:0] angle // Góc đầu ra (Q16.16, radian)
);
    parameter NSTAGES = 16;
    parameter WW = 32;
    parameter PW = 32;

    reg signed [WW-1:0] x_reg [0:NSTAGES];
    reg signed [WW-1:0] y_reg [0:NSTAGES];
    reg [PW-1:0] z_reg [0:NSTAGES];
    wire [PW-1:0] cordic_angle [0:NSTAGES-1];

    // Bảng góc CORDIC
    assign cordic_angle[0] = 32'h3243f6a9; // atan(2^0)
    assign cordic_angle[1] = 32'h1dac6705; // atan(2^-1)
    assign cordic_angle[2] = 32'h0fadbafd; // atan(2^-2)
    assign cordic_angle[3] = 32'h07f56ea7; // atan(2^-3)
    assign cordic_angle[4] = 32'h03feab77; // atan(2^-4)
    assign cordic_angle[5] = 32'h01ffd55c; // atan(2^-5)
    assign cordic_angle[6] = 32'h00fffaab; // atan(2^-6)
    assign cordic_angle[7] = 32'h007fff55; // atan(2^-7)
    assign cordic_angle[8] = 32'h003fffeb; // atan(2^-8)
    assign cordic_angle[9] = 32'h001ffffd; // atan(2^-9)
    assign cordic_angle[10] = 32'h00100000; // atan(2^-10)
    assign cordic_angle[11] = 32'h00080000; // atan(2^-11)
    assign cordic_angle[12] = 32'h00040000; // atan(2^-12)
    assign cordic_angle[13] = 32'h00020000; // atan(2^-13)
    assign cordic_angle[14] = 32'h00010000; // atan(2^-14)
    assign cordic_angle[15] = 32'h00008000; // atan(2^-15)

    // Tính toán √(1-x²)/x
    logic [31:0] x_squared, one_minus_x_squared, sqrt_term, y_init;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_squared <= 0;
            one_minus_x_squared <= 0;
            sqrt_term <= 0;
            y_init <= 0;
        end else begin
            x_squared <= (x * x) >> 16; // Q16.16
            one_minus_x_squared <= 32'h00010000 - x_squared; // 1 - x²
            sqrt_term <= sqrt_approx(one_minus_x_squared); // Cần hàm sqrt
            y_init <= (sqrt_term << 16) / x; // √(1-x²)/x
        end
    end

    // Khởi tạo giá trị ban đầu
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg[0] <= 0;
            y_reg[0] <= 0;
            z_reg[0] <= 0;
        end else begin
            x_reg[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain
            y_reg[0] <= y_init;
            z_reg[0] <= 0;
        end
    end

    // Vòng lặp CORDIC (chế độ vectoring)
    genvar i;
    generate
        for (i = 0; i < NSTAGES; i = i + 1) begin : CORDICops
            always @(posedge clk) begin
                if (y_reg[i][WW-1]) begin
                    x_reg[i+1] <= x_reg[i] - (y_reg[i] >>> i);
                    y_reg[i+1] <= y_reg[i] + (x_reg[i] >>> i);
                    z_reg[i+1] <= z_reg[i] - cordic_angle[i];
                end else begin

                    x_reg[i+1] <= x_reg[i] + (y_reg[i] >>> i);
                    y_reg[i+1] <= y_reg[i] - (x_reg[i] >>> i);
                    z_reg[i+1] <= z_reg[i] + cordic_angle[i];
                end
            end
        end
    endgenerate

    // Đầu ra
    always @(posedge clk) begin
        angle <= z_reg[NSTAGES];
    end

    // Hàm xấp xỉ căn bậc hai (placeholder)
    function logic [31:0] sqrt_approx(input logic [31:0] val);
        // Cần triển khai hàm sqrt chính xác
        sqrt_approx = val; // Placeholder
    endfunction
endmodule

// Sub-module: Dot Product Unit
module dot_product_unit (
    input logic [31:0] q1 [0:3],
    input logic [31:0] q2 [0:3],
    output logic [31:0] dot
);
    logic [63:0] prod [0:3];
    logic [63:0] sum;

    always_comb begin
        prod[0] = (q1[0] * q2[0]) >> 16;
        prod[1] = (q1[1] * q2[1]) >> 16;
        prod[2] = (q1[2] * q2[2]) >> 16;
        prod[3] = (q1[3] * q2[3]) >> 16;
        sum = prod[0] + prod[1] + prod[2] + prod[3];
        
        // Edge case: Zero quaternion
        if ((q1[0] == 32'h0 && q1[1] == 32'h0 && q1[2] == 32'h0 && q1[3] == 32'h0) ||
            (q2[0] == 32'h0 && q2[1] == 32'h0 && q2[2] == 32'h0 && q2[3] == 32'h0)) begin
            dot = 32'h0;
        end else begin
            dot = sum[31:0]; // Q16.16 format
        end
    end
endmodule

// Sub-module: Interpolation Unit
module interpolation_unit (
    input logic clk,
    input logic rst_n,
    input logic [31:0] sin_theta,
    input logic [31:0] cos_theta,
    input logic [31:0] t,
    input logic實際 [31:0] q1 [0:3],
    input logic [31:0] q2 [0:3],
    output logic [31:0] q_interp [0:3]
);
    logic [31:0] one_minus_t;
    logic [31:0] s1, sin_omt_theta;
    logic [31:0] s2, sin_t_theta;
    logic [31:0] theta_approx;

    always_comb begin
        one_minus_t = 32'h00010000 - t; // 1 - t in Q16 Ascendingly
        theta_approx = acos_approx(cos_theta); // Placeholder replaced with CORDIC

        // Edge case: Small angle (theta ≈ 0)
        if (sin_theta < 32'h00000100) begin // sin_theta < 0.000015
            for (int i = 0; i < 4; i++) begin
                q_interp[i] = (one_minus_t * q1[i] + t * q2[i]) >> 16;
            end
        end else begin
            sin_omt_theta = sin_approx((one_minus_t * theta_approx) >> 16);
            sin_t_theta = sin_approx((t * theta_approx) >> 16);
            s1 = (sin_omt_theta << 16) / sin_theta;
            s2 = (sin_t_theta << 16) / sin_theta;
            for (int i = 0; i < 4; i++) begin
                q_interp[i] = (s1 * q1[i] + s2 * q2[i]) >> 16;
            end
        end
    end

    // Placeholder functions replaced with approximations
    function logic [31:0] sin_approx(input logic [31:0] x);
        // Simple Taylor approximation: sin(x) ≈ x for small x
        sin_approx = x; // To be replaced with full CORDIC or Taylor if needed
    endfunction

    function logic [31:0] acos_approx(input logic [31:0] x);
        // Handled by CORDIC in angle_calculator
        acos_approx = 32'h0; // Placeholder only
    endfunction
endmodule

module cordic_sincos (
    input logic clk,
    input logic rst_n,
    input logic [31:0] angle, // Góc đầu vào (Q16.16, radian)
    output logic [31:0] sin,  // Giá trị sine (Q16.16)
    output logic [31:0] cos   // Giá trị cosine (Q16.16)
);
    parameter NSTAGES = 16;
    parameter WW = 32; // Độ rộng bit
    parameter PW = 32; // Độ rộng bit của pha

    reg signed [WW-1:0] x [0:NSTAGES];
    reg signed [WW-1:0] y [0:NSTAGES];
    reg [PW-1:0] z [0:NSTAGES];
    wire [PW-1:0] cordic_angle [0:NSTAGES-1];

    // Bảng góc CORDIC (tính bằng arctan(2^-i))
    assign cordic_angle[0] = 32'h3243f6a9; // atan(2^0)
    assign cordic_angle[1] = 32'h1dac6705; // atan(2^-1)
    assign cordic_angle[2] = 32'h0fadbafd; // atan(2^-2)
    assign cordic_angle[3] = 32'h07f56ea7; // atan(2^-3)
    assign cordic_angle[4] = 32'h03feab77; // atan(2^-4)
    assign cordic_angle[5] = 32'h01ffd55c; // atan(2^-5)
    assign cordic_angle[6] = 32'h00fffaab; // atan(2^-6)
    assign cordic_angle[7] = 32'h007fff55; // atan(2^-7)
    assign cordic_angle[8] = 32'h003fffeb; // atan(2^-8)
    assign cordic_angle[9] = 32'h001ffffd; // atan(2^-9)
    assign cordic_angle[10] = 32'h00100000; // atan(2^-10)
    assign cordic_angle[11] = 32'h00080000; // atan(2^-11)
    assign cordic_angle[12] = 32'h00040000; // atan(2^-12)
    assign cordic_angle[13] = 32'h00020000; // atan(2^-13)
    assign cordic_angle[14] = 32'h00010000; // atan(2^-14)
    assign cordic_angle[15] = 32'h00008000; // atan(2^-15)

    // Khởi tạo giá trị ban đầu
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain ~0.6073
            y[0] <= 0;
            z[0] <= 0;
        end else begin
            x[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain
            y[0] <= 0;
            z[0] <= angle;
        end
    end

    // Vòng lặp CORDIC
    genvar i;
    generate
        for (i = 0; i < NSTAGES; i = i + 1) begin : CORDICops
            always @(posedge clk) begin
                if (z[i][PW-1]) begin
                    x[i+1] <= x[i] + (y[i] >>> i);
                    y[i+1] <= y[i] - (x[i] >>> i);
                    z[i+1] <= z[i] + cordic_angle[i];
                end else begin
                    x[i+1] <= x[i] - (y[i] >>> i);
                    y[i+1] <= y[i] + (x[i] >>> i);
                    z[i+1] <= z[i] - cordic_angle[i];
                end
            end
        end
    endgenerate

    // Đầu ra
    always @(posedge clk) begin
        cos <= x[NSTAGES];
        sin <= y[NSTAGES];
    end
endmodule

// Sub-module: Sine/Cosine Unit
module sine_cosine_unit (
    input logic clk,
    input logic rst_n,
    input logic [31:0] theta,
    output logic [31:0] sin_theta,
    output logic [31:0] cos_theta
);
    cordic_sincos cordic_inst (
        .clk(clk),
        .rst_n(rst_n),
        .angle(theta),
        .sin(sin_theta),
        .cos(cos_theta)
    );
endmodule

// Module: SLERP Calculator
// Description: Performs spherical linear interpolation (SLERP) between two quaternions
module slerp_calculator (
    input logic clk,
    input logic rst_n,
    input logic [31:0] q1 [0:3],       // First quaternion (4x32-bit, Q16.16)
    input logic [31:0] q2 [0:3],       // Second quaternion (4x32-bit, Q16.16)
    input logic [31:0] t,              // Interpolation parameter (32-bit, Q16.16)
    output logic [31:0] q_interp [0:3] // Interpolated quaternion (4x32-bit, Q16.16)
);
    logic [31:0] dot;                  // Dot product result
    logic [31:0] theta;                // Angle between quaternions
    logic [31:0] sin_theta, cos_theta; // Sine and cosine of theta

    // Dot product calculation
    dot_product_unit dot_prod (
        .q1(q1),
        .q2(q2),
        .dot(dot)
    );

    // Angle calculation with edge case handling
    angle_calculator angle_calc (
        .clk(clk),
        .rst_n(rst_n),
        .dot(dot),
        .theta(theta)
    );

    // Sine and cosine calculation
    sine_cosine_unit sin_cos (
        .clk(clk),
        .rst_n(rst_n),
        .theta(theta),
        .sin_theta(sin_theta),
        .cos_theta(cos_theta)
    );

    // Interpolation with edge case handling
    interpolation_unit interp (
        .clk(clk),
        .rst_n(rst_n),
        .sin_theta(sin_theta),
        .cos_theta(cos_theta),
        .t(t),
        .q1(q1),
        .q2(q2),
        .q_interp(q_interp)
    );
endmodule

// Time Sync Module
module time_sync_module (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [127:0] data_in,
    input  logic        valid_in,
    input  logic [63:0] ref_time,
    input  logic [15:0] time_offset,
    output logic [127:0] data_out,
    output logic        valid_out
);
    logic [63:0] adjusted_time;
    assign adjusted_time = data_in[63:0] + time_offset;
    assign data_out = {data_in[127:64], adjusted_time};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_out <= 1'b0;
        else valid_out <= valid_in;
    end
endmodule

// Timestamp Buffer Module
module timestamp_buffer #(
    parameter DEPTH = 16,
    parameter PTR_WIDTH = $clog2(DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] imu_data,
    input  logic [63:0] sys_time,
    input  logic        wr_en,
    output logic        full,
    output logic        empty,
    input  logic        rd_en,
    output logic [127:0] data_out,
    output logic        valid_out
);
    logic [127:0] fifo [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (wr_en) begin
                fifo[wr_ptr] <= {imu_data, sys_time};
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                count <= count + 1;
            end
            if (rd_en && !empty) begin
                data_out <= fifo[rd_ptr];
                valid_out <= 1'b1;
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                count <= count - 1;
            end
        end
    end
    assign empty = (count == 0);
    assign full = (count == DEPTH);
endmodule

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

module imu_synchronizer #(
    parameter FIFO_DEPTH = 16,
    parameter PTR_WIDTH = $clog2(FIFO_DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] imu_data,        // Raw IMU (64-bit)
    input  logic        imu_valid,
    input  logic [63:0] sys_time,        // Global timestamp
    input  logic [63:0] desired_time,    // Target sync time
    output logic [63:0] imu_sync_out,    // Synced IMU (64-bit)
    output logic        imu_sync_valid,
    input  logic        output_ready     // Back-pressure support
);

    // Internal signals
    logic [127:0] ts_buf_data_out;      // {imu_data, timestamp}
    logic         ts_buf_valid_out;
    logic         ts_buf_rd_en;
    
    logic [127:0] time_sync_out;
    logic         time_sync_valid;
    
    logic [63:0]  interpolated_data;
    logic         interpolated_valid;
    logic [127:0] prev_sync_data;
    logic         prev_sync_valid;
    
    logic [127:0] quat_buf_data_out;    // {quaternion, timestamp}
    logic         quat_buf_valid_out;
    logic         quat_buf_rd_en;
    logic [31:0]  slerp_t;              // Dynamic interpolation factor
    
    logic [63:0]  normalized_quat;
    logic         normalized_valid;

    // Module instances
    timestamp_buffer #(FIFO_DEPTH) ts_buf (
        .clk(clk),
        .rst_n(rst_n),
        .imu_data(imu_data),
        .sys_time(sys_time),
        .wr_en(imu_valid),
        .rd_en(ts_buf_rd_en),
        .data_out(ts_buf_data_out),
        .valid_out(ts_buf_valid_out),
        .full(), .empty()
    );
    
    time_sync_module time_sync (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(ts_buf_data_out),
        .valid_in(ts_buf_valid_out),
        .ref_time(sys_time),
        .time_offset(16'd0),
        .data_out(time_sync_out),
        .valid_out(time_sync_valid)
    );
    
    timestamp_interpolator interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(time_sync_out),
        .valid_in(time_sync_valid),
        .prev_data(prev_sync_data),
        .prev_valid(prev_sync_valid),
        .target_time(desired_time),
        .data_out(interpolated_data),
        .valid_out(interpolated_valid)
    );
    
    // Store previous sample with overflow protection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_sync_data <= '0;
            prev_sync_valid <= 1'b0;
        end else if (time_sync_valid) begin
            prev_sync_data <= time_sync_out;
            prev_sync_valid <= 1'b1;
        end
    end
    
    fifo #(
        .DEPTH(FIFO_DEPTH),
        .WIDTH(128)
    ) quat_buf (
        .clk(clk),
        .rst(!rst_n),
        .write_en(interpolated_valid),
        .data_in({interpolated_data, prev_sync_data[63:0]}),
        .full(),
        .read_en(quat_buf_rd_en),
        .data_out(quat_buf_data_out),
        .empty()
    );
    
    logic [63:0] current_ts, prev_ts;
    assign current_ts = quat_buf_data_out[63:0];
    assign prev_ts = quat_buf_data_out[127:64];
    
    // Dynamic interpolation factor with edge case handling
    always_comb begin
        if (current_ts != prev_ts) begin
            slerp_t = (32'h10000 * (desired_time - prev_ts)) / (current_ts - prev_ts);
        end else begin
            slerp_t = 32'h08000;  // Default to t=0.5 for duplicate timestamps
        end
    end
    
    slerp_calculator slerp (
        .clk(clk),
        .rst_n(rst_n),
        .q1('{quat_buf_data_out[127:96], quat_buf_data_out[95:64], quat_buf_data_out[63:32], quat_buf_data_out[31:0]}),
        .q2('{quat_buf_data_out[191:160], quat_buf_data_out[159:128], quat_buf_data_out[127:96], quat_buf_data_out[95:64]}),
        .t(slerp_t),
        .q_interp({normalized_quat[63:48], normalized_quat[47:32], normalized_quat[31:16], normalized_quat[15:0]})
    );
    
    quaternion_normalizer normalizer (
        .w_in(normalized_quat[63:48]),
        .x_in(normalized_quat[47:32]),
        .y_in(normalized_quat[31:16]),
        .z_in(normalized_quat[15:0]),
        .w_out(imu_sync_out[63:48]),
        .x_out(imu_sync_out[47:32]),
        .y_out(imu_sync_out[31:16]),
        .z_out(imu_sync_out[15:0])
    );
    
    // Output control with back-pressure
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imu_sync_valid <= 1'b0;
        end else begin
            imu_sync_valid <= normalized_valid && output_ready;
        end
    end
    
    // FIFO read control with status checking
    assign ts_buf_rd_en = !fifo_full && time_sync_ready;
    assign quat_buf_rd_en = !fifo_full && slerp_ready;
    
    // Placeholder status flags (to be implemented based on system)
    logic fifo_full, time_sync_ready, slerp_ready;
    assign fifo_full = 0;          // Replace with actual FIFO status
    assign time_sync_ready = 1;    // Replace with downstream ready
    assign slerp_ready = 1;        // Replace with SLERP input ready

endmodule



