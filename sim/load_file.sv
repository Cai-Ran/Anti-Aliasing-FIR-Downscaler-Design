
package load_file_pkg;

    class LoadFrameFile;

        int unsigned width;
        int unsigned height;
        logic [7:0] R_frame [];
        logic [7:0] G_frame [];
        logic [7:0] B_frame [];

        function new(int unsigned width, int unsigned height);
            this.width = width;
            this.height = height;
            this.R_frame = new[width * height];         //dynamic allocation
            this.G_frame = new[width * height];
            this.B_frame = new[width * height];
        endfunction

        // logic [7:0] R_frame [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];
        // logic [7:0] G_frame [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];
        // logic [7:0] B_frame [0: (`SRC_WIDTH*`SRC_HEIGHT)-1];

        // function new();
        // endfunction


        task read_file(string filename);
            string R_filename = {filename, "_R.hex"};
            string G_filename = {filename, "_G.hex"};
            string B_filename = {filename, "_B.hex"};
            $display(R_filename);
            $readmemh(R_filename, R_frame);
            $readmemh(G_filename, G_frame);
            $readmemh(B_filename, B_frame);
        endtask


    endclass

endpackage
