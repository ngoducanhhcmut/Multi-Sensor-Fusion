// Top-Level Loop Filters Module
module loop_filters #(
    parameter WIDTH     = 640,
    parameter HEIGHT    = 480,
    parameter N         = 8,
    parameter THRESHOLD = 10,
    parameter OFFSET    = 2,
    parameter NUM_FRAMES = 4
) (
    input  logic [7:0] reconstructed_frame [0:HEIGHT-1][0:WIDTH-1],
    output logic [7:0] reference_frames [0:NUM_FRAMES-1][0:HEIGHT-1][0:WIDTH-1],
    input  logic clk,
    input  logic reset_n,
    input  logic new_frame_ready
);
    // Intermediate signals
    logic [7:0] deblocked_frame [0:HEIGHT-1][0:WIDTH-1];
    logic [7:0] filtered_frame [0:HEIGHT-1][0:WIDTH-1];

    // Instantiate Deblocking Filter
    deblocking_filter #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .N(N),
        .THRESHOLD(THRESHOLD)
    ) deblock (
        .reconstructed_frame(reconstructed_frame),
        .filtered_frame(deblocked_frame),
        .clk(clk),
        .reset_n(reset_n)
    );

    // Instantiate SAO Filter
    sao_filter #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .OFFSET(OFFSET)
    ) sao (
        .deblocked_frame(deblocked_frame),
        .filtered_frame(filtered_frame),
        .clk(clk),
        .reset_n(reset_n)
    );

    // Instantiate Frame Buffer Manager
    frame_buffer_manager #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .NUM_FRAMES(NUM_FRAMES)
    ) fbm (
        .filtered_frame(filtered_frame),
        .reference_frames(reference_frames),
        .clk(clk),
        .reset_n(reset_n),
        .new_frame_ready(new_frame_ready)
    );
endmodule