module MaxPoolingModule #(
    parameter H = 4,      // Feature map height (phải lớn hơn 0)
    parameter W = 4       // Feature map width (phải lớn hơn 0)
)(
    input  logic [H*W*256-1:0] activation_map_flat, // Input: HxWx32 INT8, thứ tự [Pixel0_Ch0..Ch31][Pixel1_Ch0..Ch31]...
    output logic [255:0]        feature_vector      // Output: 256-bit vector, thứ tự [Ch0][Ch1]...[Ch31]
);
    // Kiểm tra trường hợp biên
    initial begin
        if (H <= 0 || W <= 0) begin
            $fatal("Error: H và W phải lớn hơn 0");
        end
    end

    localparam BIT_WIDTH = 8;      // Độ rộng bit mỗi kênh
    localparam CHANNELS  = 32;     // Số kênh cố định
    localparam PIXEL_BITS = CHANNELS * BIT_WIDTH; // 256 bits mỗi pixel

    // Hàm binary tree reduction để tìm giá trị lớn nhất
    function automatic logic [BIT_WIDTH-1:0] tree_reduce;
        input logic [BIT_WIDTH-1:0] data [H*W];
        logic [BIT_WIDTH-1:0] tree [0:H*W-1][0:$clog2(H*W)];
        
        begin
            // Khởi tạo lá cây
            for (int i = 0; i < H*W; i++) begin
                tree[i][0] = data[i];
            end
            
            // Giảm dần bằng cây nhị phân
            for (int level = 1; level <= $clog2(H*W); level++) begin
                int stride = 1 << (level - 1);
                for (int i = 0; i < (H*W + stride-1)/(2*stride); i++) begin
                    int idx1 = 2*i*stride;
                    int idx2 = (2*i+1)*stride;
                    
                    if (idx2 >= H*W) begin
                        tree[i][level] = tree[idx1][level-1];
                    end else begin
                        tree[i][level] = (tree[idx1][level-1] > tree[idx2][level-1]) 
                                       ? tree[idx1][level-1] 
                                       : tree[idx2][level-1];
                    end
                end
            end
            
            tree_reduce = tree[0][$clog2(H*W)];
        end
    endfunction

    // Xử lý chính
    always_comb begin
        for (int ch = 0; ch < CHANNELS; ch++) begin
            logic [BIT_WIDTH-1:0] channel_data [H*W];
            
            // Trích xuất dữ liệu từng kênh
            for (int h = 0; h < H; h++) begin
                for (int w = 0; w < W; w++) begin
                    int pixel_idx = h*W + w;
                    int bit_offset = (pixel_idx * PIXEL_BITS) + (ch * BIT_WIDTH);
                    channel_data[pixel_idx] = activation_map_flat[bit_offset +: BIT_WIDTH];
                end
            end
            
            // Áp dụng tree reduction để tìm max
            feature_vector[ch*BIT_WIDTH +: BIT_WIDTH] = tree_reduce(channel_data);
        end
    end

endmodule