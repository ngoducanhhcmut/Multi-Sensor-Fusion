// Top-level module: Point Cloud Assembler (Improved)
module point_cloud_assembler (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] x,          // 32-bit x coordinate
    input  logic [31:0] y,          // 32-bit y coordinate
    input  logic [31:0] z,          // 32-bit z coordinate
    input  logic [7:0]  R,          // 8-bit red
    input  logic [7:0]  G,          // 8-bit green
    input  logic [7:0]  B,          // 8-bit blue
    input  logic [7:0]  intensity,  // 8-bit intensity
    input  logic        valid_in,   // Input valid signal
    output logic [511:0] encrypted_data, // Encrypted 512-bit output
    output logic         output_valid    // Output valid signal
);

    // Internal signals
    logic [127:0] point;          // 128-bit formatted point
    logic         point_valid;    // Point Formatter output valid
    logic [511:0] buffer_next;    // Next buffer value
    logic         write_full;     // Buffer full signal
    logic [511:0] packed_data;    // Packed 512-bit data
    logic         packed_valid;   // Packed data valid

    // Instantiate sub-modules
    point_formatter pf (
        .x(x),
        .y(y),
        .z(z),
        .R(R),
        .G(G),
        .B(B),
        .intensity(intensity),
        .valid_in(valid_in),
        .point(point),
        .valid_out(point_valid)
    );

    buffer_writer bw (
        .clk(clk),
        .reset(reset),
        .point(point),
        .valid_in(point_valid),
        .buffer_next(buffer_next),
        .write_full(write_full)
    );

    output_packer op (
        .clk(clk),
        .reset(reset),
        .buffer_next(buffer_next),
        .write_full(write_full),
        .packed_data(packed_data),
        .packed_valid(packed_valid)
    );

    data_encryption_module dem (
        .clk(clk),
        .reset(reset),
        .point_cloud(packed_data),
        .valid_in(packed_valid),
        .encrypted_data(encrypted_data),
        .valid_out(output_valid)
    );

endmodule