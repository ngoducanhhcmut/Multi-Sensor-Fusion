// Module PointReader: Đọc và giải nén dữ liệu từ đám mây điểm 512-bit thành các khối 128-bit
module PointReader (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [511:0] point_cloud,
    output reg [127:0] point_data,
    output reg valid,
    output reg done
);
    reg [1:0] counter;
    reg processing;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 2'b0;
            valid <= 1'b0;
            done <= 1'b0;
            processing <= 1'b0;
            point_data <= 128'b0;
        end else begin
            if (start && !processing) begin
                processing <= 1'b1;
                counter <= 2'b0;
                done <= 1'b0;
            end
            if (processing) begin
                case (counter)
                    2'd0: point_data <= point_cloud[127:0];
                    2'd1: point_data <= point_cloud[255:128];
                    2'd2: point_data <= point_cloud[383:256];
                    2'd3: point_data <= point_cloud[511:384];
                endcase
                valid <= 1'b1;
                counter <= counter + 1;
                if (counter == 2'd3) begin
                    done <= 1'b1;
                    processing <= 1'b0;
                end
            end else begin
                valid <= 1'b0;
            end
        end
    end
endmodule