#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>     
#include <string.h>    
#include <stdint.h>    

#include <math.h>
#define PRECISION 10
// #define METHOD 1    //0: nearest neighbor; 1:bilinear interpolation


// -----------------------------------------------------------------------------------
// This implementation ONLY works correctly if the BMP image width is a multiple of 4.
// -----------------------------------------------------------------------------------


// Define BMP file headers and pixel structure
#pragma pack(push, 1)
typedef struct {
    unsigned short bfType;
    unsigned int bfSize;
    unsigned short bfReserved1;
    unsigned short bfReserved2;
    unsigned int bfOffBits;
} BMPFileHeader;

typedef struct {
    unsigned int biSize;
    int biWidth;
    int biHeight;
    unsigned short biPlanes;
    unsigned short biBitCount;
    unsigned int biCompression;
    unsigned int biSizeImage;
    int biXPelsPerMeter;
    int biYPelsPerMeter;
    unsigned int biClrUsed;
    unsigned int biClrImportant;
} BMPInfoHeader;

typedef struct {
    unsigned char b, g, r;
} Pixel;


#pragma pack(pop)

void resizeBMP(const char *inputFile, const char *outputFile, const int OLD_X, const int OLD_Y, const int NEW_X, const int NEW_Y, const int METHOD);


int main(int argc, char *argv[]) {

    if (argc < 8) {
        printf("Error: usage: %s [input.bmp] [output.bmp]\n", argv[0]);
        exit(1);
    }
    
    setbuf(stdout, NULL);

    const char *inputFile  = argv[1];
    const char *outputFile = argv[2];
    const int OLD_X = atoi(argv[3]);
    const int OLD_Y = atoi(argv[4]);
    const int NEW_X = atoi(argv[5]);
    const int NEW_Y = atoi(argv[6]);    
    const int METHOD = atoi(argv[7]);    

    if (OLD_X <= 0 || OLD_Y <= 0 || NEW_X <= 0 || NEW_Y <= 0) {
        printf("Error: Invalid input parameters.\n");
        exit(1);
    }
    
    float scaleX = (float)NEW_X/OLD_X;
    float scaleY = (float)NEW_Y/OLD_Y;

    resizeBMP(inputFile, outputFile, OLD_X, OLD_Y, NEW_X, NEW_Y, METHOD);

    return 0;
}



void resizeBMP(const char *inputFile, const char *outputFile, const int OLD_X, const int OLD_Y, const int NEW_X, const int NEW_Y, const int METHOD) {

    FILE *inFile = fopen(inputFile, "rb");
    if (!inFile) {
        printf("Error: Unable to open picture file.\n");
        exit(1);
    }

    BMPFileHeader fileHeader;
    BMPInfoHeader infoHeader;

    fread(&fileHeader, sizeof(BMPFileHeader), 1, inFile);
    fread(&infoHeader, sizeof(BMPInfoHeader), 1, inFile);

    if (fileHeader.bfType != 0x4D42 || infoHeader.biBitCount != 24) {
        printf("Error: unsupported BMP format. Only 24-bit BMP files are supported.\n");
        fclose(inFile);
        exit(1);
    }

    int oldWidth = infoHeader.biWidth;
    if ((oldWidth * 3) % 4 != 0) {
        printf("Error: unsupported BMP width (%d). Width*3 must be a multiple of 4.\n", oldWidth);
        fclose(inFile);
        exit(1);
    }
    int oldHeight = (infoHeader.biHeight>0) ? infoHeader.biHeight : -infoHeader.biHeight;
    if (oldWidth!=OLD_X || oldHeight !=OLD_Y) {
        printf("Error: incorrect input picture size.\n");
        fclose(inFile);
        exit(1);
    }
    int newWidth  = NEW_X;
    int newHeight = NEW_Y;

    // Read pixel data from input BMP
    // int oldRowBytes = ((oldWidth * 3 + 3) / 4) * 4;
    // int newRowBytes = ((newWidth * 3 + 3) / 4) * 4;
    int oldRowBytes = oldWidth * 3;
    int newRowBytes = newWidth * 3;

    Pixel *bmpinputPixels = (Pixel *)malloc(oldWidth * oldHeight * sizeof(Pixel));
    Pixel *inputPixels = (Pixel *)malloc(oldWidth * oldHeight * sizeof(Pixel));
    Pixel *outputPixels = (Pixel *)malloc(newWidth * newHeight * sizeof(Pixel));
    if (!bmpinputPixels || !inputPixels || !outputPixels) {
        printf("ERROR: Memory allocation failed!\n");
        free(bmpinputPixels);
        free(inputPixels);
        free(outputPixels);
        fclose(inFile);
        exit(1);
    }


    int checkfseek = fseek(inFile, fileHeader.bfOffBits, SEEK_SET);
    if (checkfseek != 0) {
        printf("Error: fseek() failed! bfOffBits = %d is invalid.\n", fileHeader.bfOffBits);
        free(bmpinputPixels);
        free(inputPixels);
        free(outputPixels);
        fclose(inFile);
        exit(1);
    }
    size_t RowsRead = fread(bmpinputPixels, oldRowBytes, oldHeight, inFile);
    if (RowsRead != oldHeight) {
        printf("Error: fread failed: expected %d rows, got %zu\n", oldHeight, RowsRead);
        free(bmpinputPixels);
        free(inputPixels);
        free(outputPixels);
        fclose(inFile);
        exit(1);
    }
    fclose(inFile);
    
     
    if (infoHeader.biHeight>0) {
        // Reverse pixel data (biheight>0 POSITIVE means BMP stores pixels from bottom to top)
        for (int n = 0; n < oldHeight; ++n) {
            int sourceRowPixelIndex = (oldHeight -1 - n) * oldWidth;  // Read from bottom row
            int targetRowPixelIndex = n * oldWidth; 
            
            memcpy(inputPixels+targetRowPixelIndex, bmpinputPixels+sourceRowPixelIndex, oldRowBytes);
        }
    } else {
        // no need to reverse (biheight<0 NEGATIVE means BMP stores pixels from top to bottom)
        memcpy(inputPixels, bmpinputPixels, oldRowBytes * oldHeight);
    }
    
    free(bmpinputPixels);


    Pixel newPixel;
    
    int order = -ceil(log10(powf(2, -PRECISION)));
    float precision_factor = powf(10, order);

    float real_scaleX = (newWidth>1  && oldWidth>1 ) ? ((float)oldWidth / newWidth) : 0;
    float real_scaleY = (newHeight>1 && oldHeight>1) ? ((float)oldHeight /newHeight) : 0;

    // pixel-centered formula: (src_idx+0.5)/(tar_idx+0.5)=OLD_X/OLD_Y 
    for (int tarY_idx=0; tarY_idx<NEW_Y; tarY_idx++) {
        for (int tarX_idx=0; tarX_idx<NEW_X; tarX_idx++) {

            //map target pixel back to source coordinate; 
            //tar_co = coordinate of target pixel on source picture( and coordinate of points became (int) instead of (int+0.5) ); 
            float tarX_co = (tarX_idx + 0.5f) * real_scaleX - 0.5f;
            float tarY_co = (tarY_idx + 0.5f) * real_scaleY - 0.5f;    

            int srcX_idx;
            int srcY_idx;
            
            if (tarX_co > OLD_X-1) {
                srcX_idx = OLD_X-1;
            } else if (tarX_co < 0) {
                srcX_idx = 0;
            }
            
            if (tarY_co > OLD_Y-1) {
                srcY_idx = OLD_Y-1;
            } else if (tarY_co < 0) {
                srcY_idx = 0;
            }


            switch (METHOD) {
                case 0: {

                        if (!(tarX_co>OLD_X-1) && !(tarX_co<0)) {
                            srcX_idx = (int)(tarX_co + 0.5f);      // round
                        }
                        if (!(tarY_co>OLD_Y-1) && !(tarY_co<0)) {
                            srcY_idx = (int)(tarY_co + 0.5f);      // round
                        }

                        newPixel = inputPixels[srcY_idx*oldWidth+srcX_idx];
                    
                        break;
                }

                case 1: {

                        if (!(tarX_co>OLD_X-1) && !(tarX_co<0)) {
                            srcX_idx = (int)(tarX_co);          // floor
                        }
                        if (!(tarY_co>OLD_Y-1) && !(tarY_co<0)) {
                            srcY_idx = (int)(tarY_co);          // floor
                        }

                        Pixel p_1, p_2, p_3, p_4;
                        float dx, dy, rest_dx, rest_dy;


                        if (
                                srcX_idx==OLD_X-1 && srcY_idx==OLD_Y-1 
                            ||  srcX_idx==OLD_X-1 && srcY_idx==0
                            ||  srcX_idx==0 && srcY_idx==OLD_Y-1
                            ||  srcX_idx==0 && srcY_idx==0
                            ) {
                            p_1 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx  )];
                            p_2 = p_1;
                            p_3 = p_1;
                            p_4 = p_1;
                            dx = 1;
                            dy = 1;
                        } else if (srcX_idx==OLD_X-1 || tarX_co<srcX_idx) {
                            p_1 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx  )];
                            p_2 = p_1;
                            p_3 = inputPixels[(srcY_idx+1)*oldWidth+(srcX_idx  )];
                            p_4 = p_3;
                            dx = 1;
                            dy = tarY_co-(float)srcY_idx;
                            
                        } else if (srcY_idx==OLD_Y-1 || tarY_co<srcY_idx) {
                            p_1 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx  )];
                            p_2 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx+1)];
                            p_3 = p_1;
                            p_4 = p_2;
                            dx = tarX_co-(float)srcX_idx;
                            dy = 1;
                        } else {
                            p_1 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx  )];
                            p_2 = inputPixels[(srcY_idx  )*oldWidth+(srcX_idx+1)];
                            p_3 = inputPixels[(srcY_idx+1)*oldWidth+(srcX_idx  )];
                            p_4 = inputPixels[(srcY_idx+1)*oldWidth+(srcX_idx+1)];
                            dx = tarX_co-(float)srcX_idx;
                            dy = tarY_co-(float)srcY_idx;
                        }

                        rest_dx = 1.0f - dx;
                        rest_dy = 1.0f - dy;

                        float w1 = floorf( dx*dy             * precision_factor) / precision_factor;
                        float w2 = floorf( rest_dx*dy        * precision_factor) / precision_factor;
                        float w3 = floorf( dx*rest_dy        * precision_factor) / precision_factor;
                        float w4 = floorf( rest_dx*rest_dy   * precision_factor) / precision_factor;
                        
                        newPixel.b = w1*p_4.b + w2*p_3.b + w3*p_2.b + w4*p_1.b;
                        newPixel.g = w1*p_4.g + w2*p_3.g + w3*p_2.g + w4*p_1.g;
                        newPixel.r = w1*p_4.r + w2*p_3.r + w3*p_2.r + w4*p_1.r;
                        
                        break;
                }

                default:
                    printf("Error: Invalid method.\n");
                    free(inputPixels);
                    free(outputPixels);
                    exit(1);
            }

            outputPixels[tarY_idx*newWidth+tarX_idx] = newPixel;
        }
    }
    free(inputPixels);
    

    //headers for new picture
    BMPFileHeader new_fileHeader = fileHeader;
    BMPInfoHeader new_infoHeader = infoHeader;
    new_infoHeader.biWidth = newWidth;
    new_infoHeader.biHeight = (infoHeader.biHeight>0) ? newHeight : -newHeight;
    new_infoHeader.biSizeImage = newRowBytes * newHeight;
    new_fileHeader.bfSize = sizeof(BMPFileHeader) + sizeof(BMPInfoHeader) + new_infoHeader.biSizeImage;

    FILE *outFile = fopen(outputFile, "wb");
    if (!outFile) {
        printf("Error: Unable to open output file.\n");
        free(outputPixels);
        exit(1);
    }

    size_t fwrite_cnt1 = fwrite(&new_fileHeader, sizeof(BMPFileHeader), 1, outFile);
    size_t fwrite_cnt2 = fwrite(&new_infoHeader, sizeof(BMPInfoHeader), 1, outFile);
    if (fwrite_cnt1 != 1 || fwrite_cnt2 != 1) {
        printf("Error: write file header / info header error\n");
        free(outputPixels);
        fclose(outFile);
        exit(1);
    }

    if (infoHeader.biHeight>0) {
        for (int i=newHeight-1; i>=0; --i) {
            int row_pixel_index = i*newWidth;
            size_t write_one_row = fwrite(outputPixels+row_pixel_index, newRowBytes, 1, outFile);
            if (write_one_row != 1) {
                printf("Error: write row error\n");
                free(outputPixels);
                fclose(outFile);
                exit(1);
            }
        }
    } else {
        size_t Rows_write = fwrite(outputPixels, newRowBytes, newHeight, outFile);
        if (Rows_write != newHeight) {
            printf("Error: write all error\n");
            free(outputPixels);
            fclose(outFile);
            exit(1);
        }
    }
    

    fclose(outFile);
    free(outputPixels);
}
