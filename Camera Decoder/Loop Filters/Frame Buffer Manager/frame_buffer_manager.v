// Frame Buffer Manager Module
module frame_buffer_manager #(
    parameter WIDTH     = 640,
    parameter HEIGHT    = 480,
    parameter NUM_FRAMES = 4    // Number of reference frames
) (
    input  logic [7:0] filtered_frame [0:HEIGHT-1][0:WIDTH-1],
    output logic [7:0] reference_frames [0:NUM_FRAMES-1][0:HEIGHT-1][0:WIDTH-1],
    input  logic clk,
    input  logic reset_n,
    input  logic new_frame_ready
);
    logic [7:0] buffer [0:NUM_FRAMES-1][0:HEIGHT-1][0:WIDTH-1];
    logic [$clog2(NUM_FRAMES)-1:0] write_ptr;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_ptr <= 0;
            for (int i = 0; i < NUM_FRAMES; i++) begin
                for (int y = 0; y < HEIGHT; y++) begin
                    for (int x = 0; x < WIDTH; x++) begin
                        buffer[i][y][x] <= 0;
                    end
                end
            end
        end else if (new_frame_ready) begin
            buffer[write_ptr] <= filtered_frame;
            write_ptr <= (write_ptr + 1) % NUM_FRAMES;  // Circular buffer
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_FRAMES; i++) begin
            reference_frames[i] = buffer[i];
        end
    end
endmodule