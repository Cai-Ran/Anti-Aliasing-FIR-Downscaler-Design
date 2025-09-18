#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#pragma pack(push, 1)
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

int main(int argc, char* argv[]) {
    setvbuf(stdout, NULL, _IONBF, 0);

    if (argc < 3) {
        printf("Error: Usage: %s input.bmp output_dir\n", argv[0]);
        exit(1);
    }
    const char* bmp_path = argv[1];
    const char* output_dir = argv[2];

    FILE* bmpFile = fopen(bmp_path, "rb");
    if (!bmpFile) {
        printf("Error: Failed to open BMP file\n");
        exit(1);
    }

    BMPFileHeader fileHeader;
    BMPInfoHeader infoHeader;
    
    fread(&fileHeader, sizeof(fileHeader), 1, bmpFile);
    fread(&infoHeader, sizeof(infoHeader), 1, bmpFile);

    if (fileHeader.bfType != 0x4D42 ||
        infoHeader.biBitCount != 24 || infoHeader.biCompression != 0) {
        printf("Error: Only supports 24-bit uncompressed BMP.\n");
        fclose(bmpFile);
        exit(1);
    }

    char path_r[256], path_g[256], path_b[256];
    snprintf(path_r, sizeof(path_r), "%s_R.hex", output_dir);
    snprintf(path_g, sizeof(path_g), "%s_G.hex", output_dir);
    snprintf(path_b, sizeof(path_b), "%s_B.hex", output_dir);
    FILE *rf = fopen(path_r, "w");
    FILE *gf = fopen(path_g, "w");
    FILE *bf = fopen(path_b, "w");
    if (!rf || !gf || !bf) {
        printf("Error: failed to open output file.\n");
        if (rf) fclose(rf);
        if (gf) fclose(gf);
        if (bf) fclose(bf);
        fclose(bmpFile);
        exit(1);
    }

    int checkfseek = fseek(bmpFile, fileHeader.bfOffBits, SEEK_SET);
    if (checkfseek != 0) {
        printf("Error: fseek() failed! bfOffBits = %u is invalid.\n", fileHeader.bfOffBits);
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }

    int width = infoHeader.biWidth;
    int height = (infoHeader.biHeight>0) ? infoHeader.biHeight : -infoHeader.biHeight;

    // int rowBytes = ((width*3 + 3) / 4)*4;
    int rowBytes = (width * 3 + 3) & ~3;

    uint8_t *bmpinputBytes = (uint8_t *)malloc(rowBytes * height);
    if (!bmpinputBytes) {
        printf("Error: malloc bmpinputBytes failed.\n");
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }
    
    size_t RowsRead = fread(bmpinputBytes, rowBytes, height, bmpFile);
    if (RowsRead != height) {
        printf("Error: fread failed: expected %d rows, got %zu\n", height, RowsRead);
        free(bmpinputBytes);
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }

    uint8_t *row = (uint8_t *)malloc(rowBytes);
    if (!row) {
        printf("Error: malloc row failed.\n");
        free(bmpinputBytes);
        fclose(rf); fclose(gf); fclose(bf); fclose(bmpFile);
        exit(1);
    }

    if (infoHeader.biHeight>0) {
        for (int i=height-1; i>=0; --i) {
            int row_bytes_index = i*rowBytes;
            memcpy(row, bmpinputBytes+row_bytes_index, rowBytes);
            for (int x = 0; x < width; x++) {
                uint8_t b = row[x * 3 + 0];
                uint8_t g = row[x * 3 + 1];
                uint8_t r = row[x * 3 + 2];
                fprintf(rf, "%02X ", r);
                fprintf(gf, "%02X ", g);
                fprintf(bf, "%02X ", b);
            }
            fprintf(rf, "\n");
            fprintf(gf, "\n");
            fprintf(bf, "\n");
        }
    } else {
        for (int i=0; i<height; i++) {
            int row_bytes_index = i*rowBytes;
            memcpy(row, bmpinputBytes+row_bytes_index, rowBytes);
            for (int x = 0; x < width; x++) {
                uint8_t b = row[x * 3 + 0];
                uint8_t g = row[x * 3 + 1];
                uint8_t r = row[x * 3 + 2];
                fprintf(rf, "%02X ", r);
                fprintf(gf, "%02X ", g);
                fprintf(bf, "%02X ", b);
            }
            fprintf(rf, "\n");
            fprintf(gf, "\n");
            fprintf(bf, "\n");
        }
    }

    fflush(rf); fflush(gf); fflush(bf);
    fclose(rf); fclose(gf); fclose(bf); 
    fclose(bmpFile);
    free(bmpinputBytes);
    free(row);
    // printf("Info: Extraction complete.\n");
    return 0;
}

