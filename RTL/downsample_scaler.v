
//for synthesize
`define MAX_X_DECIMATION_FACTOR_LOG2    3       // X_factor max 7
`define MAX_Y_DECIMATION_FACTOR_LOG2    3       // Y_factor max 5
`define MAX_ROW_LOG2                    11     
`define MAX_COL_LOG2                    10
`define MAX_RES_TARX                    1600
`define X_ROM_LEN                       512
`define Y_ROM_LEN                       512
`define X_ROM_LEN_LOG2                  9       
`define Y_ROM_LEN_LOG2                  9      
`define NUM_RESLUTION_PAIR              64     
`define RESOLUTION_PAIR_LOG2            6

`define SYN
`ifdef SYN
    `include "./read_ROM.v"
    `include "./tmp_row_buffer.v"
    `include "./polyphase_fir_x.v"
    `include "./polyphase_fir_y.v"
`endif 
`ifdef SIM
    `include "./RTL/read_ROM.v"
    `include "./RTL/tmp_row_buffer.v"
    `include "./RTL/polyphase_fir_x.v"
    `include "./RTL/polyphase_fir_y.v"
`endif 

module downsample_scaler(
    input clk,
    input rst_n,

    input vsync,
    input hsync,
    input data_enable,

    input [7:0] cur_R,
    input [7:0] cur_G,
    input [7:0] cur_B,

    input [`RESOLUTION_PAIR_LOG2-1:0] resolution_pair_idx,
    input [2:0] X_factor,
    input [2:0] Y_factor,
    input [`MAX_ROW_LOG2-1:0] tar_width,
    input [`MAX_COL_LOG2-1:0] tar_height,

    output reg en_output,
    output reg [7:0] out_R,
    output reg [7:0] out_G,
    output reg [7:0] out_B,
    output reg frame_done
);

    reg VALID_CONFIG;          //enable the downscaler
    reg ERROR_FLAG;

    reg vsync_latch;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            vsync_latch <= 0;
        else
            vsync_latch <= vsync;
    end

    wire vsync_negedge = vsync_latch && !vsync; 

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            VALID_CONFIG <= 0;
        else if (vsync_negedge) begin
            if (X_factor<3'd2 || Y_factor<3'd1 || Y_factor>3'd5 ||
                tar_width<3'd2 || tar_width>`MAX_RES_TARX || tar_height<3'd1)  begin
                VALID_CONFIG <= 0;
                $display("Error: INVALID CONFIG; DUT freeze");
            end else
                VALID_CONFIG <= 1'b1;
        end
    end


    assign stream_in = data_enable && VALID_CONFIG && !ERROR_FLAG;


    wire [`X_ROM_LEN_LOG2-1:0] x_rom_start;
    wire [`X_ROM_LEN_LOG2-1:0] x_rom_end;
    wire [`Y_ROM_LEN_LOG2-1:0] y_rom_start;
    wire [`Y_ROM_LEN_LOG2-1:0] y_rom_end;
    wire [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] x_window;
    wire [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] y_window;

    //x_window_rom_addr
    reg [`X_ROM_LEN_LOG2-1:0] xw;
    //y_window_rom_addr
    reg [`Y_ROM_LEN_LOG2-1:0] yw;


    wire [1:0] Xh1_1, Xh2_1, Xh3_1, Xh4_1, Xh5_1, Xh6_1, Xh7_1;
    wire [1:0] Xh1_2, Xh2_2, Xh3_2, Xh4_2, Xh5_2, Xh6_2, Xh7_2;
    wire [1:0] Xh1_3, Xh2_3, Xh3_3, Xh4_3, Xh5_3, Xh6_3, Xh7_3;
    wire [2:0] Xh1_shft_dir, Xh2_shft_dir, Xh3_shft_dir, Xh4_shft_dir, Xh5_shft_dir, Xh6_shft_dir, Xh7_shft_dir;
    wire [2:0] Xnormalize;

    wire [1:0] Yh1_1, Yh2_1, Yh3_1, Yh4_1, Yh5_1;
    wire [1:0] Yh1_2, Yh2_2, Yh3_2, Yh4_2, Yh5_2;
    wire [1:0] Yh1_3, Yh2_3, Yh3_3, Yh4_3, Yh5_3;
    wire [2:0] Yh1_shft_dir, Yh2_shft_dir, Yh3_shft_dir, Yh4_shft_dir, Yh5_shft_dir;
    wire [2:0] Ynormalize;


    read_ROM Load_From_ROM(
        .clk(clk), .rst_n(rst_n), 

        .resolution_pair_idx(resolution_pair_idx),
        .xw(xw), .yw(yw), 

        .x_rom_start(x_rom_start), .x_rom_end(x_rom_end), 
        .y_rom_start(y_rom_start), .y_rom_end(y_rom_end),
        .x_window(x_window), .y_window(y_window),

        .Xh1_1(Xh1_1), .Xh1_2(Xh1_2), .Xh1_3(Xh1_3), 
        .Xh2_1(Xh2_1), .Xh2_2(Xh2_2), .Xh2_3(Xh2_3),
        .Xh3_1(Xh3_1), .Xh3_2(Xh3_2), .Xh3_3(Xh3_3),
        .Xh4_1(Xh4_1), .Xh4_2(Xh4_2), .Xh4_3(Xh4_3),
        .Xh5_1(Xh5_1), .Xh5_2(Xh5_2), .Xh5_3(Xh5_3),
        .Xh6_1(Xh6_1), .Xh6_2(Xh6_2), .Xh6_3(Xh6_3),
        .Xh7_1(Xh7_1), .Xh7_2(Xh7_2), .Xh7_3(Xh7_3),
        .Xh1_shft_dir(Xh1_shft_dir), .Xh2_shft_dir(Xh2_shft_dir), .Xh3_shft_dir(Xh3_shft_dir), 
        .Xh4_shft_dir(Xh4_shft_dir), .Xh5_shft_dir(Xh5_shft_dir), .Xh6_shft_dir(Xh6_shft_dir), 
        .Xh7_shft_dir(Xh7_shft_dir), .Xnormalize(Xnormalize),
        .Yh1_1(Yh1_1), .Yh1_2(Yh1_2), .Yh1_3(Yh1_3), 
        .Yh2_1(Yh2_1), .Yh2_2(Yh2_2), .Yh2_3(Yh2_3), 
        .Yh3_1(Yh3_1), .Yh3_2(Yh3_2), .Yh3_3(Yh3_3), 
        .Yh4_1(Yh4_1), .Yh4_2(Yh4_2), .Yh4_3(Yh4_3), 
        .Yh5_1(Yh5_1), .Yh5_2(Yh5_2), .Yh5_3(Yh5_3), 
        .Yh1_shft_dir(Yh1_shft_dir), .Yh2_shft_dir(Yh2_shft_dir), .Yh3_shft_dir(Yh3_shft_dir), 
        .Yh4_shft_dir(Yh4_shft_dir), .Yh5_shft_dir(Yh5_shft_dir), .Ynormalize(Ynormalize)
    );


    reg [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] cnt_load_x;

    localparam [1:0] START  = 2'b00;
    localparam [1:0] KEEP   = 2'b01;
    localparam [1:0] ADD    = 2'b10;

    reg [1:0] x_curr, x_next;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            x_curr <= START;
        else if (!stream_in)
            x_curr <= START;
        else
            x_curr <= x_next;
    end

    always @(*) begin
        case (x_curr)
            START:  x_next = KEEP;

            ADD:    x_next = KEEP;

            KEEP:   
                    if (cnt_load_x != x_window-1)       x_next = KEEP;          //(cnt_load_x != x_window-1)
                    else if (xw==x_rom_end)             x_next = START;         //(cnt_load_x == x_window-1 && xw==x_rom_end)
                    else                                x_next = ADD;           //(cnt_load_x == x_window-1 && xw!=x_rom_end)  
            
            default:
                    begin
                    x_next = START;
                    $fatal(1, "x_curr illegal state: %0d", x_curr);
                    end

        endcase
    end


    always @(posedge clk) begin
        if (x_curr==START)
            xw <= x_rom_start;
        else begin
            case (x_next)
                START:  xw <= x_rom_start;
                ADD:    xw <= xw+1;
                KEEP:   xw <= xw;
            default:    xw <= x_rom_start;
            endcase
        end
    end


    reg Xout_rdy;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            Xout_rdy <= 0;
        else if ((cnt_load_x == x_window-1) && stream_in)
            Xout_rdy <= 1;
        else 
            Xout_rdy <= 0;
    end



    reg [1:0] y_curr, y_next;


    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            y_curr <= START;
        else
            y_curr <= y_next;
    end

    reg [`MAX_ROW_LOG2-1:0] out_num_counter;

    always @(*) begin
        case (y_curr)
            START:  y_next = KEEP;
            ADD:    y_next = KEEP;
            KEEP:   if (out_num_counter!=tar_width)                                         y_next = KEEP;      //(out_num_counter!=tar_width)
                    else if (yw==y_rom_end)                                                 y_next = START;     //(out_num_counter==tar_width && yw==y_rom_end)
                    else                                                                    y_next = ADD;       //(out_num_counter==tar_width && yw!=y_rom_end)
            default:
                    begin
                    y_next = START;
                    // $fatal(1, "y_curr illegal state: %0d", y_curr);
                    end
        endcase
    end

    always @(posedge clk) begin
        if (y_curr==START)
            yw <= y_rom_start;
        else begin
            case (y_next)
                START:      yw <= y_rom_start; 
                ADD:        yw <= yw+1;
                KEEP:       yw <= yw;
                default:    yw <= y_rom_start;
            endcase
        end
    end

    `ifdef SIM
        initial begin
            if (rst_n && (xw>x_rom_end))
                $fatal(1, "Error: ADDRESS of x_window OUT OF BOUND: %0d", xw);
            if (rst_n && (yw>y_rom_end))
                $fatal(1, "Error: ADDRESS of y_window OUT OF BOUND: %0d", yw);
        end
    `endif
    

    wire [7:0] outX_R;
    wire [7:0] outX_G;
    wire [7:0] outX_B;


    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            cnt_load_x <= 0;
        else if (stream_in) begin
            if (cnt_load_x == x_window-1)
                cnt_load_x <= 0;
            else
                cnt_load_x <= cnt_load_x + 1;  
        end
    end



    wire R_en_xout, G_en_xout, B_en_xout;

    polyphase_fir_x R_Xfir( .clk(clk), .rst_n(rst_n), .stream_in(stream_in), .Xout_rdy(Xout_rdy), .sel(cnt_load_x), .cur_p(cur_R), 
                            .h1_1(Xh1_1), .h1_2(Xh1_2), .h1_3(Xh1_3),
                            .h2_1(Xh2_1), .h2_2(Xh2_2), .h2_3(Xh2_3),
                            .h3_1(Xh3_1), .h3_2(Xh3_2), .h3_3(Xh3_3),
                            .h4_1(Xh4_1), .h4_2(Xh4_2), .h4_3(Xh4_3),
                            .h5_1(Xh5_1), .h5_2(Xh5_2), .h5_3(Xh5_3),
                            .h6_1(Xh6_1), .h6_2(Xh6_2), .h6_3(Xh6_3),
                            .h7_1(Xh7_1), .h7_2(Xh7_2), .h7_3(Xh7_3),
                            .h1_shft_dir(Xh1_shft_dir), .h2_shft_dir(Xh2_shft_dir), .h3_shft_dir(Xh3_shft_dir),
                            .h4_shft_dir(Xh4_shft_dir), .h5_shft_dir(Xh5_shft_dir), .h6_shft_dir(Xh6_shft_dir), 
                            .h7_shft_dir(Xh7_shft_dir), .normalize(Xnormalize),
                            .en_xout(R_en_xout), .out_p(outX_R));

    polyphase_fir_x G_Xfir( .clk(clk), .rst_n(rst_n), .stream_in(stream_in), .Xout_rdy(Xout_rdy), .sel(cnt_load_x), .cur_p(cur_G), 
                            .h1_1(Xh1_1), .h1_2(Xh1_2), .h1_3(Xh1_3),
                            .h2_1(Xh2_1), .h2_2(Xh2_2), .h2_3(Xh2_3),
                            .h3_1(Xh3_1), .h3_2(Xh3_2), .h3_3(Xh3_3),
                            .h4_1(Xh4_1), .h4_2(Xh4_2), .h4_3(Xh4_3),
                            .h5_1(Xh5_1), .h5_2(Xh5_2), .h5_3(Xh5_3),
                            .h6_1(Xh6_1), .h6_2(Xh6_2), .h6_3(Xh6_3),
                            .h7_1(Xh7_1), .h7_2(Xh7_2), .h7_3(Xh7_3),
                            .h1_shft_dir(Xh1_shft_dir), .h2_shft_dir(Xh2_shft_dir), .h3_shft_dir(Xh3_shft_dir),
                            .h4_shft_dir(Xh4_shft_dir), .h5_shft_dir(Xh5_shft_dir), .h6_shft_dir(Xh6_shft_dir), 
                            .h7_shft_dir(Xh7_shft_dir), .normalize(Xnormalize),
                            .en_xout(G_en_xout), .out_p(outX_G));

    polyphase_fir_x B_Xfir( .clk(clk), .rst_n(rst_n), .stream_in(stream_in), .Xout_rdy(Xout_rdy), .sel(cnt_load_x), .cur_p(cur_B), 
                            .h1_1(Xh1_1), .h1_2(Xh1_2), .h1_3(Xh1_3),
                            .h2_1(Xh2_1), .h2_2(Xh2_2), .h2_3(Xh2_3),
                            .h3_1(Xh3_1), .h3_2(Xh3_2), .h3_3(Xh3_3),
                            .h4_1(Xh4_1), .h4_2(Xh4_2), .h4_3(Xh4_3),
                            .h5_1(Xh5_1), .h5_2(Xh5_2), .h5_3(Xh5_3),
                            .h6_1(Xh6_1), .h6_2(Xh6_2), .h6_3(Xh6_3),
                            .h7_1(Xh7_1), .h7_2(Xh7_2), .h7_3(Xh7_3),
                            .h1_shft_dir(Xh1_shft_dir), .h2_shft_dir(Xh2_shft_dir), .h3_shft_dir(Xh3_shft_dir),
                            .h4_shft_dir(Xh4_shft_dir), .h5_shft_dir(Xh5_shft_dir), .h6_shft_dir(Xh6_shft_dir), 
                            .h7_shft_dir(Xh7_shft_dir), .normalize(Xnormalize),
                            .en_xout(B_en_xout), .out_p(outX_B));


    reg [`MAX_ROW_LOG2-1:0] cnt_row_pxl;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            cnt_row_pxl <= 0;
        else if (cnt_row_pxl==(tar_width))
            cnt_row_pxl <= 0;
        else if (Xout_rdy) 
            cnt_row_pxl <= cnt_row_pxl + 1;
    end

    reg flag_cnt_row_pxl;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            flag_cnt_row_pxl <= 0;
        else if (cnt_row_pxl == tar_width)
            flag_cnt_row_pxl <= 0;
        else if (data_enable)
            flag_cnt_row_pxl <= 1;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            ERROR_FLAG <= 0;
        else if (hsync && flag_cnt_row_pxl) begin
            ERROR_FLAG <= 1;
            $display("Error: lost pixel while verifying hsync; DUE freeze.");
        end
    end


    reg [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] cnt_num_rows;

    reg Yin_rdy;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            Yin_rdy <= 0;
        else if (cnt_num_rows == y_window-1) 
            Yin_rdy <= 1;
        else     
            Yin_rdy <= 0;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            cnt_num_rows <= 0;
        else if (cnt_row_pxl==(tar_width)) begin
            if (cnt_num_rows == y_window-1) 
                cnt_num_rows <= 0;
            else 
                cnt_num_rows <= cnt_num_rows + 1;
        end
    end


   
    reg wr_buf1, wr_buf2, wr_buf3, wr_buf4;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            wr_buf1 <= 0;
            wr_buf2 <= 0;
            wr_buf3 <= 0;
            wr_buf4 <= 0;      
        end
        else begin
            wr_buf1 <= Xout_rdy && (cnt_num_rows==0) && (!Yin_rdy);
            wr_buf2 <= Xout_rdy && (cnt_num_rows==1) && (!Yin_rdy);
            wr_buf3 <= Xout_rdy && (cnt_num_rows==2) && (!Yin_rdy);
            wr_buf4 <= Xout_rdy && (cnt_num_rows==3) && (!Yin_rdy);
        end
    end


    reg Ycolumn_rdy;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            Ycolumn_rdy <= 0;
        else if (Yin_rdy && Xout_rdy)
            Ycolumn_rdy <= 1;
        else 
            Ycolumn_rdy <= 0;
    end


    reg [3:0] all_rd_buf;
    wire [3:0] ext_Ycolumn_rdy;
    assign ext_Ycolumn_rdy = {4{Ycolumn_rdy}};
    always @(*) begin
        case (cnt_num_rows)
            0:  all_rd_buf = {4'b0000};
            1:  all_rd_buf = {4'b0001};
            2:  all_rd_buf = {4'b0011};
            3:  all_rd_buf = {4'b0111};
            4:  all_rd_buf = {4'b1111};
            default:
                all_rd_buf = 0;
        endcase
    end


    wire rd_buf1, rd_buf2, rd_buf3, rd_buf4;
    assign {rd_buf4, rd_buf3, rd_buf2, rd_buf1} = all_rd_buf & ext_Ycolumn_rdy;

    wire [7:0] Rbuf1_out, Rbuf2_out, Rbuf3_out, Rbuf4_out, Rbuf5_out; 
    tmp_row_buffer Rbuf1( .clk(clk), .rst_n(rst_n), .in_data(outX_R), .wr_en(wr_buf1), .rd_en(rd_buf1), .out_data(Rbuf1_out));  
    tmp_row_buffer Rbuf2( .clk(clk), .rst_n(rst_n), .in_data(outX_R), .wr_en(wr_buf2), .rd_en(rd_buf2), .out_data(Rbuf2_out));  
    tmp_row_buffer Rbuf3( .clk(clk), .rst_n(rst_n), .in_data(outX_R), .wr_en(wr_buf3), .rd_en(rd_buf3), .out_data(Rbuf3_out));  
    tmp_row_buffer Rbuf4( .clk(clk), .rst_n(rst_n), .in_data(outX_R), .wr_en(wr_buf4), .rd_en(rd_buf4), .out_data(Rbuf4_out));  

    wire [7:0] Gbuf1_out, Gbuf2_out, Gbuf3_out, Gbuf4_out, Gbuf5_out; 
    tmp_row_buffer Gbuf1( .clk(clk), .rst_n(rst_n), .in_data(outX_G), .wr_en(wr_buf1), .rd_en(rd_buf1), .out_data(Gbuf1_out));  
    tmp_row_buffer Gbuf2( .clk(clk), .rst_n(rst_n), .in_data(outX_G), .wr_en(wr_buf2), .rd_en(rd_buf2), .out_data(Gbuf2_out));  
    tmp_row_buffer Gbuf3( .clk(clk), .rst_n(rst_n), .in_data(outX_G), .wr_en(wr_buf3), .rd_en(rd_buf3), .out_data(Gbuf3_out));  
    tmp_row_buffer Gbuf4( .clk(clk), .rst_n(rst_n), .in_data(outX_G), .wr_en(wr_buf4), .rd_en(rd_buf4), .out_data(Gbuf4_out));  

    wire [7:0] Bbuf1_out, Bbuf2_out, Bbuf3_out, Bbuf4_out, Bbuf5_out; 
    tmp_row_buffer Bbuf1( .clk(clk), .rst_n(rst_n), .in_data(outX_B), .wr_en(wr_buf1), .rd_en(rd_buf1), .out_data(Bbuf1_out));  
    tmp_row_buffer Bbuf2( .clk(clk), .rst_n(rst_n), .in_data(outX_B), .wr_en(wr_buf2), .rd_en(rd_buf2), .out_data(Bbuf2_out));  
    tmp_row_buffer Bbuf3( .clk(clk), .rst_n(rst_n), .in_data(outX_B), .wr_en(wr_buf3), .rd_en(rd_buf3), .out_data(Bbuf3_out));  
    tmp_row_buffer Bbuf4( .clk(clk), .rst_n(rst_n), .in_data(outX_B), .wr_en(wr_buf4), .rd_en(rd_buf4), .out_data(Bbuf4_out));  

    reg latch_Ycolumn_rdy;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            latch_Ycolumn_rdy <= 0;
        else 
            latch_Ycolumn_rdy <= Ycolumn_rdy;
    end

    reg [3:0] all_buf_out_rdy;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            all_buf_out_rdy <= 0;
        else
            all_buf_out_rdy <= all_rd_buf;
    end

    reg [7:0] latch_outX_R, latch_outX_B, latch_outX_G;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            {latch_outX_R, latch_outX_B, latch_outX_G} <= 0;
        else if (Ycolumn_rdy) begin
            latch_outX_R <= outX_R;
            latch_outX_B <= outX_B;
            latch_outX_G <= outX_G;
        end
    end


    wire [7:0] RYin1, RYin2, RYin3, RYin4, RYin5; 

    assign RYin1 = Rbuf1_out;
    assign RYin2 = all_buf_out_rdy[1] ? Rbuf2_out : (all_buf_out_rdy[0] ? latch_outX_R : 0);
    assign RYin3 = all_buf_out_rdy[2] ? Rbuf3_out : (all_buf_out_rdy[1] ? latch_outX_R : 0);
    assign RYin4 = all_buf_out_rdy[3] ? Rbuf4_out : (all_buf_out_rdy[2] ? latch_outX_R : 0);
    assign RYin5 = (all_buf_out_rdy[3] ? latch_outX_R : 0);
    

    wire [7:0] GYin1, GYin2, GYin3, GYin4, GYin5; 
 
    assign GYin1 = Gbuf1_out;
    assign GYin2 = all_buf_out_rdy[1] ? Gbuf2_out : (all_buf_out_rdy[0] ? latch_outX_G : 0);
    assign GYin3 = all_buf_out_rdy[2] ? Gbuf3_out : (all_buf_out_rdy[1] ? latch_outX_G : 0);
    assign GYin4 = all_buf_out_rdy[3] ? Gbuf4_out : (all_buf_out_rdy[2] ? latch_outX_G : 0);
    assign GYin5 = (all_buf_out_rdy[3] ? latch_outX_G : 0);


    wire [7:0] BYin1, BYin2, BYin3, BYin4, BYin5; 
 
    assign BYin1 = Bbuf1_out;
    assign BYin2 = all_buf_out_rdy[1] ? Bbuf2_out : (all_buf_out_rdy[0] ? latch_outX_B : 0);
    assign BYin3 = all_buf_out_rdy[2] ? Bbuf3_out : (all_buf_out_rdy[1] ? latch_outX_B : 0);
    assign BYin4 = all_buf_out_rdy[3] ? Bbuf4_out : (all_buf_out_rdy[2] ? latch_outX_B : 0);
    assign BYin5 = (all_buf_out_rdy[3] ? latch_outX_B : 0);


    
    reg en_loadY;
    always @(negedge clk, negedge rst_n) begin
        if (!rst_n) 
            en_loadY <= 0;
        else if (all_buf_out_rdy==0 && Yin_rdy) 
            en_loadY <= 0;
        else
            en_loadY <= latch_Ycolumn_rdy;
    end

    wire R_en_yout, G_en_yout, B_en_yout;
    wire [7:0] pixelR, pixelG, pixelB;
    
    mac_y R_Yfir( .clk(clk), .rst_n(rst_n), .en_load(en_loadY), 
        .br1P(RYin1), .br2P(RYin2), .br3P(RYin3), .br4P(RYin4), .br5P(RYin5),
        .h1_1(Yh1_1), .h1_2(Yh1_2), .h1_3(Yh1_3),
        .h2_1(Yh2_1), .h2_2(Yh2_2), .h2_3(Yh2_3),
        .h3_1(Yh3_1), .h3_2(Yh3_2), .h3_3(Yh3_3),
        .h4_1(Yh4_1), .h4_2(Yh4_2), .h4_3(Yh4_3),
        .h5_1(Yh5_1), .h5_2(Yh5_2), .h5_3(Yh5_3),
        .h1_shft_dir(Yh1_shft_dir), .h2_shft_dir(Yh2_shft_dir), .h3_shft_dir(Yh3_shft_dir),
        .h4_shft_dir(Yh4_shft_dir), .h5_shft_dir(Yh5_shft_dir), .normalize(Ynormalize),
        .en_yout(R_en_yout), .out_p(pixelR));

    mac_y G_Yfir( .clk(clk), .rst_n(rst_n), .en_load(en_loadY), 
        .br1P(GYin1), .br2P(GYin2), .br3P(GYin3), .br4P(GYin4), .br5P(GYin5),
        .h1_1(Yh1_1), .h1_2(Yh1_2), .h1_3(Yh1_3),
        .h2_1(Yh2_1), .h2_2(Yh2_2), .h2_3(Yh2_3),
        .h3_1(Yh3_1), .h3_2(Yh3_2), .h3_3(Yh3_3),
        .h4_1(Yh4_1), .h4_2(Yh4_2), .h4_3(Yh4_3),
        .h5_1(Yh5_1), .h5_2(Yh5_2), .h5_3(Yh5_3),
        .h1_shft_dir(Yh1_shft_dir), .h2_shft_dir(Yh2_shft_dir), .h3_shft_dir(Yh3_shft_dir),
        .h4_shft_dir(Yh4_shft_dir), .h5_shft_dir(Yh5_shft_dir), .normalize(Ynormalize),
        .en_yout(G_en_yout), .out_p(pixelG));

    mac_y B_Yfir( .clk(clk), .rst_n(rst_n), .en_load(en_loadY), 
        .br1P(BYin1), .br2P(BYin2), .br3P(BYin3), .br4P(BYin4), .br5P(BYin5),
        .h1_1(Yh1_1), .h1_2(Yh1_2), .h1_3(Yh1_3),
        .h2_1(Yh2_1), .h2_2(Yh2_2), .h2_3(Yh2_3),
        .h3_1(Yh3_1), .h3_2(Yh3_2), .h3_3(Yh3_3),
        .h4_1(Yh4_1), .h4_2(Yh4_2), .h4_3(Yh4_3),
        .h5_1(Yh5_1), .h5_2(Yh5_2), .h5_3(Yh5_3),
        .h1_shft_dir(Yh1_shft_dir), .h2_shft_dir(Yh2_shft_dir), .h3_shft_dir(Yh3_shft_dir),
        .h4_shft_dir(Yh4_shft_dir), .h5_shft_dir(Yh5_shft_dir), .normalize(Ynormalize),
        .en_yout(B_en_yout), .out_p(pixelB));

    

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            en_output <= 0;
        else if (all_buf_out_rdy==0 && Yin_rdy) begin
            en_output <= (R_en_xout & G_en_xout & B_en_xout);
        end
        else begin
            en_output <= (R_en_yout & G_en_yout & B_en_yout);
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            out_B <= 0;
            out_G <= 0;
            out_R <= 0;
        end
        else if (all_buf_out_rdy==0 && Yin_rdy) begin
            out_B <= outX_B;
            out_G <= outX_G;
            out_R <= outX_R;
        end
        else begin
            out_B <= pixelB;
            out_G <= pixelG;
            out_R <= pixelR;
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            out_num_counter <= 0;
        else if (out_num_counter == tar_width)
            out_num_counter <= 0;
        else if (en_output)
            out_num_counter <= out_num_counter + 1;
    end

    reg [`MAX_COL_LOG2-1:0] out_row_counter;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            out_row_counter <= 0;
        else if (out_row_counter == tar_height)
            out_row_counter <= 0;
        else if (out_num_counter == tar_width)
            out_row_counter <= out_row_counter + 1;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            frame_done <= 0;
        else if (out_row_counter == tar_height && tar_height!=0)
            frame_done <= 1;
        else
            frame_done <= 0;
    end


endmodule
