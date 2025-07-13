module IntraPrediction (
    input  logic [7:0] intra_mode,         // Chế độ dự đoán
    input  logic       top_available,      // Pixel top có sẵn
    input  logic       left_available,     // Pixel left có sẵn
    input  logic [7:0] top_neighbors [0:3], // 4 pixel top
    input  logic [7:0] left_neighbors[0:3], // 4 pixel left
    output logic [7:0] predicted_block [0:3][0:3] // Block 4x4
);
    logic [7:0] default_val = 8'd128;
    
    always_comb begin
        for (int y = 0; y < 4; y++) begin
            for (int x = 0; x < 4; x++) begin
                predicted_block[y][x] = default_val;
            end
        end

        case (intra_mode)
            8'h00: begin // DC Mode
                logic [8:0] sum = 0;
                logic [2:0] count = 0;
                if (top_available) for (int i=0; i<4; i++) begin
                    sum += top_neighbors[i];
                    count++;
                end
                if (left_available) for (int i=0; i<4; i++) begin
                    sum += left_neighbors[i];
                    count++;
                end
                logic [7:0] dc_val = (count > 0) ? sum / count : default_val;
                for (int y=0; y<4; y++) for (int x=0; x<4; x++)
                    predicted_block[y][x] = dc_val;
            end
            8'h01: begin // Planar Mode
                logic [7:0] dc_val;
                if (top_available && left_available) begin
                    for (int y=0; y<4; y++) for (int x=0; x<4; x++) begin
                        logic [8:0] hor = (3-x)*left_neighbors[y] + (x+1)*top_neighbors[3];
                        logic [8:0] ver = (3-y)*top_neighbors[x] + (y+1)*left_neighbors[3];
                        predicted_block[y][x] = (hor + ver + 4) >> 3;
                    end
                end else begin
                    logic [8:0] sum = 0;
                    logic [2:0] count = 0;
                    if (top_available) for (int i=0; i<4; i++) begin
                        sum += top_neighbors[i];
                        count++;
                    end
                    if (left_available) for (int i=0; i<4; i++) begin
                        sum += left_neighbors[i];
                        count++;
                    end
                    dc_val = (count > 0) ? sum / count : default_val;
                    for (int y=0; y<4; y++) for (int x=0; x<4; x++)
                        predicted_block[y][x] = dc_val;
                end
            end
        endcase
    end
endmodule