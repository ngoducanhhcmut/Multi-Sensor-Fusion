// Deblocking Filter Module
module deblocking_filter #(
    parameter WIDTH     = 640,
    parameter HEIGHT    = 480,
    parameter N         = 8,    // Block size
    parameter THRESHOLD = 10    // Threshold for filtering
) (
    input  logic [7:0] reconstructed_frame [0:HEIGHT-1][0:WIDTH-1],
    output logic [7:0] filtered_frame [0:HEIGHT-1][0:WIDTH-1],
    input  logic clk,
    input  logic reset_n
);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int y = 0; y < HEIGHT; y++) begin
                for (int x = 0; x < WIDTH; x++) begin
                    filtered_frame[y][x] <= reconstructed_frame[y][x];
                end
            end
        end else begin
            for (int y = 0; y < HEIGHT; y = y + N) begin
                for (int x = 0; x < WIDTH; x = x + N) begin
                    for (int i = 0; i < N; i++) begin
                        for (int j = 0; j < N; j++) begin
                            if (y + i < HEIGHT && x + j < WIDTH) begin
                                logic [7:0] diff;
                                if (j < N-1 && x + j + 1 < WIDTH)
                                    diff = abs(reconstructed_frame[y+i][x+j] - reconstructed_frame[y+i][x+j+1]);
                                else
                                    diff = 0;
                                if (diff < THRESHOLD)
                                    filtered_frame[y+i][x+j] <= (reconstructed_frame[y+i][x+j] + reconstructed_frame[y+i][x+j+1]) >> 1;
                                else
                                    filtered_frame[y+i][x+j] <= reconstructed_frame[y+i][x+j];
                            end
                        end
                    end
                end
            end
        end
    end
endmodule