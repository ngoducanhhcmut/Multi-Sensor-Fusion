module InterPrediction (
    input  logic clk,
    input  logic signed [8:0] mv_x,       // Motion vector X (8.2 fixed-point)
    input  logic signed [8:0] mv_y,       // Motion vector Y (8.2 fixed-point)
    input  logic [9:0] pos_x, pos_y,      // Vị trí hiện tại
    input  logic [7:0] ref_pixel [0:3][0:3], // Vùng tham chiếu 4x4
    output logic [7:0] predicted_block [0:3][0:3]
);
    function automatic logic [7:0] interpolate(
        input logic [7:0] p00, p01, p10, p11,
        input logic [1:0] frac_x, frac_y
    );
        logic [10:0] a = (4 - frac_x) * (4 - frac_y) * p00;
        logic [10:0] b = frac_x * (4 - frac_y) * p01;
        logic [10:0] c = (4 - frac_x) * frac_y * p10;
        logic [10:0] d = frac_x * frac_y * p11;
        return (a + b + c + d + 8) >> 4;
    endfunction

    always_comb begin
        for (int y = 0; y < 4; y++) begin
            for (int x = 0; x < 4; x++) begin
                logic signed [10:0] base_x = pos_x + x + (mv_x >> 2);
                logic signed [10:0] base_y = pos_y + y + (mv_y >> 2);
                logic [1:0] frac_x = mv_x[1:0];
                logic [1:0] frac_y = mv_y[1:0];
                
                // Giới hạn ranh giới
                logic [1:0] idx_x = (base_x < 0) ? 0 : (base_x > 2) ? 2 : base_x[1:0];
                logic [1:0] idx_y = (base_y < 0) ? 0 : (base_y > 2) ? 2 : base_y[1:0];
                
                predicted_block[y][x] = interpolate(
                    ref_pixel[idx_y][idx_x],
                    ref_pixel[idx_y][idx_x+1],
                    ref_pixel[idx_y+1][idx_x],
                    ref_pixel[idx_y+1][idx_x+1],
                    frac_x, frac_y
                );
            end
        end
    end
endmodule