/*
 *	crc_32.c 
 *
 * Calculates CRC (cylical redundancy check) producing a 32-bit checksum value
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include "size_types.h"

#define                 P_32			0xEDB88320 //IEEE 802.3
#define					Castagnoli32	0x82F63B78
#define					Koopman32		0xEB31D82E
#define FALSE           0
#define TRUE            1


static int crc_tab32_init = FALSE;
static ui4 crc_tab32[256];


//Initialize CRC lookup table
static void init_crc32_tab( void ) {
	
    int i, j;
    ui4 crc;
	
    for (i=0; i<256; i++) {
		
        crc = (ui4) i;
		
        for (j=0; j<8; j++) {
            if ( crc & 0x00000001 ) 
				crc = ( crc >> 1 ) ^ Koopman32;
            else
				crc =   crc >> 1;
        }
		
        crc_tab32[i] = crc;
    }
	
    crc_tab32_init = TRUE;
	
}  /* init_crc32_tab */


ui4 update_crc_32(ui4 crc, si1 c ) {
	
    ui4 tmp, long_c;
	
    long_c = 0x000000ff & (ui4) c;
	
    if ( ! crc_tab32_init ) init_crc32_tab();
	
    tmp = crc ^ long_c;
    crc = (crc >> 8) ^ crc_tab32[ tmp & 0xff ];
	
    return crc;
	
}  /* update_crc_32 */
