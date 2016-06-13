#ifndef RED_CODEC_IN
#define RED_CODEC_IN

#include "size_types.h"

/* range encoding constants			*/
/* CODE_BITS = 32				*/
/* TOP_VALUE = 1 << (CODE_BITS - 1)		*/
/* TOP_VALUE_M_1 = TOP_VALUE - 1		*/
/* SHIFT_BITS = CODE_BITS - 9			*/
/* EXTRA_BITS = ((CODE_BITS - 2) % 8) + 1	*/
/* BOTTOM_VALUE = TOP_VALUE >> 8		*/
/* BOTTOM_VALUE_M_1 = BOTTOM_VALUE - 1		*/
#define TOP_VALUE		(ui4) 0x80000000
#define TOP_VALUE_M_1		(ui4) 0x7FFFFFFF
#define CARRY_CHECK		(ui4) 0x7F800000
#define SHIFT_BITS		23
#define EXTRA_BITS		7
#define BOTTOM_VALUE		(ui4) 0x800000
#define BOTTOM_VALUE_M_1	(ui4) 0x7FFFFF
#define FILLER_BYTE			(ui1) 0x55 

/* 4 byte checksum, 4 byte compressed byte count, 8 byte time value, 4 byte difference count,  */
/* 4 byte sample count, 3 byte data maximum, 3 byte data minimum, 1 byte discontinuity flag, 256 byte model counts */
#define BLOCK_HEADER_BYTES	287
#define RED_CHECKSUM_OFFSET 0
#define RED_COMPRESSED_BYTE_COUNT_OFFSET 4
#define RED_UUTC_TIME_OFFSET 8
#define RED_DIFFERENCE_COUNT_OFFSET 16
#define RED_SAMPLE_COUNT_OFFSET 20
#define RED_DATA_MAX_OFFSET 24
#define RED_DATA_MIN_OFFSET 27
#define RED_DISCONTINUITY_OFFSET 30
#define RED_STAT_MODEL_OFFSET 31
#define RED_DATA_OFFSET BLOCK_HEADER_BYTES

/****************************************************************************************************/
/***  block size defines desired packet spacing - do not exceed 2^23 = 8388608 samples per block  ***/
/****************************************************************************************************/

typedef struct {
	ui4 CRC_32;
	ui1 CRC_validated;
	si4 compressed_bytes;
	ui8 block_start_time;
	si4 difference_count;
	si4 sample_count;
	si4 max_value; /*NOTE: max and min are stored in block header as si3's*/
	si4 min_value;
	ui1 discontinuity;
} RED_BLOCK_HDR_INFO; 


#endif


