module camera_decoder #(
    parameter WIDTH           = 640,
    parameter HEIGHT          = 480,
    parameter BLOCK_SIZE      = 8,
    parameter PIXEL_WIDTH     = 8,
    parameter ADDR_WIDTH      = 19,         // log2(640*480) ≈ 19
    parameter NUM_REF_FRAMES  = 4,
    parameter MAX_COEFF_SIZE  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    // Bitstream input
    input  logic [7:0]            bitstream_in,
    input  logic                  bitstream_valid,
    output logic                  bitstream_ready,
    // RGB output
    output logic [PIXEL_WIDTH-1:0] pixel_r,
    output logic [PIXEL_WIDTH-1:0] pixel_g,
    output logic [PIXEL_WIDTH-1:0] pixel_b,
    output logic [9:0]            pixel_x,
    output logic [8:0]            pixel_y,
    output logic                  pixel_valid,
    output logic                  frame_done
);

    // --- Parameters ---
    localparam NUM_BLOCKS_X = WIDTH / BLOCK_SIZE;    // 80 blocks
    localparam NUM_BLOCKS_Y = HEIGHT / BLOCK_SIZE;   // 60 blocks
    localparam TOTAL_BLOCKS = NUM_BLOCKS_X * NUM_BLOCKS_Y; // 4800 blocks
    localparam Y_PLANE_SIZE = WIDTH * HEIGHT;
    localparam UV_PLANE_SIZE = (WIDTH/2) * (HEIGHT/2);

    // --- State Machine ---
    typedef enum logic [3:0] {
        IDLE,
        DECODE_SPS,
        DECODE_PPS,
        DECODE_SLICE_HEADER,
        DECODE_BLOCKS,
        APPLY_LOOP_FILTERS,
        CONVERT_RGB,
        ERROR_STATE
    } state_t;
    state_t state, next_state;

    // --- Control Signals ---
    logic [15:0] block_counter;
    logic [9:0] block_x, block_y;
    logic [9:0] rgb_x, rgb_y;
    logic header_start, header_valid, header_done, header_error;
    logic slice_start, slice_valid, slice_error;
    logic ans_bitstream_valid, ans_ready, ans_data_request, syntax_valid;
    logic inv_quant_start, inv_quant_done;
    logic pred_start, pred_valid, pred_error;
    logic recon_block_valid, recon_done;
    logic new_frame_ready;
    logic yuv_valid_in, rgb_valid_out;

    // --- NAL Parser Signals ---
    logic [7:0] nal_type;
    logic [3071:0] nal_unit;
    logic [9:0] nal_unit_size;
    logic nal_valid, nal_error_overflow;

    // --- Header Decoder Signals ---
    logic [7:0] profile;
    logic [15:0] frame_width, frame_height;
    logic [7:0] fps;
    logic [1:0] chroma_format;
    logic [3:0] bit_depth;
    logic [5:0] base_qp;
    logic tiles_enabled;
    logic [3:0] tile_cols, tile_rows;

    // --- Slice Decoder Signals ---
    logic [1:0] slice_type;
    logic [2:0] num_ref_idx_l0_active_minus1, num_ref_idx_l1_active_minus1;
    logic [5:0] slice_qp_delta;
    logic [3071:0] slice_data;
    logic [3071:0] slice_data_reg;
    logic [11:0] bit_pos;

    // --- ANS Decoder Signals ---
    logic [31:0] ans_bitstream_in;
    logic [15:0] syntax_element;
    logic [7:0] syntax_elements; // For inverse quant

    // --- Inverse Quant & Transform Signals ---
    logic signed [15:0] quantized_coeff_matrix[MAX_COEFF_SIZE][MAX_COEFF_SIZE];
    logic signed [15:0] residual_data[MAX_COEFF_SIZE][MAX_COEFF_SIZE];

    // --- Prediction Signals ---
    logic [7:0] pred_mode, intra_mode;
    logic top_available, left_available;
    logic [7:0] top_pixels[0:BLOCK_SIZE-1];
    logic [7:0] left_pixels[0:BLOCK_SIZE-1];
    logic signed [8:0] mv_x, mv_y;
    logic [9:0] pos_x, pos_y;
    logic [7:0] ref_window[0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [7:0] predicted_block[0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];

    // --- Reconstruction Signals ---
    logic [PIXEL_WIDTH-1:0] recon_block[0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [PIXEL_WIDTH-1:0] mem_data;
    logic mem_we;

    // --- Memory Interface ---
    logic [7:0] current_frame_Y [0:HEIGHT-1][0:WIDTH-1];
    logic [7:0] current_frame_U [0:HEIGHT/2-1][0:WIDTH/2-1];
    logic [7:0] current_frame_V [0:HEIGHT/2-1][0:WIDTH/2-1];
    logic [7:0] filtered_frame_Y [0:HEIGHT-1][0:WIDTH-1];
    logic [7:8] filtered_frame_U [0:HEIGHT/2-1][0:WIDTH/2-1];
    logic [7:0] filtered_frame_V [0:HEIGHT/2-1][0:WIDTH/2-1];
    logic [7:0] dpb_Y [0:NUM_REF_FRAMES-1][0:HEIGHT-1][0:WIDTH-1];
    logic [7:0] dpb_U [0:NUM_REF_FRAMES-1][0:HEIGHT/2-1][0:WIDTH/2-1];
    logic [7:0] dpb_V [0:NUM_REF_FRAMES-1][0:HEIGHT/2-1][0:WIDTH/2-1];

    // --- YUV to RGB Signals ---
    logic [7:0] yuv_Y, yuv_U, yuv_V;
    logic [23:0] rgb_pixel;

    // --- Submodule Instances ---
    NALParser nal_parser (
        .clk(clk),
        .reset(rst),
        .bitstream_data(bitstream_in),
        .bitstream_valid(bitstream_valid),
        .bitstream_ready(bitstream_ready),
        .nal_type(nal_type),
        .nal_unit(nal_unit),
        .nal_unit_size(nal_unit_size),
        .nal_valid(nal_valid),
        .error_overflow(nal_error_overflow)
    );

    header_decoder header_dec (
        .clk(clk),
        .reset(rst),
        .nal_unit(nal_unit),
        .start(header_start),
        .valid(header_valid),
        .done(header_done),
        .error(header_error),
        .profile(profile),
        .width(frame_width),
        .height(frame_height),
        .fps(fps),
        .chroma_format(chroma_format),
        .bit_depth(bit_depth),
        .qp(base_qp),
        .tiles_enabled(tiles_enabled),
        .tile_cols(tile_cols),
        .tile_rows(tile_rows)
    );

    slice_decoder slice_dec (
        .clk(clk),
        .reset(rst),
        .start(slice_start),
        .nal_unit(nal_unit),
        .slice_type(slice_type),
        .num_ref_idx_l0_active_minus1(num_ref_idx_l0_active_minus1),
        .num_ref_idx_l1_active_minus1(num_ref_idx_l1_active_minus1),
        .slice_qp_delta(slice_qp_delta),
        .slice_data(slice_data),
        .valid(slice_valid),
        .error(slice_error)
    );

    ans_decoder ans_dec (
        .clk(clk),
        .rst(rst),
        .bitstream_in(ans_bitstream_in),
        .bitstream_valid(ans_bitstream_valid),
        .context(4'b0), // Giả định context đơn giản
        .syntax_element(syntax_element),
        .syntax_valid(syntax_valid),
        .ready(ans_ready),
        .data_request(ans_data_request)
    );

    inverse_quant_transform inv_quant (
        .clk(clk),
        .reset(rst),
        .start(inv_quant_start),
        .done(inv_quant_done),
        .syntax_elements(syntax_elements),
        .quantized_coeff_matrix(quantized_coeff_matrix),
        .QP(base_qp + slice_qp_delta),
        .residual_data(residual_data)
    );

    // Sửa PredictionModule để hỗ trợ BLOCK_SIZE
    PredictionModule #(
        .BLOCK_SIZE(BLOCK_SIZE)
    ) pred (
        .clk(clk),
        .reset_n(~rst),
        .pred_mode(pred_mode),
        .intra_mode(intra_mode),
        .top_available(top_available),
        .left_available(left_available),
        .top_pixels(top_pixels),
        .left_pixels(left_pixels),
        .mv_x(mv_x),
        .mv_y(mv_y),
        .pos_x(pos_x),
        .pos_y(pos_y),
        .ref_window(ref_window),
        .predicted_block(predicted_block),
        .valid_out(pred_valid),
        .error_flag(pred_error)
    );

    reconstruction_unit recon (
        .clk(clk),
        .reset(rst),
        .block_valid(recon_block_valid),
        .P(predicted_block),
        .R(residual_data[0:BLOCK_SIZE-1][0:BLOCK_SIZE-1]),
        .block_x(block_x),
        .block_y(block_y),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_we(mem_we),
        .done(recon_done)
    );

    loop_filters loop_filters (
        .clk(clk),
        .reset_n(~rst),
        .reconstructed_frame(current_frame_Y),
        .reference_frames(dpb_Y),
        .new_frame_ready(new_frame_ready)
        // Giả định filtered_frame_Y được lưu trong dpb_Y[0]
    );

    hw_accelerated_yuv2rgb rgb_conv (
        .clk(clk),
        .rst_n(~rst),
        .Y(yuv_Y),
        .U(yuv_U),
        .V(yuv_V),
        .valid_in(yuv_valid_in),
        .data_out(rgb_pixel), // Sửa để xuất RGB 24-bit
        .valid_out(rgb_valid_out)
    );

    // --- State Machine Control ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            block_counter <= 0;
            block_x <= 0;
            block_y <= 0;
            rgb_x <= 0;
            rgb_y <= 0;
            slice_data_reg <= 0;
            bit_pos <= 0;
            frame_done <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    block_counter <= 0;
                    block_x <= 0;
                    block_y <= 0;
                    rgb_x <= 0;
                    rgb_y <= 0;
                    frame_done <= 0;
                end
                DECODE_SLICE_HEADER: if (slice_valid) begin
                    slice_data_reg <= slice_data;
                    bit_pos <= 0;
                end
                DECODE_BLOCKS: if (recon_done) begin
                    if (block_x < NUM_BLOCKS_X-1) begin
                        block_x <= block_x + 1;
                    end else begin
                        block_x <= 0;
                        if (block_y < NUM_BLOCKS_Y-1) begin
                            block_y <= block_y + 1;
                        end else begin
                            block_y <= 0;
                        end
                    end
                    block_counter <= block_counter + 1;
                end
                CONVERT_RGB: if (rgb_valid_out) begin
                    if (rgb_x < WIDTH-1) begin
                        rgb_x <= rgb_x + 1;
                    end else begin
                        rgb_x <= 0;
                        if (rgb_y < HEIGHT-1) begin
                            rgb_y <= rgb_y + 1;
                        end else begin
                            rgb_y <= 0;
                            frame_done <= 1;
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        bitstream_ready = 0;
        header_start = 0;
        slice_start = 0;
        ans_bitstream_valid = 0;
        ans_ready = 1;
        inv_quant_start = 0;
        pred_start = 0;
        recon_block_valid = 0;
        new_frame_ready = 0;
        yuv_valid_in = 0;

        case (state)
            IDLE: begin
                bitstream_ready = 1;
                if (nal_valid) begin
                    case (nal_type)
                        8'h42: next_state = DECODE_SPS; // SPS
                        8'h43: next_state = DECODE_PPS; // PPS
                        8'h01: next_state = DECODE_SLICE_HEADER; // Slice
                        default: next_state = ERROR_STATE;
                    endcase
                end
            end
            DECODE_SPS: begin
                header_start = 1;
                if (header_done) begin
                    if (header_error || frame_width != WIDTH || frame_height != HEIGHT) begin
                        next_state = ERROR_STATE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DECODE_PPS: begin
                header_start = 1;
                if (header_done) begin
                    if (header_error) begin
                        next_state = ERROR_STATE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DECODE_SLICE_HEADER: begin
                slice_start = 1;
                if (slice_valid) begin
                    if (slice_error) begin
                        next_state = ERROR_STATE;
                    end else begin
                        next_state = DECODE_BLOCKS;
                    end
                end
            end
            DECODE_BLOCKS: begin
                if (ans_data_request && bit_pos <= 3072-32) begin
                    ans_bitstream_in = slice_data_reg[bit_pos +: 32];
                    ans_bitstream_valid = 1;
                    bit_pos = bit_pos + 32;
                end
                if (syntax_valid) begin
                    inv_quant_start = 1;
                    syntax_elements = syntax_element[7:0]; // Giả định
                end
                if (inv_quant_done) begin
                    pred_start = 1;
                    // Giả định syntax_element cung cấp pred_mode, mv_x, mv_y, v.v.
                    pred_mode = syntax_element[7:0]; // Cần logic phân tích cú pháp
                    pos_x = block_x * BLOCK_SIZE;
                    pos_y = block_y * BLOCK_SIZE;
                    // Cần logic để lấy top_pixels, left_pixels, ref_window từ bộ nhớ
                end
                if (pred_valid) begin
                    recon_block_valid = 1;
                end
                if (recon_done) begin
                    if (block_counter == TOTAL_BLOCKS-1) begin
                        next_state = APPLY_LOOP_FILTERS;
                        new_frame_ready = 1;
                    end
                end
                if (pred_error) begin
                    next_state = ERROR_STATE;
                end
            end
            APPLY_LOOP_FILTERS: begin
                new_frame_ready = 1;
                // Giả định loop_filters hoàn thành trong một chu kỳ
                next_state = CONVERT_RGB;
            end
            CONVERT_RGB: begin
                yuv_valid_in = 1;
                yuv_Y = filtered_frame_Y[rgb_y][rgb_x];
                yuv_U = filtered_frame_U[rgb_y/2][rgb_x/2];
                yuv_V = filtered_frame_V[rgb_y/2][rgb_x/2];
                if (frame_done) begin
                    next_state = IDLE;
                end
            end
            ERROR_STATE: begin
                if (rst) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // --- Memory Write Logic ---
    always_ff @(posedge clk) begin
        if (mem_we) begin
            current_frame_Y[mem_addr / WIDTH][mem_addr % WIDTH] <= mem_data;
            // Giả định U, V được xử lý tương tự
        end
    end

    // --- RGB Output ---
    assign pixel_r = rgb_pixel[23:16];
    assign pixel_g = rgb_pixel[15:8];
    assign pixel_b = rgb_pixel[7:0];
    assign pixel_x = rgb_x;
    assign pixel_y = rgb_y;
    assign pixel_valid = rgb_valid_out;

    // --- Error Handling ---
    always_ff @(posedge clk) begin
        if (nal_error_overflow || header_error || slice_error || pred_error) begin
            next_state <= ERROR_STATE;
        end
    end

endmodule