package write_file;

    class WriteFrameFile;

        integer handle_R = 0;
        integer handle_G = 0;
        integer handle_B = 0;

        function new();
        endfunction

        task open_file(string filename);
            string R_filename = {filename, "_R.hex"};
            string G_filename = {filename, "_G.hex"};
            string B_filename = {filename, "_B.hex"};
            $display(R_filename);
            handle_R = $fopen(R_filename, "w");
            handle_G = $fopen(G_filename, "w");
            handle_B = $fopen(B_filename, "w");

            if (!handle_R || !handle_G || !handle_B)
                $warning("[Error]: failed to open output file.");
        endtask


        task write_pixel(string channel, logic [7:0] pixel);
            if (channel=="R")
                $fwrite(handle_R, "%h ", pixel);
            else if (channel=="G")
                $fwrite(handle_G, "%h ", pixel);
            else if (channel=="B")
                $fwrite(handle_B, "%h ", pixel);
            else 
                $display("Error: invalid input of write_pixel function.");
        endtask

        task write_string(string str);
            $fwrite(handle_R, str);
            $fwrite(handle_G, str);
            $fwrite(handle_B, str);
        endtask


        task flush_close();
            $fflush(handle_R); $fflush(handle_G); $fflush(handle_B);
            $fclose(handle_R); $fclose(handle_G); $fclose(handle_B);
        endtask


    endclass

endpackage
