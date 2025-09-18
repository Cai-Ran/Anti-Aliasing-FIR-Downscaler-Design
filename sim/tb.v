`define DEBUG_HANG
`define SIM
`define DUMP_WAVE
`define VALIDATION_MODE

`include `CONFIG_FILE

`timescale 1ps/1ps


`include "./rtl/downsample_scaler.v"
`include "./sim/validate.v"


module tb();

    reg clk;
    reg rst_n;

    always #`HALF_PERIOD clk = ~clk;

    event done_reset;
    initial begin
        clk = 1;
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        -> done_reset;
        // $display("[Info] Trigger done_reset at %t", $time);
    end



    reg [7:0] data_stream_R [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];
    reg [7:0] data_stream_G [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];
    reg [7:0] data_stream_B [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];

    reg [7:0] golden_frame_R [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];
    reg [7:0] golden_frame_G [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];
    reg [7:0] golden_frame_B [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];

    reg [64*8-1:0] filename;  //64 char
    integer fR, fG, fB;
    initial begin
        //SRC PIC INPUT HEX
        $sformat(filename, "%s/%0dx%0d_%s_B.hex", `IN_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        // $display("[Info] check input filename %s", filename);
        $readmemh(filename, data_stream_B);
        $sformat(filename, "%s/%0dx%0d_%s_G.hex", `IN_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        $readmemh(filename, data_stream_G);
        $sformat(filename, "%s/%0dx%0d_%s_R.hex", `IN_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        $readmemh(filename, data_stream_R);
        //GOLDEN HEX TO VERIFY DESIGN OUPUT
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_B.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        // $display("[Info] check input filename %s", filename);
        $readmemh(filename, golden_frame_B);
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_G.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        $readmemh(filename, golden_frame_G);
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_R.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        $readmemh(filename, golden_frame_R);
        //DESIGN OUTPUT
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_R.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        // $display("[Info] check output filename %s", filename);
        fR = $fopen(filename, "w");
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_G.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        fG = $fopen(filename, "w");
        $sformat(filename, "%s/%0dx%0d_%0dx%0d_%s_B.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        fB = $fopen(filename, "w");
        if (!fR || !fG || !fB) begin
            $warning("[Error] fopen output file failed");
            $finish;
        end
    end


    reg [7:0] output_buffer_R [(`TAR_WIDTH*`TAR_HEIGHT)-1:0];
    reg [7:0] output_buffer_G [(`TAR_WIDTH*`TAR_HEIGHT)-1:0];
    reg [7:0] output_buffer_B [(`TAR_WIDTH*`TAR_HEIGHT)-1:0];

    reg [7:0] cur_R;
    reg [7:0] cur_G;
    reg [7:0] cur_B;

    wire [7:0] out_R, out_G, out_B;

    reg data_enable;
    reg hsync, vsync;

    wire en_output;
    wire frame_done;
    
    wire  [`RESOLUTION_PAIR_LOG2-1:0] resolution_pair_idx;
    assign resolution_pair_idx = `RESOLUTION_PAIR_IDX;

    wire [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] X_factor;
    wire [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] Y_factor;
    assign X_factor = `X_DECIMATION_FACTOR;
    assign Y_factor = `Y_DECIMATION_FACTOR;

    wire [`MAX_ROW_LOG2-1:0] Tar_Width;
    assign Tar_Width = `TAR_WIDTH;

    wire [`MAX_COL_LOG2-1:0] Tar_Height;
    assign Tar_Height = `TAR_HEIGHT;


    downsample_scaler dut(.clk(clk), .rst_n(rst_n), .vsync(vsync), .hsync(hsync), .data_enable(data_enable), 
                            .cur_R(cur_R), .cur_G(cur_G), .cur_B(cur_B),
                            .resolution_pair_idx(resolution_pair_idx),
                            .X_factor(X_factor), .Y_factor(Y_factor), 
                            .tar_width(Tar_Width), .tar_height(Tar_Height),
                            .en_output(en_output), 
                            .out_R(out_R), .out_G(out_G), .out_B(out_B),
                            .frame_done(frame_done));

  

    integer sx, sy;
    initial begin    
        data_enable = 0;  
        vsync = 0;  
        @(done_reset);

        //VSYNC align HSYNC
        repeat(`VFRONT+1) @(posedge hsync);
        vsync <= 1;
        repeat(`VSYNC) @(posedge hsync);
        vsync <= 0;
        repeat(`VBACK-1) @(posedge hsync);

        for (sy=0; sy<`SRC_HEIGHT; sy=sy+1) begin 
            @(negedge hsync);
            repeat (`HBACK) @(posedge clk);
            data_enable <= 1;
            for (sx=0; sx<`SRC_WIDTH; sx=sx+1) begin
                /* 
                if (sy==50 && sx==`SRC_WIDTH-3) begin
                    repeat (100) @(posedge clk);
                    $display("[Info] VERIFY INPUT LOST PIXEL");
                end
                */
                cur_R <= data_stream_R[sy*`SRC_WIDTH + sx];
                cur_G <= data_stream_G[sy*`SRC_WIDTH + sx];
                cur_B <= data_stream_B[sy*`SRC_WIDTH + sx];
                @(posedge clk);
            end
            data_enable <= 0;
        end
    end

    integer total_lines;
    initial begin
        hsync = 0;
        @(done_reset);
        total_lines = `VFRONT + `VSYNC + `VBACK + `SRC_HEIGHT;

        repeat(total_lines) begin
            hsync <= 0;
            repeat(`HFRONT) @(posedge clk);
            hsync <= 1;
            repeat(`HSYNC) @(posedge clk);
            hsync <= 0;
            repeat(`HBACK) @(posedge clk);

            repeat(`SRC_WIDTH) @(posedge clk);
        end
    end

        

    reg FAIL_FLAG;
    integer p_cnt;
    wire [7:0] golden_B, golden_G, golden_R;
    assign golden_R = golden_frame_R[p_cnt];
    assign golden_G = golden_frame_G[p_cnt];
    assign golden_B = golden_frame_B[p_cnt];

    time frame_start, frame_end, frame_duration;

    initial begin
        p_cnt = 0;
        FAIL_FLAG = 0;
        @(done_reset);

        while (!frame_done) begin
            @(posedge clk);

            if (en_output) begin
                output_buffer_R[p_cnt] <= out_R;
                output_buffer_G[p_cnt] <= out_G;
                output_buffer_B[p_cnt] <= out_B;

                if (out_R!==golden_R || out_G!==golden_G || out_B!==golden_B) begin
                    FAIL_FLAG = 1;
                    $warning("[Error] output of DUT not match golden ref: p_cnt=%0d golden_R=%h, outR=%h, golden_G=%h, outG=%h, golden_B=%h, outB=%h",
                    p_cnt, golden_R, out_R, golden_G, out_G, golden_B, out_B);
                end
                if ((p_cnt+1)==1) begin
                    frame_start = $time;
                    $display("[Info] START frame %t", frame_start);
                end

                p_cnt <= (p_cnt+1);
                // $display("[Info] polyphase downscaler processed %d pixels", (p_cnt+1));

                if (^out_R === 1'bx || ^out_G === 1'bx || ^out_B === 1'bx) // out_R 有任意 bit 是 x 或 z，^out_R 會變成 x
                    $warning("[Error] wrong value of Yh and Ynormalize; pixel value exceed 255\n ");
            end
        end

        if (frame_done) begin
            if (p_cnt != `TAR_WIDTH*`TAR_HEIGHT) 
                $warning("[Error] wrong output count ");
            else begin
                frame_end = $time;
                $display("[Info] END frame %t", frame_end);
            end
        end
    end


    real frame_rate;
    integer out_idx;
    initial begin
        @(done_reset);

        out_idx = 0;
        while (!frame_done) begin
            @(posedge clk);
            if (p_cnt==out_idx+1) begin
                $fwrite(fR, "%h ", output_buffer_R[out_idx]);
                $fwrite(fG, "%h ", output_buffer_G[out_idx]);
                $fwrite(fB, "%h ", output_buffer_B[out_idx]);
                out_idx <= out_idx+1;

                if (p_cnt%`TAR_WIDTH==0) begin
                    $fwrite(fR, "\n");
                    $fwrite(fG, "\n");
                    $fwrite(fB, "\n");
                    // $display("[Info] Output %0d row to monitor...", p_cnt/`TAR_WIDTH);
                end
            end
        end


        if (p_cnt!=`TAR_HEIGHT*`TAR_WIDTH) begin
            $display("[Error] %0dx%0d_%0dx%0d FAILED", `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT);
        end

        
        $display("[Info] all pixels in output_buffers has been written to files.");
        $fflush(fR);$fflush(fG);$fflush(fB);
        $fclose(fR);$fclose(fG);$fclose(fB);

        if (FAIL_FLAG) begin
            $display("[Error] VERIFICATION FAILED!!!"); $finish;
        end else begin
            frame_duration = frame_end-frame_start;
            frame_rate = 1e12/frame_duration;
            $display("[Info] frame duration %t ps", frame_duration);
            $display("[Info] frame rate %.3f fps", frame_rate);


            $display("VERILOG_OUTPUT_DONE");    //for regression script
            $finish;
        end
    end
    
    `ifdef DEBUG_HANG
        parameter TB_TIMEOUT_CYCLES = `SRC_WIDTH*`SRC_HEIGHT*10;
        initial begin
            $display("[Info] VVP START: %0dx%0d_%0dx%0d", `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT);
            repeat(TB_TIMEOUT_CYCLES) @(posedge clk);
            if (p_cnt!=`TAR_HEIGHT*`TAR_WIDTH) begin
                $display("[ERROR] %0dx%0d_%0dx%0d TIME OUT", `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT);
            end
            $finish;
        end
    `endif 

    `ifdef DUMP_WAVE
        initial begin
            $dumpfile("wave.vcd");
            $dumpvars();
        end
    `endif 

endmodule
