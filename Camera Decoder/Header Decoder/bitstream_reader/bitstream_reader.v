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