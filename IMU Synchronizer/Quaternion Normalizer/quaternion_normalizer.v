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