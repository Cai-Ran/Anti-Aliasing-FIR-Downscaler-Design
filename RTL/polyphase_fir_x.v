//support max x decimation factor = 7
module polyphase_fir_x (
    input clk,
    input rst_n,
    input stream_in,
    input Xout_rdy,
    input [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] sel, 
    input [7:0] cur_p,
    input [1:0] h1_1, h1_2, h1_3,
    input [1:0] h2_1, h2_2, h2_3,
    input [1:0] h3_1, h3_2, h3_3,
    input [1:0] h4_1, h4_2, h4_3,
    input [1:0] h5_1, h5_2, h5_3,
    input [1:0] h6_1, h6_2, h6_3,
    input [1:0] h7_1, h7_2, h7_3,
    input [2:0] h1_shft_dir, h2_shft_dir, h3_shft_dir, h4_shft_dir, h5_shft_dir, h6_shft_dir, h7_shft_dir,
    input [2:0] normalize,
    output reg en_xout,
    output reg [7:0] out_p
);
    
    reg [7:0] p1, p2, p3, p4, p5, p6, p7;

    //demux
    always @(negedge clk, negedge rst_n) begin
        if (!rst_n)
            {p1, p2, p3, p4, p5, p6, p7} <= 56'b0;
        else if (!stream_in)
            {p1, p2, p3, p4, p5, p6, p7} <= 56'b0;
        else begin
            /* verilator lint_off CASEINCOMPLETE */
            case (sel)
                3'd0: p1 <= cur_p;
                3'd1: p2 <= cur_p;
                3'd2: p3 <= cur_p;
                3'd3: p4 <= cur_p;
                3'd4: p5 <= cur_p;
                3'd5: p6 <= cur_p;
                3'd6: p7 <= cur_p;
                default: begin
                    $fatal(1, "[Error] Illegal sel value in polyphase_fir_x: %0d", sel);
                end
            endcase
        end
    end
    

    //barrel shifter
    wire [10:0] h1_1_mul, h1_2_mul, h1_3_mul;
    wire [10:0] h2_1_mul, h2_2_mul, h2_3_mul;
    wire [10:0] h3_1_mul, h3_2_mul, h3_3_mul;
    wire [10:0] h4_1_mul, h4_2_mul, h4_3_mul;
    wire [10:0] h5_1_mul, h5_2_mul, h5_3_mul;
    wire [10:0] h6_1_mul, h6_2_mul, h6_3_mul;
    wire [10:0] h7_1_mul, h7_2_mul, h7_3_mul;

    wire [12:0] p1_mul, p2_mul, p3_mul, p4_mul, p5_mul, p6_mul, p7_mul;

    assign h1_1_mul = (!h1_shft_dir[0] && h1_1==0) ? 0 : ((h1_shft_dir[0]) ? p1<<h1_1 : p1>>h1_1);
    assign h1_2_mul = (!h1_shft_dir[1] && h1_2==0) ? 0 : ((h1_shft_dir[1]) ? p1<<h1_2 : p1>>h1_2);
    assign h1_3_mul = (!h1_shft_dir[2] && h1_3==0) ? 0 : ((h1_shft_dir[2]) ? p1<<h1_3 : p1>>h1_3);
    assign p1_mul = h1_1_mul + h1_2_mul + h1_3_mul;

    assign h2_1_mul = (!h2_shft_dir[0] && h2_1==0) ? 0 : ((h2_shft_dir[0]) ? p2 << h2_1 : p2 >> h2_1);
    assign h2_2_mul = (!h2_shft_dir[1] && h2_2==0) ? 0 : ((h2_shft_dir[1]) ? p2 << h2_2 : p2 >> h2_2);
    assign h2_3_mul = (!h2_shft_dir[2] && h2_3==0) ? 0 : ((h2_shft_dir[2]) ? p2 << h2_3 : p2 >> h2_3);
    assign p2_mul = h2_1_mul + h2_2_mul + h2_3_mul;

    assign h3_1_mul = (!h3_shft_dir[0] && h3_1==0) ? 0 : ((h3_shft_dir[0]) ? p3 << h3_1 : p3 >> h3_1);
    assign h3_2_mul = (!h3_shft_dir[1] && h3_2==0) ? 0 : ((h3_shft_dir[1]) ? p3 << h3_2 : p3 >> h3_2);
    assign h3_3_mul = (!h3_shft_dir[2] && h3_3==0) ? 0 : ((h3_shft_dir[2]) ? p3 << h3_3 : p3 >> h3_3);
    assign p3_mul = h3_1_mul + h3_2_mul + h3_3_mul;

    assign h4_1_mul = (!h4_shft_dir[0] && h4_1==0) ? 0 : ((h4_shft_dir[0]) ? p4 << h4_1 : p4 >> h4_1);
    assign h4_2_mul = (!h4_shft_dir[1] && h4_2==0) ? 0 : ((h4_shft_dir[1]) ? p4 << h4_2 : p4 >> h4_2);
    assign h4_3_mul = (!h4_shft_dir[2] && h4_3==0) ? 0 : ((h4_shft_dir[2]) ? p4 << h4_3 : p4 >> h4_3);
    assign p4_mul = h4_1_mul + h4_2_mul + h4_3_mul;

    assign h5_1_mul = (!h5_shft_dir[0] && h5_1==0) ? 0 : ((h5_shft_dir[0]) ? p5 << h5_1 : p5 >> h5_1);
    assign h5_2_mul = (!h5_shft_dir[1] && h5_2==0) ? 0 : ((h5_shft_dir[1]) ? p5 << h5_2 : p5 >> h5_2);
    assign h5_3_mul = (!h5_shft_dir[2] && h5_3==0) ? 0 : ((h5_shft_dir[2]) ? p5 << h5_3 : p5 >> h5_3);
    assign p5_mul = h5_1_mul + h5_2_mul + h5_3_mul;

    assign h6_1_mul = (!h6_shft_dir[0] && h6_1==0) ? 0 : ((h6_shft_dir[0]) ? p6 << h6_1 : p6 >> h6_1);
    assign h6_2_mul = (!h6_shft_dir[1] && h6_2==0) ? 0 : ((h6_shft_dir[1]) ? p6 << h6_2 : p6 >> h6_2);
    assign h6_3_mul = (!h6_shft_dir[2] && h6_3==0) ? 0 : ((h6_shft_dir[2]) ? p6 << h6_3 : p6 >> h6_3);
    assign p6_mul = h6_1_mul + h6_2_mul + h6_3_mul;

    assign h7_1_mul = (!h7_shft_dir[0] && h7_1==0) ? 0 : ((h7_shft_dir[0]) ? p7 << h7_1 : p7 >> h7_1);
    assign h7_2_mul = (!h7_shft_dir[1] && h7_2==0) ? 0 : ((h7_shft_dir[1]) ? p7 << h7_2 : p7 >> h7_2);
    assign h7_3_mul = (!h7_shft_dir[2] && h7_3==0) ? 0 : ((h7_shft_dir[2]) ? p7 << h7_3 : p7 >> h7_3);
    assign p7_mul = h7_1_mul + h7_2_mul + h7_3_mul;

    wire [15:0] acc_sum;
    assign acc_sum = (p1_mul + p2_mul + p3_mul + p4_mul + p5_mul + p6_mul + p7_mul);
    
    always @(negedge clk, negedge rst_n) begin
        if (!rst_n)
            out_p <= 0;
        else if (Xout_rdy)
            out_p <= (acc_sum >> normalize);
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            en_xout <= 0;
        else
            en_xout <= Xout_rdy;
    end

endmodule
