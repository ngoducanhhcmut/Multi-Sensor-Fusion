module Noise_Reducer (
    input  logic        clk,
    input  logic        rst,
    input  logic        valid_in,       // Tín hiệu valid đầu vào
    input  logic [127:0] raw_point,
    output logic [127:0] filtered_point,
    output logic        valid_out       // Tín hiệu valid đầu ra
);

    // Tín hiệu nội bộ
    logic [127:0] window [0:4];
    logic [31:0] X[0:4], Y[0:4], Z[0:4];
    logic [31:0] med_X, med_Y, med_Z;
    logic buffer_full;

    Window_Buffer wb (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .raw_point(raw_point),
        .window_out(window),
        .buffer_full(buffer_full)
    );

    Coordinate_Splitter cs (
        .window_in(window),
        .X(X),
        .Y(Y),
        .Z(Z)
    );

    Median_Calculator calc_X (.data_in(X), .median(med_X));
    Median_Calculator calc_Y (.data_in(Y), .median(med_Y));
    Median_Calculator calc_Z (.data_in(Z), .median(med_Z));

    Data_Reassembler dr (
        .median_X(med_X),
        .median_Y(med_Y),
        .median_Z(med_Z),
        .current_point(raw_point),
        .filtered_point(filtered_point)
    );

    // Delay valid signal theo pipeline
    logic [2:0] valid_delay;
    always_ff @(posedge clk) begin
        if (rst) valid_delay <= 0;
        else valid_delay <= {valid_delay[1:0], valid_in & buffer_full};
    end
    assign valid_out = valid_delay[2];
endmodule