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