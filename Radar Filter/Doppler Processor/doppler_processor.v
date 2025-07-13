module doppler_processor #(
    parameter PHASE_OFFSET = 0,    // Vị trí phase trong clean_point
    parameter LUT_DEPTH = 256      // Kích thước LUT
)(
    input  wire         clk,          // Clock
    input  wire         reset,        // Reset
    input  wire         data_valid,   // Tín hiệu valid đầu vào
    input  wire [127:0] clean_point,  // Điểm sạch 128-bit
    output wire [15:0]  velocity,     // Vận tốc (signed)
    output wire         vel_valid     // Tín hiệu valid đầu ra
);

    wire [15:0] phase_diff;  // Độ lệch pha
    wire        diff_valid;  // Tín hiệu valid của phase_diff

    // Module Phase Extractor
    phase_extractor #(.PHASE_OFFSET(PHASE_OFFSET)) u_phase_extractor (
        .clk         (clk),
        .reset       (reset),
        .data_valid  (data_valid),
        .clean_point (clean_point),
        .phase_diff  (phase_diff),
        .diff_valid  (diff_valid)
    );

    // Module Velocity LUT
    velocity_lut #(.LUT_DEPTH(LUT_DEPTH)) u_velocity_lut (
        .clk         (clk),
        .reset       (reset),
        .phase_valid (diff_valid),
        .phase_diff  (phase_diff),
        .velocity    (velocity),
        .vel_valid   (vel_valid)
    );

endmodule