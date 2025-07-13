// SAO Filter Module
module sao_filter #(
    parameter WIDTH     = 640,
    parameter HEIGHT    = 480,
    parameter OFFSET    = 2     // Fixed offset for simplicity
) (
    input  logic [7:0] deblocked_frame [0:HEIGHT-1][0:WIDTH-1],
    output logic [7:0] filtered_frame [0:HEIGHT-1][0:WIDTH-1],
    input  logic clk,
    input  logic reset_n
);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int y = 0; y < HEIGHT; y++) begin
                for (int x = 0; x < WIDTH; x++) begin
                    filtered_frame[y][x] <= deblocked_frame[y][x];
                end
            end
        end else begin
            for (int y = 0; y < HEIGHT; y++) begin
                for (int x = 0; x < WIDTH; x++) begin
                    // Band offset: Apply offset to a specific intensity range
                    logic [7:0] pixel = deblocked_frame[y][x];
                    if (pixel >= 100 && pixel <= 150) begin
                        if (pixel + OFFSET <= 255)  // Handle overflow
                            filtered_frame[y][x] <= pixel + OFFSET;
                        else
                            filtered_frame[y][x] <= 255;
                    end else begin
                        filtered_frame[y][x] <= pixel;
                    end
                end
            end
        end
    end
endmodule