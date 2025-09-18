#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#pragma pack(push, 1)

#define MAX_XWINDOW_LEN 2048      //fst number: window_list length
#define MAX_YWINDOW_LEN 2048      //snd number: REPEATX/REPEATY

void get_window_values(const char* Xwindow_path, const char* Ywindow_path, int* xwindow_array, int* ywindow_array);
uint8_t* get_src_pixel(const char* path, int src_width, int src_height);
void generateX_golden(uint8_t* frame, const char* path, const int src_width, const int src_height, const int tar_width,
                        int* xwindow_array, uint8_t* tar_Xdown_frame);
void generateY_golden(uint8_t* tar_Xdown_frame, const char* path, const int src_width, const int src_height, const int tar_width, const int tar_height,
                        int* ywindow_array, uint8_t* tar_frame);
uint8_t shift_multiply(int window_size, uint8_t p1, uint8_t p2, uint8_t p3, 
                        uint8_t p4, uint8_t p5, uint8_t p6, uint8_t p7);


int main(int argc, char* argv[]) {
    // setvbuf(stdout, NULL, _IONBF, 0);
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);

    if (argc < 10) {
        printf("Usage: <src_hex_dir> <hex_file_name> <golden_hex_dir> <window_data_dir> <postfix> <src_w> <src_h> <tar_w> <tar_h>\n");
        exit(1);
    }

    const char* src_hex_dir = argv[1];
    const char* hex_file_name = argv[2];
    const char* golden_hex_dir = argv[3];
    const char* window_data_dir = argv[4];
    const char* postfix = argv[5];
    const int src_width = atoi(argv[6]);
    const int src_height = atoi(argv[7]);
    const int tar_width = atoi(argv[8]);
    const int tar_height = atoi(argv[9]);

    char Xwindow_file_path[128], Ywindow_file_path[128];
    snprintf(Xwindow_file_path, sizeof(Xwindow_file_path), "%s/%dx%d_%dx%d_Xwindow.txt", window_data_dir, src_width, src_height, tar_width, tar_height);
    snprintf(Ywindow_file_path, sizeof(Ywindow_file_path), "%s/%dx%d_%dx%d_Ywindow.txt", window_data_dir, src_width, src_height, tar_width, tar_height);
    int xwindow_array[MAX_XWINDOW_LEN];
    int ywindow_array[MAX_YWINDOW_LEN];
    get_window_values(Xwindow_file_path, Ywindow_file_path, xwindow_array, ywindow_array);


    char in_path_r[256], in_path_g[256], in_path_b[256];
    snprintf(in_path_r, sizeof(in_path_r), "%s/%s_R.hex", src_hex_dir, hex_file_name);
    snprintf(in_path_g, sizeof(in_path_g), "%s/%s_G.hex", src_hex_dir, hex_file_name);
    snprintf(in_path_b, sizeof(in_path_b), "%s/%s_B.hex", src_hex_dir, hex_file_name);

    char outx_path_r[256], outx_path_g[256], outx_path_b[256];
    char goldenX_filename[50];
    snprintf(goldenX_filename, sizeof(goldenX_filename), "%dx%d-%dx%d_%s", src_width, src_height, tar_width, src_height, postfix);
    snprintf(outx_path_r, sizeof(outx_path_r), "%s/%s_R.hex", golden_hex_dir, goldenX_filename);
    snprintf(outx_path_g, sizeof(outx_path_g), "%s/%s_G.hex", golden_hex_dir, goldenX_filename);
    snprintf(outx_path_b, sizeof(outx_path_b), "%s/%s_B.hex", golden_hex_dir, goldenX_filename);

    char outy_path_r[256], outy_path_g[256], outy_path_b[256];
    char golden_filename[50];
    snprintf(golden_filename, sizeof(golden_filename), "%dx%d_%dx%d_%s", src_width, src_height, tar_width, tar_height, postfix);
    snprintf(outy_path_r, sizeof(outy_path_r), "%s/%s_R.hex", golden_hex_dir, golden_filename);
    snprintf(outy_path_g, sizeof(outy_path_g), "%s/%s_G.hex", golden_hex_dir, golden_filename);
    snprintf(outy_path_b, sizeof(outy_path_b), "%s/%s_B.hex", golden_hex_dir, golden_filename);

    char* in_path[] = {in_path_b, in_path_g, in_path_r};
    char* outx_path[] = {outx_path_b, outx_path_g, outx_path_r};
    char* outy_path[] = {outy_path_b, outy_path_g, outy_path_r};



    for (int c=0; c<3; c++) {
        uint8_t* frame = get_src_pixel(in_path[c], src_width, src_height);
        if (!frame) {
            printf("Error: get_src_pixel failed\n");
            exit(1);
        }
        uint8_t* tar_Xdown_frame = (uint8_t*)malloc(src_height * tar_width);
        if (!tar_Xdown_frame) {
            printf("Error: malloc tar_Xdown_frame failed\n");
            free(frame); exit(1);
        }
        uint8_t* tar_frame = (uint8_t*)malloc(tar_height * tar_width);
        if (!tar_frame) {
            printf("Error: malloc tar_frame failed\n");
            free(frame); free(tar_Xdown_frame); exit(1);
        }
        generateX_golden(frame, outx_path[c], src_width, src_height, tar_width, xwindow_array, tar_Xdown_frame);
        generateY_golden(tar_Xdown_frame, outy_path[c], src_width, src_height, tar_width, tar_height, ywindow_array, tar_frame);
        free(frame);
        free(tar_Xdown_frame);
        free(tar_frame);
    }


    return 0;
}

void get_window_values(const char* Xwindow_path, const char* Ywindow_path, int* xwindow_array, int* ywindow_array) {

    FILE* Xwindow_file = fopen(Xwindow_path, "r");
    FILE* Ywindow_file = fopen(Ywindow_path, "r");
    if (!Xwindow_file || !Ywindow_file) {
        printf("Error: cannot open window file\n");
        exit(1);
    }

    int x_count = 0;
    while (x_count < MAX_XWINDOW_LEN && fscanf(Xwindow_file, "%d", &xwindow_array[x_count]) == 1) {
        x_count ++;
    }
    if (x_count == MAX_XWINDOW_LEN) {
        printf("Warning: Xwindow array reached max size (%d), input may be truncated\n", MAX_XWINDOW_LEN);
    }
    fclose(Xwindow_file);

    int y_count = 0;
    while (y_count < MAX_YWINDOW_LEN && fscanf(Ywindow_file, "%d", &ywindow_array[y_count]) == 1) {
        y_count ++;
    }
    if (y_count == MAX_YWINDOW_LEN) {
        printf("Warning: Ywindow array reached max size (%d), input may be truncated\n", MAX_YWINDOW_LEN);
    }
    fclose(Ywindow_file);
}


uint8_t* get_src_pixel(const char* path, int src_width, int src_height) {

    FILE* in_file = fopen(path, "r");
    if (!in_file) {
        printf("Error: failed to open src hex: %s\n", path);
        return NULL;
    }

    uint8_t* row = (uint8_t*)calloc(1, src_width);
    if (!row) {
        printf("Error: calloc row failed\n");
        fclose(in_file);
        return NULL;
    }

    uint8_t* frameBuffer = (uint8_t*)malloc(src_height * src_width);
    if (!frameBuffer) {
        printf("Error: malloc frameBuffer failed\n");
        fclose(in_file); free(row);
        return NULL;
    }


    for (int y=0; y < src_height; y++) {
        for (int x=0; x < src_width; x++) {

            char hex[3];
            if (fscanf(in_file, "%2s", hex)!=1) {
                printf("Error: Failed to read hex at: (x=%d, y=%d)", x, y);
                fclose(in_file); free(row); free(frameBuffer);
                return NULL;
            }

            hex[2]='\0';

            uint8_t value;  int ck;
            ck = sscanf(hex, "%2hhx", &value);
            if (!ck) {
                printf("Error: failed to convert hex: %s\n", hex);
                fclose(in_file); free(row); free(frameBuffer);
                return NULL;
            }

            row[x] = value;
        }

        memcpy(frameBuffer + y*src_width, row, src_width);

    }
    free(row);
    return frameBuffer;
}



void generateX_golden(uint8_t* frame, const char* path, 
    const int src_width, const int src_height, const int tar_width,
    int* xwindow_array, uint8_t* tar_Xdown_frame) {

    FILE* outX_f = fopen(path, "w");

    // int X_ratio = (int)ceil((double)src_width / tar_width);
    int X_ratio = (src_width + tar_width - 1)/tar_width;
    
    int x_len = xwindow_array[0];
    int repeatx = xwindow_array[1];
    
    for (int y=0; y<src_height; y++) {
        int curXidx = 0;
        int tarXidx = 0;

        for (int rx=0; rx<repeatx; rx++) {
            for (int xw=2; xw<x_len+2; xw++) {
                if (xwindow_array[xw]>X_ratio) { printf("Error: wrong xwindow_size=%d, X_ratio=%d\n", xwindow_array[xw], X_ratio);}
                if (curXidx + xwindow_array[xw] > src_width) { printf("Error: curXidx+window (%d) exceeds src_width (%d) at line y=%d\n", curXidx + 6, src_width, y);}
                uint8_t outX;
                uint8_t p1 = frame[y*src_width + curXidx+0];
                uint8_t p2 = (xwindow_array[xw]>=2) ? frame[y*src_width + curXidx+1] : 0;
                uint8_t p3 = (xwindow_array[xw]>=3) ? frame[y*src_width + curXidx+2] : 0;
                uint8_t p4 = (xwindow_array[xw]>=4) ? frame[y*src_width + curXidx+3] : 0;
                uint8_t p5 = (xwindow_array[xw]>=5) ? frame[y*src_width + curXidx+4] : 0;
                uint8_t p6 = (xwindow_array[xw]>=6) ? frame[y*src_width + curXidx+5] : 0;
                uint8_t p7 = (xwindow_array[xw]==7) ? frame[y*src_width + curXidx+6] : 0;

                outX = shift_multiply(xwindow_array[xw], p1, p2, p3, p4, p5, p6, p7);

                fprintf(outX_f, "%02x ", outX);
                tar_Xdown_frame[y*tar_width + tarXidx] = outX;

                curXidx += xwindow_array[xw];
                tarXidx += 1;
            }
        }
        fprintf(outX_f, "\n");

        if (curXidx!=src_width) {printf("Error: curXidx=%d should be src_width=%d\n", curXidx, src_width);}
        if (tarXidx!=tar_width) {printf("Error: tarXidx=%d should be tar_width=%d\n", tarXidx, tar_width);}

    }

    fclose(outX_f);
}


void generateY_golden(uint8_t* tar_Xdown_frame, const char* path,
    const int src_width, const int src_height, const int tar_width, const int tar_height,
    int* ywindow_array, uint8_t* tar_frame) {

    int y_len = ywindow_array[0];
    int repeaty = ywindow_array[1];
    
    int Y_ratio = (src_height + tar_height - 1) / tar_height;

    for (int tx=0; tx<tar_width; tx++) {
        int curYidx = 0;
        int tarYidx = 0;
        for (int ry=0; ry<repeaty; ry++) {
            for (int yw=2; yw<y_len+2; yw++) {

                if (ywindow_array[yw]>Y_ratio) {printf("Error: wrong ywindow_size=%d, Y_ratio=%d\n", ywindow_array[yw], Y_ratio);}
                if (curYidx + ywindow_array[yw] > src_height) {printf("Error: curYidx+window (%d) exceeds src_height (%d) at tx=%d\n", curYidx + 4, src_height, tx);}
                uint8_t outP;
                uint8_t p1 = tar_Xdown_frame[ (curYidx+0) * tar_width + tx];
                uint8_t p2 = (ywindow_array[yw]>=2) ? tar_Xdown_frame[ (curYidx+1) * tar_width + tx] : 0;
                uint8_t p3 = (ywindow_array[yw]>=3) ? tar_Xdown_frame[ (curYidx+2) * tar_width + tx] : 0;
                uint8_t p4 = (ywindow_array[yw]>=4) ? tar_Xdown_frame[ (curYidx+3) * tar_width + tx] : 0;
                uint8_t p5 = (ywindow_array[yw]==5) ? tar_Xdown_frame[ (curYidx+4) * tar_width + tx] : 0;

                outP = shift_multiply(ywindow_array[yw], p1, p2, p3, p4, p5, 0, 0);
                tar_frame[tarYidx * tar_width + tx] = outP;

                curYidx += ywindow_array[yw];
                tarYidx += 1;
            }
        }
        if (curYidx!=src_height) {printf("Error: curYidx=%d should be src_height=%d\n", curYidx, src_height);}
        if (tarYidx!=tar_height) {printf("Error: tarYidx=%d should be tar_height=%d\n", tarYidx, tar_height);}

    }

    FILE* out_f = fopen(path, "w");
    for (int ty=0; ty<tar_height; ty++) {
        for (int tx=0; tx<tar_width; tx++) {
            uint8_t outp = tar_frame[ty*tar_width + tx];
            fprintf(out_f, "%02x ", outp);
        }
        fprintf(out_f, "\n");
    }
    fclose(out_f);
}


uint8_t shift_multiply(int window_size, uint8_t p1, uint8_t p2, uint8_t p3, 
                        uint8_t p4, uint8_t p5, uint8_t p6, uint8_t p7) {

    uint8_t outp;

    switch (window_size) {
        case 7:
            outp = ( (p1>>2) + (p2>>1) + ((p3>>1)+(p3>>2)) + p4 +  ((p5>>1)+(p5>>2)) + (p6>>1) + (p7>>2) ) >> 2;
            break;
        case 6:
            outp = ( (p1>>2) + ((p2>>1)+(p2>>2)) + p3 + p4 + ((p5>>1)+(p5>>2)) + (p6>>2) ) >> 2;
            break;
        case 5:
            outp = ( ((p1<<1)+p1) + ((p2<<1)+p2+(p2>>2)) + ((p3<<1)+p3+(p3>>1)) + ((p4<<1)+p4+(p4>>2)) + ((p5<<1)+p5) ) >> 4;
            break;
        case 4:
            outp = ( (p1+(p1>>1)+(p1>>2)) + ((p2<<1)+(p2>>2)) + ((p3<<1)+(p3>>2)) + (p4+(p4>>1)+(p4>>2)) ) >> 3;
            break;
        case 3:
            outp = ( (p1+(p1>>2)) + (p2+(p2>>1)) + (p3+(p3>>2)) ) >> 2;
            break;
        case 2:
            outp = (p1 + p2) >> 1;
            break;
        case 1:
            outp = p1;
            break;

        default:
            printf("Error: wrong window_size value: %d\n", window_size);
            break;
    }

    if (outp > 255 || outp < 0) {printf("ERROR: wrong pixel value: %d\n", outp);}
    return outp;
}
