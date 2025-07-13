// Module 1: Probability Lookup
// Chức năng: Cung cấp xác suất ký hiệu dựa trên ngữ cảnh
module probability_lookup #(
    parameter CONTEXT_WIDTH = 4,
    parameter PROB_WIDTH = 8,
    parameter NUM_SYMBOLS = 16,
    parameter NUM_CONTEXTS = 16
) (
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0]
);

    logic [PROB_WIDTH-1:0] prob_table [NUM_CONTEXTS-1:0][NUM_SYMBOLS-1:0];
    logic [CONTEXT_WIDTH-1:0] safe_context;

    // Xử lý ngữ cảnh vượt quá giới hạn
    assign safe_context = (context < NUM_CONTEXTS) ? context : 0;

    always_comb begin
        for (int i = 0; i < NUM_SYMBOLS; i++) begin
            prob_distribution[i] = prob_table[safe_context][i];
        end
    end

    // Khởi tạo bảng xác suất (ví dụ minh họa)
    initial begin
        for (int ctx = 0; ctx < NUM_CONTEXTS; ctx++) begin
            for (int sym = 0; sym < NUM_SYMBOLS; sym++) begin
                prob_table[ctx][sym] = ctx * 16 + sym;
            end
        end
    end
endmodule


// Module 3: Range Calculator
// Chức năng: Quản lý phạm vi giải mã ANS và xử lý dữ liệu slice mã hóa
module range_calculator #(
    parameter BITSTREAM_WIDTH = 32,
    parameter STATE_WIDTH = 32
) (
    input logic clk,
    input logic rst,
    input logic [BITSTREAM_WIDTH-1:0] bitstream_in,
    input logic bitstream_valid,
    output logic [STATE_WIDTH-1:0] state,
    output logic state_valid,
    input logic state_update,
    input logic [STATE_WIDTH-1:0] next_state
);

    // FIFO cho dữ liệu bitstream (kích thước 4)
    logic [BITSTREAM_WIDTH-1:0] bit_fifo [3:0];
    logic [1:0] fifo_head, fifo_tail;
    logic fifo_empty, fifo_full;
    logic [2:0] fifo_count;

    // Thanh ghi trạng thái
    logic [STATE_WIDTH-1:0] current_state;
    logic state_need_renorm;

    // Ngưỡng renormalization
    localparam RENORM_THRESH = 32'h1000;

    // Logic điều khiển FIFO
    always_ff @(posedge clk) begin
        if (rst) begin
            fifo_head <= 2'b0;
            fifo_tail <= 2'b0;
            fifo_count <= 3'b0;
        end else begin
            if (bitstream_valid && !fifo_full) begin
                bit_fifo[fifo_tail] <= bitstream_in;
                fifo_tail <= fifo_tail + 1;
                fifo_count <= fifo_count + 1;
            end
            if (state_update && state_need_renorm && !fifo_empty) begin
                fifo_head <= fifo_head + 1;
                fifo_count <= fifo_count - 1;
            end
        end
    end

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full = (fifo_count == 4);

    // Logic cập nhật trạng thái
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= RENORM_THRESH;
            state_valid <= 1'b1;
        end else if (state_update) begin
            state_need_renorm <= (next_state < RENORM_THRESH);
            if (!state_need_renorm) begin
                current_state <= next_state;
                state_valid <= 1'b1;
            end else if (!fifo_empty) begin
                current_state <= {next_state[STATE_WIDTH-BITSTREAM_WIDTH-1:0], bit_fifo[fifo_head]};
                state_valid <= 1'b1;
            end else begin
                current_state <= current_state;
                state_valid <= 1'b0;
            end
        end
    end

    assign state = current_state;
endmodule

// Module 4: Symbol Decoder
// Chức năng: Giải mã ký hiệu từ luồng bit sử dụng ANS
module symbol_decoder #(
    parameter STATE_WIDTH = 32,
    parameter PROB_WIDTH = 8,
    parameter SYMBOL_WIDTH = 4,
    parameter NUM_SYMBOLS = 16,
    parameter TABLE_SIZE = 256
) (
    input logic clk,
    input logic rst,
    input logic [STATE_WIDTH-1:0] current_state,
    input logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0],
    output logic [SYMBOL_WIDTH-1:0] symbol,
    output logic [STATE_WIDTH-1:0] next_state,
    output logic symbol_valid,
    
    // Giao diện nạp bảng
    input logic table_write,
    input logic [7:0] table_addr,
    input logic [SYMBOL_WIDTH-1:0] table_symbol,
    input logic [STATE_WIDTH-1:0] table_state
);

    // Bảng giải mã có thể nạp
    logic [SYMBOL_WIDTH-1:0] decode_table [TABLE_SIZE-1:0];
    logic [STATE_WIDTH-1:0] state_table [TABLE_SIZE-1:0];
    
    // Thanh ghi an toàn cho trạng thái
    logic [STATE_WIDTH-1:0] safe_state;

    // Xử lý trạng thái không hợp lệ
    assign safe_state = (current_state >= (1 << (STATE_WIDTH-1))) ? 
                       current_state : 
                       (1 << (STATE_WIDTH-1));

    // Truy xuất bảng
    assign symbol = decode_table[safe_state[7:0]];
    assign next_state = state_table[safe_state[7:0]];
    assign symbol_valid = (safe_state != 0);

    // Cơ chế nạp bảng
    always_ff @(posedge clk) begin
        if (table_write) begin
            decode_table[table_addr] <= table_symbol;
            state_table[table_addr] <= table_state;
        end
    end

    // Khởi tạo mặc định (cho mô phỏng)
    initial begin
        for (int i = 0; i < TABLE_SIZE; i++) begin
            decode_table[i] = i % NUM_SYMBOLS;
            state_table[i] = (i + 1) << 12;
        end
    end
endmodule


// Module 2: Symbol Mapper Lookup
// Chức năng: Ánh xạ ký hiệu đã giải mã thành phần tử cú pháp (QP, motion vector, ...)
module symbol_mapper_lookup #(
    parameter SYMBOL_WIDTH = 4,
    parameter CONTEXT_WIDTH = 4,
    parameter SYNTAX_WIDTH = 16
) (
    input logic [SYMBOL_WIDTH-1:0] symbol,
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [SYNTAX_WIDTH-1:0] syntax_element
);

    always_comb begin
        // Xử lý ngữ cảnh không xác định
        if (context >= 16) begin
            syntax_element = '0;
        end else begin
            case (context)
                4'd0: syntax_element = symbol;                   // QP
                4'd1: syntax_element = symbol << 2;              // Motion vector
                4'd2: syntax_element = symbol == 0;              // Binary flag
                4'd3: syntax_element = {8'd0, symbol, 4'd0};    // Custom format
                default: syntax_element = '1;                    // Safe default
            endcase
        end
    end
endmodule


// Module 5: ANS Decoder (Top-Level)
// Chức năng: Kết hợp các module con để giải mã ANS
module ans_decoder #(
    parameter BITSTREAM_WIDTH = 32,
    parameter STATE_WIDTH = 32,
    parameter CONTEXT_WIDTH = 4,
    parameter PROB_WIDTH = 8,
    parameter SYMBOL_WIDTH = 4,
    parameter SYNTAX_WIDTH = 16,
    parameter NUM_SYMBOLS = 16
) (
    input logic clk,
    input logic rst,
    input logic [BITSTREAM_WIDTH-1:0] bitstream_in,
    input logic bitstream_valid,
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [SYNTAX_WIDTH-1:0] syntax_element,
    output logic syntax_valid,
    
    // Tín hiệu điều khiển luồng
    input logic ready,
    output logic data_request
);

    // Tín hiệu nội bộ
    logic [STATE_WIDTH-1:0] current_state, next_state;
    logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0];
    logic [SYMBOL_WIDTH-1:0] symbol;
    logic state_valid, symbol_valid;

    // Pipeline register
    logic [SYMBOL_WIDTH-1:0] symbol_reg;
    logic [CONTEXT_WIDTH-1:0] context_reg;
    logic symbol_valid_reg;

    // Kiểm soát luồng dữ liệu
    assign data_request = (state_valid && ready);

    // Pipeline stage
    always_ff @(posedge clk) begin
        if (rst) begin
            symbol_reg <= 0;
            context_reg <= 0;
            symbol_valid_reg <= 0;
        end else if (ready) begin
            symbol_reg <= symbol;
            context_reg <= context;
            symbol_valid_reg <= symbol_valid && state_valid;
        end
    end

    // Instantiate modules
    probability_lookup prob_lookup (.*);
    
    range_calculator range_calc (
        .clk(clk),
        .rst(rst),
        .bitstream_in(bitstream_in),
        .bitstream_valid(bitstream_valid && data_request),
        .state(current_state),
        .state_valid(state_valid),
        .state_update(symbol_valid && ready),
        .next_state(next_state)
    );
    
    symbol_decoder sym_decoder (
        .clk(clk),
        .rst(rst),
        .current_state(current_state),
        .prob_distribution(prob_distribution),
        .symbol(symbol),
        .next_state(next_state),
        .symbol_valid(symbol_valid)
    );
    
    symbol_mapper_lookup sym_mapper (
        .symbol(symbol_reg),
        .context(context_reg),
        .syntax_element(syntax_element)
    );

    // Đầu ra hợp lệ
    assign syntax_valid = symbol_valid_reg && ready;
endmodule

module bitstream_reader #(
    parameter BITSTREAM_WIDTH = 3072
) (
    input  logic                        clk,
    input  logic                        reset,
    input  logic [BITSTREAM_WIDTH-1:0]  bitstream,
    input  logic                        start,
    input  logic                        cmd,        // 0: u(n), 1: ue(v)
    input  logic [4:0]                  n,          // Bits to read (1-32)
    output logic [31:0]                 read_value,
    output logic                        done,
    output logic                        busy,
    output logic                        error
);
    typedef enum logic [1:0] {IDLE, COUNT_ZEROS, READ_BITS} state_t;
    state_t state;

    logic [11:0] bit_pos;
    logic [5:0]  leading_zeros;
    logic [31:0] temp_value;
    logic        cmd_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            bit_pos       <= 0;
            read_value    <= 0;
            done          <= 0;
            error         <= 0;
            busy          <= 0;
            leading_zeros <= 0;
            temp_value    <= 0;
            cmd_reg       <= 0;
        end else begin
            done <= 0;
            error <= 0;

            case (state)
                IDLE: begin
                    busy <= 0;
                    if (start) begin
                        busy <= 1;
                        cmd_reg <= cmd;
                        if (cmd == 0) begin // u(n)
                            if (n == 0 || n > 32) begin
                                error <= 1;
                                done <= 1;
                            end else if (bit_pos + n > BITSTREAM_WIDTH) begin
                                error <= 1;
                                done <= 1;
                            end else begin
                                read_value <= bitstream[bit_pos +: n];
                                bit_pos <= bit_pos + n;
                                done <= 1;
                            end
                        end else begin // ue(v)
                            state <= COUNT_ZEROS;
                            leading_zeros <= 0;
                        end
                    end
                end
                COUNT_ZEROS: begin
                    if (bit_pos >= BITSTREAM_WIDTH) begin
                        error <= 1;
                        done <= 1;
                        state <= IDLE;
                    end else if (bitstream[bit_pos] == 0) begin
                        leading_zeros <= leading_zeros + 1;
                        bit_pos <= bit_pos + 1;
                    end else begin
                        bit_pos <= bit_pos + 1;
                        if (leading_zeros == 0) begin
                            read_value <= 0;
                            done <= 1;
                            state <= IDLE;
                        end else begin
                            state <= READ_BITS;
                        end
                    end
                end
                READ_BITS: begin
                    if (leading_zeros > 32 || bit_pos + leading_zeros > BITSTREAM_WIDTH) begin
                        error <= 1;
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        temp_value <= bitstream[bit_pos +: leading_zeros];
                        bit_pos <= bit_pos + leading_zeros;
                        read_value <= (1 << leading_zeros) - 1 + temp_value;
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule

module parameter_validator (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  profile,
    input  logic [15:0] width,
    input  logic [15:0] height,
    input  logic [7:0]  fps,
    input  logic [1:0]  chroma_format,
    input  logic [3:0]  bit_depth,
    input  logic [5:0]  qp,
    input  logic        tiles_enabled,
    input  logic [3:0]  tile_cols,
    input  logic [3:0]  tile_rows,
    output logic        valid,
    output logic        done
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid <= 0;
            done <= 0;
        end else begin
            valid <= 0;
            done <= 0;
            // Kiểm tra profile (hỗ trợ Main và Main10)
            if (profile != 1 && profile != 2) begin
                valid <= 0;
            end
            // Kiểm tra width và height chia hết cho 16
            else if (width % 16 != 0 || height % 16 != 0) begin
                valid <= 0;
            end
            // Kiểm tra QP
            else if (qp > 51) begin
                valid <= 0;
            end
            // Kiểm tra chroma_format (chỉ hỗ trợ 4:2:0)
            else if (chroma_format != 1) begin
                valid <= 0;
            end
            // Kiểm tra bit_depth (8 hoặc 10)
            else if (bit_depth != 8 && bit_depth != 10) begin
                valid <= 0;
            end
            // Kiểm tra FPS
            else if (fps == 0) begin
                valid <= 0;
            end
            // Kiểm tra tiles
            else if (tiles_enabled && (tile_cols == 0 || tile_rows == 0)) begin
                valid <= 0;
            end
            else begin
                valid <= 1;
            end
            done <= 1;
        end
    end
endmodule


module pps_decoder (
    input  logic        clk,
    input  logic        reset,
    input  logic [3071:0] pps_bitstream,
    output logic [5:0]  qp,
    output logic        tiles_enabled,
    output logic [3:0]  tile_cols,
    output logic [3:0]  tile_rows,
    output logic        done,
    output logic        error
);
    logic        start, br_cmd, br_done, br_error, br_busy;
    logic [4:0]  br_n;
    logic [31:0] br_value;

    bitstream_reader br (
        .clk(clk), .reset(reset), .bitstream(pps_bitstream),
        .start(start), .cmd(br_cmd), .n(br_n),
        .read_value(br_value), .done(br_done), .busy(br_busy), .error(br_error)
    );

    typedef enum logic [2:0] {
        P_IDLE, P_QP, P_TILES, P_TILE_COLS, P_TILE_ROWS, P_DONE
    } state_t;
    state_t state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= P_IDLE;
            start <= 0;
            qp <= 0;
            tiles_enabled <= 0;
            tile_cols <= 0;
            tile_rows <= 0;
            done <= 0;
            error <= 0;
        end else begin
            start <= 0;

            case (state)
                P_IDLE: begin
                    if (!br_busy) begin
                        start <= 1;
                        br_cmd <= 0; // u(6) for qp
                        br_n <= 6;
                        state <= P_QP;
                    end
                end
                P_QP: if (br_done) begin
                    if (br_error || br_value > 51) goto_error();
                    else begin
                        qp <= br_value[5:0];
                        start <= 1;
                        br_cmd <= 0; // u(1) for tiles_enabled
                        br_n <= 1;
                        state <= P_TILES;
                    end
                end
                P_TILES: if (br_done) begin
                    if (br_error) goto_error();
                    else begin
                        tiles_enabled <= br_value[0];
                        if (br_value[0]) begin
                            start <= 1;
                            br_cmd <= 1; // ue(v) for num_tile_columns_minus1
                            state <= P_TILE_COLS;
                        end else begin
                            tile_cols <= 0;
                            tile_rows <= 0;
                            state <= P_DONE;
                        end
                    end
                end
                P_TILE_COLS: if (br_done) begin
                    if (br_error || br_value > 15) goto_error(); // Giới hạn tile_cols
                    else begin
                        tile_cols <= br_value + 1; // num_tile_columns_minus1 + 1
                        start <= 1;
                        br_cmd <= 1; // ue(v) for num_tile_rows_minus1
                        state <= P_TILE_ROWS;
                    end
                end
                P_TILE_ROWS: if (br_done) begin
                    if (br_error || br_value > 15) goto_error(); // Giới hạn tile_rows
                    else begin
                        tile_rows <= br_value + 1;
                        state <= P_DONE;
                    end
                end
                P_DONE: begin
                    done <= 1;
                    state <= P_IDLE;
                end
            endcase
        end
    end

    task goto_error;
        error <= 1;
        state <= P_DONE;
    endtask
endmodule

module sps_decoder (
    input  logic        clk,
    input  logic        reset,
    input  logic [3071:0] sps_bitstream,
    output logic [7:0]  profile,
    output logic [15:0] width,
    output logic [15:0] height,
    output logic [7:0]  fps,
    output logic [1:0]  chroma_format,
    output logic [3:0]  bit_depth,
    output logic        done,
    output logic        error
);
    logic        start, br_cmd, br_done, br_error, br_busy;
    logic [4:0]  br_n;
    logic [31:0] br_value;

    bitstream_reader br (
        .clk(clk), .reset(reset), .bitstream(sps_bitstream),
        .start(start), .cmd(br_cmd), .n(br_n),
        .read_value(br_value), .done(br_done), .busy(br_busy), .error(br_error)
    );

    typedef enum logic [4:0] {
        S_IDLE, S_PROFILE, S_WIDTH, S_HEIGHT, S_FPS, S_CHROMA_FORMAT, S_BIT_DEPTH, S_DONE
    } state_t;
    state_t state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            start <= 0;
            profile <= 0;
            width <= 0;
            height <= 0;
            fps <= 0;
            chroma_format <= 0;
            bit_depth <= 0;
            done <= 0;
            error <= 0;
        end else begin
            start <= 0;

            case (state)
                S_IDLE: begin
                    if (!br_busy) begin
                        start <= 1;
                        br_cmd <= 0;
                        br_n <= 8;
                        state <= S_PROFILE;
                    end
                end
                S_PROFILE: if (br_done) begin
                    if (br_error) goto_error();
                    else begin
                        profile <= br_value[7:0];
                        start <= 1;
                        br_cmd <= 1; // ue(v) for width
                        state <= S_WIDTH;
                    end
                end
                S_WIDTH: if (br_done) begin
                    if (br_error || br_value == 0 || br_value > 8192) goto_error();
                    else begin
                        width <= br_value[15:0];
                        start <= 1;
                        br_cmd <= 1; // ue(v) for height
                        state <= S_HEIGHT;
                    end
                end
                S_HEIGHT: if (br_done) begin
                    if (br_error || br_value == 0 || br_value > 8192) goto_error();
                    else begin
                        height <= br_value[15:0];
                        start <= 1;
                        br_cmd <= 0; // u(8) for fps
                        br_n <= 8;
                        state <= S_FPS;
                    end
                end
                S_FPS: if (br_done) begin
                    if (br_error) goto_error();
                    else begin
                        fps <= br_value[7:0];
                        start <= 1;
                        br_cmd <= 1; // ue(v) for chroma_format_idc
                        state <= S_CHROMA_FORMAT;
                    end
                end
                S_CHROMA_FORMAT: if (br_done) begin
                    if (br_error) goto_error();
                    else begin
                        chroma_format <= br_value[1:0];
                        start <= 1;
                        br_cmd <= 1; // ue(v) for bit_depth_luma_minus8
                        state <= S_BIT_DEPTH;
                    end
                end
                S_BIT_DEPTH: if (br_done) begin
                    if (br_error) goto_error();
                    else begin
                        bit_depth <= br_value[3:0] + 8; // bit_depth_luma_minus8 + 8
                        state <= S_DONE;
                    end
                end
                S_DONE: begin
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    task goto_error;
        error <= 1;
        state <= S_DONE;
    endtask
endmodule

module header_decoder (
    input  logic        clk,
    input  logic        reset,
    input  logic [3071:0] nal_unit,
    input  logic        start,
    output logic        valid,
    output logic        done,
    output logic        error,
    // SPS Parameters
    output logic [7:0]  profile,
    output logic [15:0] width,
    output logic [15:0] height,
    output logic [7:0]  fps,
    output logic [1:0]  chroma_format,
    output logic [3:0]  bit_depth,
    // PPS Parameters
    output logic [5:0]  qp,
    output logic        tiles_enabled,
    output logic [3:0]  tile_cols,
    output logic [3:0]  tile_rows
);

    // Internal signals
    logic sps_done, pps_done, sps_error, pps_error;
    logic validator_valid;
    
    // Control FSM
    typedef enum {IDLE, DECODE_SPS, DECODE_PPS, VALIDATE, DONE} state_t;
    state_t state;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
        end else begin
            case(state)
                IDLE: if (start) state <= nal_unit[7:0] == 8'h42 ? DECODE_SPS : DECODE_PPS;
                
                DECODE_SPS: if (sps_done) begin
                    if (sps_error) begin
                        error <= 1;
                        state <= DONE;
                    end else state <= DECODE_PPS;
                end
                
                DECODE_PPS: if (pps_done) begin
                    if (pps_error) begin
                        error <= 1;
                        state <= DONE;
                    end else state <= VALIDATE;
                end
                
                VALIDATE: begin
                    valid <= validator_valid;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // SPS Decoder instance
    sps_decoder sps_dec (
        .clk(clk),
        .reset(reset),
        .sps_bitstream(nal_unit),
        .start(state == DECODE_SPS),
        .profile(profile),
        .width(width),
        .height(height),
        .fps(fps),
        .chroma_format(chroma_format),
        .bit_depth(bit_depth),
        .done(sps_done),
        .error(sps_error)
    );

    // PPS Decoder instance
    pps_decoder pps_dec (
        .clk(clk),
        .reset(reset),
        .pps_bitstream(nal_unit),
        .start(state == DECODE_PPS),
        .qp(qp),
        .tiles_enabled(tiles_enabled),
        .tile_cols(tile_cols),
        .tile_rows(tile_rows),
        .done(pps_done),
        .error(pps_error)
    );

    // Parameter Validator
    parameter_validator validator (
        .clk(clk),
        .reset(reset),
        .profile(profile),
        .width(width),
        .height(height),
        .fps(fps),
        .chroma_format(chroma_format),
        .bit_depth(bit_depth),
        .qp(qp),
        .tiles_enabled(tiles_enabled),
        .tile_cols(tile_cols),
        .tile_rows(tile_rows),
        .valid(validator_valid),
        .done()
    );

endmodule

// Module: Hardware Optimizer
// Pipeline register để đồng bộ hóa dữ liệu RGB
module hardware_optimizer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  R_in,
    input  logic [7:0]  G_in,
    input  logic [7:0]  B_in,
    output logic [7:0]  R_out,
    output logic [7:0]  G_out,
    output logic [7:0]  B_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_out <= 8'd0;
            G_out <= 8'd0;
            B_out <= 8'd0;
        end else begin
            R_out <= R_in;
            G_out <= G_in;
            B_out <= B_in;
        end
    end
endmodule


// Module: Matrix Multiplier
// Chuyển đổi YUV sang RGB bằng ma trận 3x3
module matrix_multiplier #(
    parameter int C11 = 16'h0100, // 1.0 in Q8.8
    parameter int C12 = 16'h0000, // 0.0
    parameter int C13 = 16'h0166, // ~1.402 in Q8.8 (BT.601)
    parameter int C21 = 16'h0100, // 1.0
    parameter int C22 = 16'hFF58, // ~-0.344 in Q8.8
    parameter int C23 = 16'hFF49, // ~-0.714 in Q8.8
    parameter int C31 = 16'h0100, // 1.0
    parameter int C32 = 16'h01C5, // ~1.772 in Q8.8
    parameter int C33 = 16'h0000  // 0.0
)(
    input  logic [7:0]  Y,
    input  logic [7:0]  U,
    input  logic [7:0]  V,
    output logic [7:0]  R,
    output logic [7:0]  G,
    output logic [7:0]  B
);
    logic signed [23:0] temp_R, temp_G, temp_B;

    always_comb begin
        // Tính R = Y + 1.402 * (V - 128)
        logic signed [8:0]  V_diff = V - 8'd128;
        logic signed [24:0] prod_R  = V_diff * $signed(C13);
        temp_R = (Y << 8) + (prod_R >>> 8);

        // Tính G = Y - 0.344 * (U - 128) - 0.714 * (V - 128)
        logic signed [8:0]  U_diff = U - 8'd128;
        logic signed [24:0] prod_G1 = U_diff * $signed(C22);
        logic signed [24:0] prod_G2 = V_diff * $signed(C23);
        temp_G = (Y << 8) + (prod_G1 >>> 8) + (prod_G2 >>> 8);

        // Tính B = Y + 1.772 * (U - 128)
        logic signed [24:0] prod_B  = U_diff * $signed(C32);
        temp_B = (Y << 8) + (prod_B >>> 8);

        // Saturation để đảm bảo R, G, B nằm trong [0, 255]
        R = (temp_R[23]) ? 8'd0 : (temp_R[15:8] > 255) ? 8'd255 : temp_R[15:8];
        G = (temp_G[23]) ? 8'd0 : (temp_G[15:8] > 255) ? 8'd255 : temp_G[15:8];
        B = (temp_B[23]) ? 8'd0 : (temp_B[15:8] > 255) ? 8'd255 : temp_B[15:8];
    end
endmodule

// Module: Output Formatter
// Đóng gói 128 pixel RGB thành gói 3072-bit
module output_formatter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  R,
    input  logic [7:0]  G,
    input  logic [7:0]  B,
    input  logic        valid_in,
    output logic [3071:0] data_out,
    output logic        valid_out
);
    logic [23:0] pixel_buffer [0:127]; // Buffer cho 128 pixel
    logic [6:0]  count;                // Đếm số pixel

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= 7'd0;
            valid_out <= 1'b0;
            data_out  <= 3072'd0;
        end else if (valid_in) begin
            pixel_buffer[count] <= {R, G, B};
            if (count == 7'd127) begin
                // Buffer đầy, xuất gói dữ liệu
                for (int i = 0; i < 128; i++) begin
                    data_out[i*24 +: 24] = pixel_buffer[i];
                end
                valid_out <= 1'b1;
                count     <= 7'd0;
            end else begin
                count     <= count + 1;
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule

// Module: HW-Accelerated YUV2RGB
// Tổng hợp các khối con
module hw_accelerated_yuv2rgb (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  Y,
    input  logic [7:0]  U,
    input  logic [7:0]  V,
    input  logic        valid_in,
    output logic [3071:0] data_out,
    output logic        valid_out
);
    logic [7:0] R_mm, G_mm, B_mm;  // Đầu ra từ Matrix Multiplier
    logic [7:0] R_opt, G_opt, B_opt; // Đầu ra từ Hardware Optimizer

    matrix_multiplier mm (
        .Y(Y),
        .U(U),
trecht

.V(V),
        .R(R_mm),
        .G(G_mm),
        .B(B_mm)
    );

    hardware_optimizer opt (
        .clk(clk),
        .rst_n(rst_n),
        .R_in(R_mm),
        .G_in(G_mm),
        .B_in(B_mm),
        .R_out(R_opt),
        .G_out(G_opt),
        .B_out(B_opt)
    );

    output_formatter fmt (
        .clk(clk),
        .rst_n(rst_n),
        .R(R_opt),
        .G(G_opt),
        .B(B_opt),
        .valid_in(valid_in),
        .data_out(data_out),
        .valid_out(valid_out)
    );
endmodule

module inverse_quantizer #(
    parameter COEFF_WIDTH = 16,
    parameter QP_WIDTH = 6,
    parameter BIT_DEPTH = 8
) (
    input  logic signed [COEFF_WIDTH-1:0] quantized_coeff,
    input  logic [QP_WIDTH-1:0]           QP,
    output logic signed [COEFF_WIDTH-1:0] coeff
);

    localparam SF_WIDTH = 20;
    localparam logic [SF_WIDTH-1:0] scale_factor [0:5] = '{
        40 * (1 << 14), 45 * (1 << 14), 51 * (1 << 14),
        57 * (1 << 14), 64 * (1 << 14), 72 * (1 << 14)
    };

    logic [5:0] shift_amount = QP / 6;
    logic [2:0] scale_idx = QP % 6;
    logic signed [35:0] temp_product;
    logic signed [COEFF_WIDTH-1:0] scaled_coeff;

    always_comb begin
        if (QP >= 52) begin
            coeff = 0;
        end else begin
            temp_product = quantized_coeff * scale_factor[scale_idx];
            scaled_coeff = temp_product >>> (14 + BIT_DEPTH - 8 - shift_amount);
            coeff = (scaled_coeff >  (2**(COEFF_WIDTH-1)-1)) ?  (2**(COEFF_WIDTH-1)-1) :
                    (scaled_coeff < -(2**(COEFF_WIDTH-1)))   ? -(2**(COEFF_WIDTH-1))   :
                    scaled_coeff;
        end
    end
endmodule

module inverse_transform #(
    parameter COEFF_WIDTH = 16,
    parameter MAX_SIZE = 32
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done,
    input  logic [1:0] transform_size,
    input  logic signed [COEFF_WIDTH-1:0] coeff_matrix[MAX_SIZE][MAX_SIZE],
    output logic signed [COEFF_WIDTH-1:0] residual_data[MAX_SIZE][MAX_SIZE]
);

    logic signed [COEFF_WIDTH-1:0] stage_buf[MAX_SIZE][MAX_SIZE];
    logic [5:0] process_steps;
    typedef enum {IDLE, ROW_PROCESS, COL_PROCESS, DONE} state_t;
    state_t state;
    logic [5:0] row_cnt, col_cnt;

    always_comb begin
        case (transform_size)
            2'b00: process_steps = 4;
            2'b01: process_steps = 8;
            2'b10: process_steps = 16;
            2'b11: process_steps = 32;
            default: process_steps = 4;
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            row_cnt <= 0;
            col_cnt <= 0;
        end else begin
            case (state)
                IDLE: if (start) state <= ROW_PROCESS;
                ROW_PROCESS: if (row_cnt < process_steps) begin
                    logic signed [COEFF_WIDTH-1:0] row_data[0:31];
                    for (int j = 0; j < process_steps; j++) row_data[j] = coeff_matrix[row_cnt][j];
                    idct_1d(row_data, stage_buf[row_cnt], process_steps);
                    row_cnt <= row_cnt + 1;
                end else begin
                    state <= COL_PROCESS;
                    col_cnt <= 0;
                end
                COL_PROCESS: if (col_cnt < process_steps) begin
                    logic signed [COEFF_WIDTH-1:0] col_data[0:31], idct_col[0:31];
                    for (int i = 0; i < process_steps; i++) col_data[i] = stage_buf[i][col_cnt];
                    idct_1d(col_data, idct_col, process_steps);
                    for (int i = 0; i < process_steps; i++) residual_data[i][col_cnt] <= idct_col[i];
                    col_cnt <= col_cnt + 1;
                end else begin
                    state <= DONE;
                    done <= 1;
                end
                DONE: if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end

    function automatic void idct_1d(input logic signed [COEFF_WIDTH-1:0] in_data[0:31],
                                   output logic signed [COEFF_WIDTH-1:0] out_data[0:31],
                                   input integer size);
        // Ghi chú: Cần triển khai IDCT chuẩn cho từng kích thước; tạm dùng nhân đơn giản
        for (int i = 0; i < size; i++) out_data[i] = in_data[i] * 64 >>> 6;
    endfunction
endmodule


module transform_size_selector (
    input  logic [7:0] syntax_elements,
    input  logic [1:0] cu_size,
    output logic [1:0] transform_size
);

    always_comb begin
        if (cu_size == 2'b00) begin // 8x8
            transform_size = syntax_elements[0] ? 2'b00 : 2'b01;
        end else if (cu_size == 2'b01) begin // 16x16
            case (syntax_elements[1:0])
                2'b00: transform_size = 2'b00;
                2'b01: transform_size = 2'b01;
                2'b10: transform_size = 2'b10;
                default: transform_size = 2'b00;
            endcase
        end else begin // >= 32x32
            transform_size = syntax_elements[3] ? 2'b11 : 2'b10;
        end
    end
endmodule

module inverse_quant_transform #(
    parameter COEFF_WIDTH = 16,
    parameter QP_WIDTH = 6,
    parameter MAX_SIZE = 32,
    parameter BIT_DEPTH = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done,
    input  logic [7:0]                    syntax_elements,
    input  logic signed [COEFF_WIDTH-1:0] quantized_coeff_matrix[MAX_SIZE][MAX_SIZE],
    input  logic [QP_WIDTH-1:0]           QP,
    output logic signed [COEFF_WIDTH-1:0] residual_data[MAX_SIZE][MAX_SIZE]
);

    typedef enum {IDLE, QUANT_PROCESS, TRANSFORM, DONE} state_t;
    state_t state;
    logic signed [COEFF_WIDTH-1:0] dequant_buf[MAX_SIZE][MAX_SIZE];
    logic [1:0] transform_size;
    logic transform_start, transform_done;

    transform_size_selector tss (
        .syntax_elements(syntax_elements),
        .cu_size(2'b11), // Giả định, cần lấy từ cú pháp thực tế
        .transform_size(transform_size)
    );

    inverse_transform it (
        .clk(clk), .reset(reset), .start(transform_start), .done(transform_done),
        .transform_size(transform_size),
        .coeff_matrix(dequant_buf),
        .residual_data(residual_data)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
        end else begin
            case (state)
                IDLE: if (start) state <= QUANT_PROCESS;
                QUANT_PROCESS: begin
                    for (int i = 0; i < MAX_SIZE; i++) begin
                        for (int j = 0; j < MAX_SIZE; j++) begin
                            inverse_quantizer iq (
                                .quantized_coeff(quantized_coeff_matrix[i][j]),
                                .QP(QP),
                                .coeff(dequant_buf[i][j])
                            );
                        end
                    end
                    state <= TRANSFORM;
                    transform_start <= 1;
                end
                TRANSFORM: begin
                    transform_start <= 0;
                    if (transform_done) begin
                        state <= DONE;
                        done <= 1;
                    end
                end
                DONE: if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end
endmodule

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

// Bitstream Reader Module (Improved)
module BitstreamReader (
    input  logic         clk,
    input  logic         reset,
    input  logic [7:0]   bitstream_data,    // Input byte stream
    input  logic         bitstream_valid,   // Valid signal for input byte
    output logic [3071:0] chunk_data,       // 3072-bit chunk output
    output logic         chunk_valid,       // Valid signal for chunk output
    output logic         chunk_overflow     // Warning when input overflows
);

    logic [3071:0] buffer;
    logic [9:0] byte_count;  // 0-383 (384 bytes)
    logic [7:0] input_reg;
    logic input_valid_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer <= '0;
            byte_count <= '0;
            chunk_valid <= 1'b0;
            chunk_overflow <= 1'b0;
            input_reg <= '0;
            input_valid_reg <= 1'b0;
        end else begin
            chunk_valid <= 1'b0;
            chunk_overflow <= 1'b0;
            
            input_reg <= bitstream_data;
            input_valid_reg <= bitstream_valid;
            
            if (input_valid_reg) begin
                if (byte_count < 384) begin
                    buffer[byte_count*8 +:8] <= input_reg;
                    byte_count <= byte_count + 1;
                end else begin
                    chunk_overflow <= 1'b1;
                end
                
                if (byte_count == 383) begin
                    chunk_data <= {buffer[3063:0], input_reg};
                    chunk_valid <= 1'b1;
                    byte_count <= 0;
                end
            end
        end
    end
endmodule

// NAL Unit Detector Module (FSM-based)
module NALUnitDetector (
    input  logic         clk,
    input  logic         reset,
    input  logic [3071:0] chunk_data,      // 3072-bit chunk input
    input  logic         chunk_valid,      // Valid signal for chunk
    output logic         nal_start,        // Start of NAL unit
    output logic         nal_end,          // End of NAL unit
    output logic [3071:0] nal_payload,     // NAL payload data
    output logic [9:0]   nal_payload_size  // Valid bytes in payload
);

    typedef enum logic [1:0] {
        IDLE,
        PROCESS_CHUNK,
        START_FOUND
    } state_t;
    
    state_t state, next_state;
    logic [23:0] shift_reg;
    logic start_code_found;
    logic long_start_code;
    logic [9:0] byte_idx;
    logic [9:0] payload_count;
    logic [3071:0] payload_buffer;
    logic chunk_done;
    
    localparam START_CODE_SHORT = 24'h000001;
    localparam START_CODE_LONG  = 32'h00000001;
    
    always_comb begin
        start_code_found = (shift_reg[23:0] == START_CODE_SHORT);
        long_start_code = (shift_reg[15:0] == 16'h0000) && (chunk_data[byte_idx*8 +:8] == 8'h01);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            shift_reg <= '0;
            byte_idx <= '0;
            payload_count <= '0;
            payload_buffer <= '0;
            nal_start <= 1'b0;
            nal_end <= 1'b0;
            nal_payload <= '0;
            nal_payload_size <= '0;
            chunk_done <= 1'b0;
        end else begin
            nal_start <= 1'b0;
            nal_end <= 1'b0;
            chunk_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (chunk_valid) begin
                        state <= PROCESS_CHUNK;
                        byte_idx <= 0;
                        shift_reg <= '0;
                        payload_count <= 0;
                    end
                end
                
                PROCESS_CHUNK: begin
                    if (byte_idx < 384) begin
                        shift_reg <= {shift_reg[15:0], chunk_data[byte_idx*8 +:8]};
                        
                        if (start_code_found || (byte_idx >= 1 && long_start_code)) begin
                            if (payload_count > 0) begin
                                nal_end <= 1'b1;
                                nal_payload <= payload_buffer;
                                nal_payload_size <= payload_count;
                            end
                            
                            state <= START_FOUND;
                            nal_start <= 1'b1;
                            payload_count <= 0;
                            payload_buffer <= '0;
                            
                            if (long_start_code) begin
                                byte_idx <= byte_idx + 1;
                            end
                        end else begin
                            if (!(shift_reg[23:16] == 8'h00 && shift_reg[15:8] == 8'h00 && shift_reg[7:0] == 8'h03)) begin
                                if (payload_count < 384) begin
                                    payload_buffer[payload_count*8 +:8] <= chunk_data[byte_idx*8 +:8];
                                    payload_count <= payload_count + 1;
                                end
                            end
                        end
                        byte_idx <= byte_idx + 1;
                    end else begin
                        chunk_done <= 1'b1;
                        state <= IDLE;
                        if (payload_count > 0) begin
                            nal_end <= 1'b1;
                            nal_payload <= payload_buffer;
                            nal_payload_size <= payload_count;
                        end
                    end
                end
                
                START_FOUND: begin
                    shift_reg <= '0;
                    state <= PROCESS_CHUNK;
                end
            endcase
        end
    end
endmodule

// NAL Unit Extractor Module (Improved)
module NALUnitExtractor (
    input  logic         clk,
    input  logic         reset,
    input  logic         nal_start,        // Start of NAL unit
    input  logic         nal_end,          // End of NAL unit
    input  logic [3071:0] nal_payload,     // NAL payload data
    input  logic [9:0]   nal_payload_size, // Valid payload size
    output logic [7:0]   nal_type,         // NAL unit type
    output logic [3071:0] nal_unit,        // Extracted NAL unit
    output logic [9:0]   nal_unit_size,    // Size of NAL unit
    output logic         nal_valid         // Valid signal for NAL unit
);

    logic [3071:0] unit_buffer;
    logic [9:0] unit_size;
    logic has_started;
    logic [7:0] first_byte;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            nal_type <= '0;
            nal_unit <= '0;
            nal_unit_size <= '0;
            nal_valid <= 1'b0;
            unit_buffer <= '0;
            unit_size <= '0;
            has_started <= 1'b0;
            first_byte <= '0;
        end else begin
            nal_valid <= 1'b0;
            
            if (nal_start) begin
                unit_buffer <= '0;
                unit_size <= '0;
                has_started <= 1'b1;
                first_byte <= nal_payload[7:0];
            end
            
            if (nal_end && has_started) begin
                nal_type <= first_byte;
                nal_unit <= unit_buffer;
                nal_unit_size <= unit_size;
                nal_valid <= nvim1'b1;
                has_started <= 1'b0;
            end else if (has_started) begin
                for (int i = 0; i < nal_payload_size; i++) begin
                    if (unit_size < 384) begin
                        unit_buffer[unit_size*8 +:8] <= nal_payload[i*8 +:8];
                        unit_size <= unit_size + 1;
                    end
                end
            end
        end
    end
endmodule

// Top-level NAL Parser with Error Handling
module NALParser (
    input  logic         clk,
    input  logic         reset,
    input  logic [7:0]   bitstream_data,    // H.265 bitstream input
    input  logic         bitstream_valid,   // Valid signal for input
    output logic [7:0]   nal_type,          // Type of extracted NAL unit
    output logic [3071:0] nal_unit,         // Extracted NAL unit data
    output logic [9:0]   nal_unit_size,     // Size of valid data in NAL unit
    output logic         nal_valid,         // Valid signal for NAL unit
    output logic         error_overflow     // Buffer overflow error
);

    logic [3071:0] chunk_data;
    logic chunk_valid;
    logic chunk_overflow;
    logic nal_start;
    logic nal_end;
    logic [3071:0] nal_payload;
    logic [9:0] nal_payload_size;
    logic int_error_overflow;

    BitstreamReader reader (
        .clk(clk),
        .reset(reset),
        .bitstream_data(bitstream_data),
        .bitstream_valid(bitstream_valid),
        .chunk_data(chunk_data),
        .chunk_valid(chunk_valid),
        .chunk_overflow(chunk_overflow)
    );
    
    NALUnitDetector detector (
        .clk(clk),
        .reset(reset),
        .chunk_data(chunk_data),
        .chunk_valid(chunk_valid),
        .nal_start(nal_start),
        .nal_end(nal_end),
        .nal_payload(nal_payload),
        .nal_payload_size(nal_payload_size)
    );
    
    NALUnitExtractor extractor (
        .clk(clk),
        .reset(reset),
        .nal_start(nal_start),
        .nal_end(nal_end),
        .nal_payload(nal_payload),
        .nal_payload_size(nal_payload_size),
        .nal_type(nal_type),
        .nal_unit(nal_unit),
        .nal_unit_size(nal_unit_size),
        .nal_valid(nal_valid)
    );
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            int_error_overflow <= 1'b0;
            error_overflow <= 1'b0;
        end else begin
            if (chunk_overflow) begin
                int_error_overflow <= 1'b1;
            end
            error_overflow <= int_error_overflow;
        end
    end
endmodule

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

module ModeSelector (
    input  logic [7:0] pred_mode,       // Phần tử cú pháp pred_mode
    output logic       prediction_mode,  // 0: Intra, 1: Inter
    output logic       mode_valid        // 1: Mode hợp lệ, 0: Lỗi
);
    always_comb begin
        mode_valid = 1'b1;
        case (pred_mode)
            8'h00: prediction_mode = 1'b0;  // Intra
            8'h01: prediction_mode = 1'b1;  // Inter
            default: begin
                prediction_mode = 1'b0;     // Mặc định Intra
                mode_valid = 1'b0;          // Báo lỗi mode
            end
        endcase
    end
endmodule

module PredictionModule #(
    parameter BLOCK_SIZE = 8
) (
    input  logic clk,
    input  logic reset_n,
    input  logic [7:0] pred_mode,
    input  logic [7:0] intra_mode,
    input  logic       top_available,
    input  logic       left_available,
    input  logic [7:0] top_pixels [0:BLOCK_SIZE-1],
    input  logic [7:8] left_pixels[0:BLOCK_SIZE-1],
    input  logic signed [8:0] mv_x, mv_y,
    input  logic [9:0] pos_x, pos_y,
    input  logic [7:0] ref_window [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1],
    output logic [7:0] predicted_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1],
    output logic       valid_out,
    output logic       error_flag
);
    logic prediction_mode;
    logic mode_valid;
    logic [7:0] intra_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [7:0] inter_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [7:0] pred_block_ff [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic valid_ff, error_ff;

    ModeSelector u_mode_selector (
        .pred_mode(pred_mode),
        .prediction_mode(prediction_mode),
        .mode_valid(mode_valid)
    );
    
    IntraPrediction u_intra (
        .intra ..

mode(intra_mode),
        .top_available(top_available),
        .left_available(left_available),
        .top_neighbors(top_pixels),
        .left_neighbors(left_pixels),
        .predicted_block(intra_block)
    );
    
    InterPrediction u_inter (
        .clk(clk),
        .mv_x(mv_x),
        .mv_y(mv_y),
        .pos_x(pos_x),
        .pos_y(pos_y),
        .ref_pixel(ref_window),
        .predicted_block(inter_block)
    );

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int y=0; y<BLOCK_SIZE; y++) for (int x=0; x<BLOCK_SIZE; x++)
                pred_block_ff[y][x] <= 8'd0;
            valid_ff <= 1'b0;
            error_ff <= 1'b0;
        end else begin
            error_ff <= !mode_valid;
            valid_ff <= mode_valid;
            if (prediction_mode == 1'b0)  // Intra
                pred_block_ff <= intra_block;
            else                         // Inter
                pred_block_ff <= inter_block;
        end
    end

    assign predicted_block = pred_block_ff;
    assign valid_out = valid_ff;
    assign error_flag = error_ff;
endmodule

module block_combiner #(
    parameter BLOCK_SIZE = 8,      // Kích thước khối (4,8,16,32)
    parameter PIXEL_WIDTH = 8,     // Bit màu (8-bit)
    parameter RESIDUAL_WIDTH = 12  // Bit phần dư (mở rộng để tránh tràn)
)(
    input  logic clk,              // Clock đồng bộ
    input  logic reset,            // Reset bất đồng bộ
    input  logic enable,           // Tín hiệu kích hoạt
    input  logic [PIXEL_WIDTH-1:0] P [BLOCK_SIZE][BLOCK_SIZE],      // Khối dự đoán
    input  logic signed [RESIDUAL_WIDTH-1:0] R [BLOCK_SIZE][BLOCK_SIZE], // Phần dư (có dấu)
    output logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE],  // Khối tái tạo
    output logic done              // Báo hoàn thành
);
    logic [PIXEL_WIDTH-1:0] P_reg [BLOCK_SIZE][BLOCK_SIZE];
    logic signed [RESIDUAL_WIDTH-1:0] R_reg [BLOCK_SIZE][BLOCK_SIZE];
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 0;
            for (int i = 0; i < BLOCK_SIZE; i++) begin
                for (int j = 0; j < BLOCK_SIZE; j++) begin
                    Recon[i][j] <= 0;
                end
            end
        end else if (enable) begin
            P_reg <= P;
            R_reg <= R;
            done <= 1;
            for (int i = 0; i < BLOCK_SIZE; i++) begin
                for (int j = 0; j < BLOCK_SIZE; j++) begin
                    logic [RESIDUAL_WIDTH:0] sum_ext;
                    sum_ext = $signed({1'b0, P_reg[i][j]}) + $signed(R_reg[i][j]); // Mở rộng P_reg
                    if (sum_ext < 0)
                        Recon[i][j] <= 0;
                    else if (sum_ext > ( (1 << PIXEL_WIDTH) - 1))
                        Recon[i][j] <= ( (1 << PIXEL_WIDTH) - 1);
                    else
                        Recon[i][j] <= sum_ext[PIXEL_WIDTH-1:0];
                end
            end
        end else begin
            done <= 0;
        end
    end
endmodule

module frame_assembler #(
    parameter FRAME_WIDTH = 640,
    parameter FRAME_HEIGHT = 480,
    parameter BLOCK_SIZE = 8,
    parameter PIXEL_WIDTH = 8,
    parameter ADDR_WIDTH = 19  // log2(640*480) ≈ 19 bit
)(
    input  logic clk,              // Clock đồng bộ
    input  logic reset,            // Reset bất đồng bộ
    input  logic start,            // Tín hiệu bắt đầu ghi
    input  logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE], // Khối đầu vào
    input  logic [9:0] block_x,    // Tọa độ X của khối (0-79)
    input  logic [9:0] block_y,    // Tọa độ Y của khối (0-59)
    output logic [ADDR_WIDTH-1:0] mem_addr,  // Địa chỉ ghi memory
    output logic [PIXEL_WIDTH-1:0] mem_data, // Dữ liệu ghi memory
    output logic mem_we,           // Tín hiệu ghi memory
    output logic done              // Báo hoàn thành
);
    logic [3:0] i, j;
    logic active;
    logic [ADDR_WIDTH-1:0] base_addr;
    assign base_addr = (block_y * BLOCK_SIZE * FRAME_WIDTH) + (block_x * BLOCK_SIZE);
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            active <= 0;
            mem_we <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                i <= 0;
                j <= 0;
            end
            if (active) begin
                mem_addr <= base_addr + (i * FRAME_WIDTH) + j;
                mem_data <= Recon[i][j];
                mem_we <= 1;
                if ((block_y * BLOCK_SIZE + i >= FRAME_HEIGHT) || 
                    (block_x * BLOCK_SIZE + j >= FRAME_WIDTH)) begin
                    mem_we <= 0; // Tắt ghi nếu vượt biên
                end
                if (j == BLOCK_SIZE - 1) begin
                    j <= 0;
                    if (i == BLOCK_SIZE - 1) begin
                        active <= 0;
                        done <= 1;
                    end else begin
                        i <= i + 1;
                    end
                end else begin
                    j <= j + 1;
                end
            end else begin
                mem_we <= 0;
                done <= 0;
            end
        end
    end
endmodule

module reconstruction_unit #(
    parameter FRAME_WIDTH = 640,
    parameter FRAME_HEIGHT = 480,
    parameter BLOCK_SIZE = 8,
    parameter PIXEL_WIDTH = 8,
    parameter ADDR_WIDTH = 19,
    parameter RESIDUAL_WIDTH = 12
)(
    input  logic clk,
    input  logic reset,
    input  logic block_valid,
    input  logic [PIXEL_WIDTH-1:0] P [BLOCK_SIZE][BLOCK_SIZE],
    input  logic signed [RESIDUAL_WIDTH-1:0] R [BLOCK_SIZE][BLOCK_SIZE],
    input  logic [9:0] block_x,
    input  logic [9:0] block_y,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [PIXEL_WIDTH-1:0] mem_data,
    output logic mem_we,
    output logic done
);
    logic combiner_done;
    logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE];
    
    block_combiner #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .RESIDUAL_WIDTH(RESIDUAL_WIDTH)
    ) combiner (
        .clk(clk),
        .reset Reset),
        .enable(block_valid),
        .P(P),
        .R(R),
        .Recon(Recon),
        .done(combiner_done)
    );
    
    frame_assembler #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) assembler (
        .clk(clk),
        .reset(reset),
        .start(combiner_done),
        .Recon(Recon),
        .block_x(block_x),
        .block_y(block_y),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_we(mem_we),
        .done(done)
    );
endmodule


// Optimized Slice Data Extractor Module
module slice_data_extractor (
    input  logic [3071:0]    nal_unit,     // Input NAL unit (slice RBSP)
    input  logic [11:0]      bit_pos,      // Position after header
    input  logic             valid_in,     // Valid signal from header parser
    output logic [3071:0]    slice_data,   // Encoded slice data
    output logic             valid_out     // Data extracted successfully
);

    // Use shift operation instead of part-select for better resource utilization
    always_comb begin
        slice_data = '0;
        valid_out = 0;
        
        if (valid_in) begin
            if (bit_pos < 3072) begin
                // Shift out processed header bits
                slice_data = nal_unit >> bit_pos;
                valid_out = 1;
            end
        end
    end

endmodule


// Slice Header Parser Module (Optimized)
module slice_header_parser (
    input  logic             clk,
    input  logic             reset,
    input  logic             start,                // Signal to begin parsing
    input  logic [3071:0]    nal_unit,             // Input NAL unit (slice RBSP)
    output logic [1:0]       slice_type,           // 00: I, 01: P, 10: B
    output logic [2:0]       num_ref_idx_l0_active_minus1, // Ref list 0 count
    output logic [2:0]       num_ref_idx_l1_active_minus1, // Ref list 1 count (B only)
    output logic [5:0]       slice_qp_delta,       // QP delta
    output logic             valid,                // Header parsing complete
    output logic             error,                // Invalid slice type detected
    output logic [11:0]      bit_pos               // Position after header
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE             = 3'd0,
        READ_SLICE_TYPE  = 3'd1,
        READ_NUM_REF_L0  = 3'd2,
        READ_NUM_REF_L1  = 3'd3,
        READ_QP_DELTA    = 3'd4,
        DONE             = 3'd5,
        ERROR            = 3'd6,
        INVALID_STATE    = 3'd7
    } state_t;

    state_t state, next_state;
    logic [11:0] bit_pos_reg;  // Internal bit position tracker
    logic [1:0]  reg_slice_type; // Registered slice type

    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state                   <= IDLE;
            bit_pos_reg             <= 0;
            valid                   <= 0;
            error                   <= 0;
            slice_type              <= 0;
            reg_slice_type          <= 0;
            num_ref_idx_l0_active_minus1 <= 0;
            num_ref_idx_l1_active_minus1 <= 0;
            slice_qp_delta          <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid  <= 0;
                    error  <= 0;
                    bit_pos_reg <= 0;
                end
                
                READ_SLICE_TYPE: begin
                    if (bit_pos_reg <= 3070) begin
                        reg_slice_type <= nal_unit[bit_pos_reg +: 2];
                        slice_type <= nal_unit[bit_pos_reg +: 2];
                        bit_pos_reg <= bit_pos_reg + 2;
                    end
                end
                
                READ_NUM_REF_L0: begin
                    if (bit_pos_reg <= 3069) begin
                        num_ref_idx_l0_active_minus1 <= nal_unit[bit_pos_reg +: 3];
                        bit_pos_reg <= bit_pos_reg + 3;
                    end
                end
                
                READ_NUM_REF_L1: begin
                    if (bit_pos_reg <= 3069) begin
                        num_ref_idx_l1_active_minus1 <= nal_unit[bit_pos_reg +: 3];
                        bit_pos_reg <= bit_pos_reg + 3;
                    end
                end
                
                READ_QP_DELTA: begin
                    if (bit_pos_reg <= 3066) begin
                        slice_qp_delta <= nal_unit[bit_pos_reg +: 6];
                        bit_pos_reg <= bit_pos_reg + 6;
                    end
                end
                
                DONE: begin
                    valid <= 1;
                end
                
                ERROR: begin
                    error <= 1;
                end
                
                default: begin
                    // Recovery mechanism
                    state <= IDLE;
                    error <= 1;
                end
            endcase
        end
    end

    // Next state logic with enhanced error checking
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = (bit_pos_reg < 3072) ? READ_SLICE_TYPE : ERROR;
                end
            end
            
            READ_SLICE_TYPE: begin
                if (bit_pos_reg > 3070) begin
                    next_state = ERROR;
                end else begin
                    case (nal_unit[bit_pos_reg +: 2])
                        2'b00: next_state = READ_QP_DELTA;  // I slice
                        2'b01: next_state = READ_NUM_REF_L0; // P slice
                        2'b10: next_state = READ_NUM_REF_L0; // B slice
                        default: next_state = ERROR;         // Invalid slice type
                    endcase
                end
            end
            
            READ_NUM_REF_L0: begin
                if (bit_pos_reg > 3069) begin
                    next_state = ERROR;
                end else begin
                    // Additional slice type validation
                    if (!(reg_slice_type inside {2'b01, 2'b10})) begin
                        next_state = ERROR;
                    end else if (reg_slice_type == 2'b01) begin
                        next_state = READ_QP_DELTA;  // P slice
                    end else begin
                        next_state = READ_NUM_REF_L1; // B slice
                    end
                end
            end
            
            READ_NUM_REF_L1: begin
                if (bit_pos_reg > 3069) novices
                    next_state = ERROR;
                end else begin
                    // Validate slice type must be B
                    next_state = (reg_slice_type == 2'b10) ? READ_QP_DELTA : ERROR;
                end
            end
            
            READ_QP_DELTA: begin
                if (bit_pos_reg > 3066) begin
                    next_state = ERROR;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE, ERROR: begin
                // Auto-reset for continuous processing
                if (start) next_state = IDLE;
            end
            
            default: next_state = ERROR;
        endcase
    end

    assign bit_pos = bit_pos_reg;

endmodule

// Enhanced Top-Level Slice Decoder Module
module slice_decoder (
    input  logic             clk,
    input  logic             reset,
    input  logic             start,
    input  logic [3071:0]    nal_unit,
    output logic [1:0]       slice_type,
    output logic [2:0]       num_ref_idx_l0_active_minus1,
    output logic [2:0]       num_ref_idx_l1_active_minus1,
    output logic [5:0]       slice_qp_delta,
    output logic [3071:0]    slice_data,
    output logic             valid,
    output logic             error
);

    logic [11:0] bit_pos;
    logic header_valid;
    logic data_valid;

    // Instantiate Slice Header Parser
    slice_header_parser header_parser (
        .clk(clk),
        .reset(reset),
        .start(start),
        .nal_unit(nal_unit),
        .slice_type(slice_type),
        .num_ref_idx_l0_active_minus1(num_ref_idx_l0_active_minus1),
        .num_ref_idx_l1_active_minus1(num_ref_idx_l1_active_minus1),
        .slice_qp_delta(slice_qp_delta),
        .valid(header_valid),
        .error(error),
        .bit_pos(bit_pos)
    );

    // Instantiate Slice Data Extractor
    slice_data_extractor data_extractor (
        .nal_unit(nal_unit),
        .bit_pos(bit_pos),
        .valid_in(header_valid),
        .slice_data(slice_data),
        .valid_out(data_valid)
    );

    // Output control with error masking
    assign valid = data_valid && !error;

endmodule

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















































