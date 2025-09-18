#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#pragma pack(push, 1)

#define MAX_WIDTH 4096

typedef struct {
    uint16_t bfType;
    uint32_t bfSize;
    uint16_t bfReserved1;
    uint16_t bfReserved2;
    uint32_t bfOffBits;
} BMPFileHeader;

typedef struct {
    uint32_t biSize;
    int32_t  biWidth;
    int32_t  biHeight;
    uint16_t biPlanes;
    uint16_t biBitCount;
    uint32_t biCompression;
    uint32_t biSizeImage;
    int32_t  biXPelsPerMeter;
    int32_t  biYPelsPerMeter;
    uint32_t biClrUsed;
    uint32_t biClrImportant;
} BMPInfoHeader;
#pragma pack(pop)

// -----------------------------------------------------------------------------------
// This implementation ONLY works correctly if the BMP image width is a multiple of 4.
// -----------------------------------------------------------------------------------

FILE *safe_fopen(const char *path, const char *mode) {
    FILE *fp = fopen(path, mode);
    if (!fp) {
        fprintf(stderr, "Error: Failed to open %s (%s)\n", path, strerror(errno));
        exit(EXIT_FAILURE);
    }
    return fp;
}

int main(int argc, char* argv[]) {
    setvbuf(stdout, NULL, _IONBF, 0);

    if (argc < 4) {
        printf("Error: Usage: %s [input_dir]\n", argv[0]);
        exit(1);
    }

    const char* hex_dir = argv[1];
    const char* file_name = argv[2];
    const char* bmp_dir = argv[3];
    char path_r[256], path_g[256], path_b[256], path_out[256];

    snprintf(path_r, sizeof(path_r), "%s/%s_R.hex", hex_dir, file_name);
    snprintf(path_g, sizeof(path_g), "%s/%s_G.hex", hex_dir, file_name);
    snprintf(path_b, sizeof(path_b), "%s/%s_B.hex", hex_dir, file_name);
    snprintf(path_out, sizeof(path_out), "%s/%s.bmp", bmp_dir, file_name);

    FILE *rf = safe_fopen(path_r, "r");
    FILE *gf = safe_fopen(path_g, "r");
    FILE *bf = safe_fopen(path_b, "r");
    FILE *bmpFile = safe_fopen(path_out, "wb");

    int row_pixels = MAX_WIDTH*3+5;    //0-255:((2 hex char)+blank)+\n+\r(windows)
    int width = 0, height = 0;  //cursor
    char line[row_pixels];
    int fst_line = 1;           //for strtok

 
    //get picture width and height
    while (fgets(line, sizeof(line), rf)) {
        if (fst_line) {
            char* token = strtok(line, " \n");
            while (token) {
                width++;
                token = strtok(NULL, " \n");
            }
            fst_line = 0;
        }
        height++;
    }

    rewind(rf); rewind(gf); rewind(bf);
    //Move an open file pointer back to the beginning of the file


    int rowBytes = (width * 3 + 3) & ~3;
    uint8_t *row = (uint8_t *)calloc(1, rowBytes);      //initialize to value 0
    if (!row) {
        printf("Error: malloc row failed.\n");
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }

    BMPFileHeader fileHeader = {
        .bfType = 0x4D42,       //bmp file signature
        .bfSize = sizeof(BMPFileHeader) + sizeof(BMPInfoHeader) + rowBytes * height,    //bmp file size
        .bfReserved1 = 0,       //must 0
        .bfReserved2 = 0,       //must 0
        .bfOffBits = sizeof(BMPFileHeader) + sizeof(BMPInfoHeader)      //pixel starting offset
    };
    BMPInfoHeader infoHeader = {
        .biSize = sizeof(BMPInfoHeader),
        .biWidth = width,           //picture width
        .biHeight = height,         //picture height
        .biPlanes = 1,              //must 1
        .biBitCount = 24,           //pixel bit depth
        .biCompression = 0,         
        .biSizeImage = rowBytes * height,       //picture all pixels size
        .biXPelsPerMeter = 0,
        .biYPelsPerMeter = 0,
        .biClrUsed = 0,
        .biClrImportant = 0
    };


    int wr_fileHeader = fwrite(&fileHeader, sizeof(fileHeader), 1, bmpFile);
    int wr_infoHeader = fwrite(&infoHeader, sizeof(infoHeader), 1, bmpFile);
    if (wr_fileHeader!=1 || wr_infoHeader!=1) {
        perror("Error: failed to write bmp header.\n");
        free(row);
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }


    //start to read hex
    uint8_t* bmpBytesBuffer = (uint8_t*)malloc( height * rowBytes );
    if (!bmpBytesBuffer) {
        printf("Error: malloc bmpBytesBuffer failed.\n");
        free(row); 
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }


    for (int y = height-1; y >= 0; --y) {
        for (int x = 0; x < width; x++) {

            char r_hex[3], g_hex[3], b_hex[3];

            if (fscanf(rf, "%2s", r_hex) != 1 ||
                fscanf(gf, "%2s", g_hex) != 1 ||
                fscanf(bf, "%2s", b_hex) != 1) {
                printf("Error: failed to read hex at (x=%d, y=%d)\n", x, height-y);
                free(row); free(bmpBytesBuffer);
                fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
                exit(1);
            }

            r_hex[2] = g_hex[2] = b_hex[2] = '\0';

            uint8_t r, g, b;
            int ck_b, ck_g, ck_r;
            ck_b = sscanf(b_hex, "%2hhx", &b);
            ck_g = sscanf(g_hex, "%2hhx", &g);
            ck_r = sscanf(r_hex, "%2hhx", &r);
            if (!ck_b) {printf("Error: hex_to_byte B sscanf fail: '%s'\n", b_hex);}
            if (!ck_g) {printf("Error: hex_to_byte G sscanf fail: '%s'\n", g_hex);}
            if (!ck_r) {printf("Error: hex_to_byte R sscanf fail: '%s'\n", r_hex);}
            if (!ck_b || !ck_g || !ck_r) {
                free(row); free(bmpBytesBuffer);
                fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
                exit(1);
            }


            row[x * 3 + 0] = b;
            row[x * 3 + 1] = g;
            row[x * 3 + 2] = r;
            
        }
        int rowBytesIdx = y*rowBytes;
        memcpy(bmpBytesBuffer+rowBytesIdx, row, rowBytes);
    }

    int once = fwrite(bmpBytesBuffer, rowBytes*height, 1, bmpFile);
    if (once != 1) {
        perror("Error: failed to write bmp pixels.\n");
        free(row); free(bmpBytesBuffer);
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }

    free(row);
    free(bmpBytesBuffer);
    fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
    printf("BMP restored to: %s size=(%dx%d)\n", path_out, width, height);
    return 0;
}
