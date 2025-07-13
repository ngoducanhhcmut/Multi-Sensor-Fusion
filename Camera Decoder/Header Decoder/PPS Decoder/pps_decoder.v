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