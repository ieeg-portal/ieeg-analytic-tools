
    

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <math.h>
#include "RED_codec.h"
#include "size_types.h"
#include "mef_header_2_0.h"


typedef struct {
	ui4	low_bound;
	ui4	range;
	ui1	out_byte;
	ui4	underflow_bytes;
	ui1	*ob_p;
}RANGE_STATS;


inline void enc_normalize(RANGE_STATS *rstats)
{
	
	while (rstats->range <= BOTTOM_VALUE) {
		if (rstats->low_bound < (ui4 ) CARRY_CHECK) {		// no carry possible => output
			*(rstats->ob_p++) = rstats->out_byte;
			for(; rstats->underflow_bytes; rstats->underflow_bytes--)
				*(rstats->ob_p++) = 0xff;
			rstats->out_byte = (ui1) (rstats->low_bound >> SHIFT_BITS);
		} else if (rstats->low_bound & TOP_VALUE) {		// carry now, no future carry
			*(rstats->ob_p++) = rstats->out_byte + 1;
			for(; rstats->underflow_bytes; rstats->underflow_bytes--)
				*(rstats->ob_p++) = 0;
			rstats->out_byte = (ui1) (rstats->low_bound >> SHIFT_BITS);
		} else						// pass on a potential carry
			rstats->underflow_bytes++;
		rstats->range <<= 8;
		rstats->low_bound = (rstats->low_bound << 8) & TOP_VALUE_M_1;
	}
		
	return;
}


inline void encode_symbol(ui1 symbol, ui4 symbol_cnts, ui4 cnts_lt_symbol, ui4 tot_cnts, RANGE_STATS *rstats )
{
	ui4	r, tmp;
	
	enc_normalize(rstats);
	rstats->low_bound += (tmp = (r = rstats->range / tot_cnts) * cnts_lt_symbol);
	if (symbol < 0xff)			// not last symbol
		rstats->range = r * symbol_cnts;
	else						// last symbol
		rstats->range -= tmp;	// special case improves compression
								// at expense of speed
	return;
}


void done_encoding(RANGE_STATS *rstats)
{
	ui4	tmp;
	
	enc_normalize(rstats);
	
	tmp = rstats->low_bound;
	tmp = (tmp >> SHIFT_BITS) + 1;
	if (tmp > 0xff) {
		*(rstats->ob_p++) = rstats->out_byte + 1;
		for(; rstats->underflow_bytes; rstats->underflow_bytes--)
			*(rstats->ob_p++) = 0;
	} else {
		*(rstats->ob_p++) = rstats->out_byte;
		for(; rstats->underflow_bytes; rstats->underflow_bytes--)
			*(rstats->ob_p++) = 0xff;
	}
	*(rstats->ob_p++) = tmp & 0xff; *(rstats->ob_p++) = 0; *(rstats->ob_p++) = 0; *(rstats->ob_p++) = 0;

	return;
}


ui8 RED_compress_block(si4 *in_buffer, ui1 *out_buffer, ui4 num_entries, ui8 uUTC_time, ui1 discontinuity,
					   si1 *key, RED_BLOCK_HDR_INFO *block_hdr)
{
	ui4	cum_cnts[256], cnts[256], max_cnt, scaled_tot_cnts, extra_bytes;
	ui4	diff_cnts, comp_block_len, comp_len, checksum, update_crc_32();
	ui1	diff_buffer[num_entries * 4], *ui1_p1, *ui1_p2, *ehbp;
	si1	*si1_p1, *si1_p2;
	si4	i, diff, max_data_value, min_data_value;
	sf8	stats_scale;
	RANGE_STATS rng_st;
	void AES_encryptWithKey(), AES_encrypt();
	
	
/*	if (num_entries < 4 * BLOCK_HEADER_BYTES) {
		if (encode_warning == 0)
			encode_warning++;
		else if (encode_warning == 1) { //Show warning message only once
			fprintf(stderr, "\n\n*** Warning: Encoding %d entries- fewer than %d entries may result in poor compression. [%s] ***\n",
					num_entries, 4*BLOCK_HEADER_BYTES, __FUNCTION__);
			encode_warning++;
		}
	}
*/	
	/*** generate differences ***/
	si1_p1 = (si1 *) diff_buffer;
	si1_p2 = (si1 *) in_buffer;
	*si1_p1++ = *si1_p2++;
	*si1_p1++ = *si1_p2++;
	*si1_p1++ = *si1_p2;	// first entry is full value (3 bytes)

	max_data_value = min_data_value = in_buffer[0];
	
	for (i = 1; i < num_entries; i++) {
		diff = in_buffer[i] - in_buffer[i - 1];
		if (in_buffer[i] > max_data_value) max_data_value = in_buffer[i];
		else if (in_buffer[i] < min_data_value) min_data_value = in_buffer[i];
		if (diff > 127 || diff < -127) {				// for little endian input
			si1_p2 = (si1 *) (in_buffer + i);
			*si1_p1++ = -128;
			*si1_p1++ = *si1_p2++;
			*si1_p1++ = *si1_p2++;
			*si1_p1++ = *si1_p2;
		} else
			*si1_p1++ = (si1) diff;
	}
	diff_cnts = (si4) (si1_p1 - (si1 *) diff_buffer);
	
	/*** generate statistics ***/
	bzero((void *) cnts, 1024);
	ui1_p1 = diff_buffer;
	for (i = diff_cnts; i--;)
		++cnts[*ui1_p1++];
	
	max_cnt = 0;
	for (i = 0; i < 256; ++i)
		if (cnts[i] > max_cnt)
			max_cnt = cnts[i];
	if (max_cnt > 255) {
		stats_scale = (sf8) 254.999 / (sf8) max_cnt;
		for (i = 0; i < 256; ++i)
			cnts[i] = (ui4) ceil((sf8) cnts[i] * stats_scale);
	}
	cum_cnts[0] = 0;
	for (i = 0; i < 255; ++i)
		cum_cnts[i + 1] = cnts[i] + cum_cnts[i];
	scaled_tot_cnts = cnts[255] + cum_cnts[255];
	
	
	/*** range encode ***/
	rng_st.low_bound = rng_st.out_byte = rng_st.underflow_bytes = 0;
	rng_st.range = TOP_VALUE;
	rng_st.ob_p = out_buffer + BLOCK_HEADER_BYTES; //NOTE: ob_p is declared GLOBAL
	ui1_p1 = diff_buffer;
	for(i = diff_cnts; i--; ++ui1_p1)
		encode_symbol(*ui1_p1, cnts[*ui1_p1], cum_cnts[*ui1_p1], scaled_tot_cnts, &rng_st);
	done_encoding(&rng_st);


	//ensure 8-byte alignment for next block
	comp_len = (ui4)(rng_st.ob_p - out_buffer);
	extra_bytes = 8 - comp_len % 8;
 
	if (extra_bytes < 8) {
		for (i=0; i<extra_bytes; i++)
			*(rng_st.ob_p++) = FILLER_BYTE; 
	}
	
	/*** write the packet & packet header ***/
	/* 4 byte checksum, 8 byte time value, 4 byte compressed byte count, 4 byte difference count,  */
	/* 4 byte sample count, 3 byte data maximum, 3 byte data minimum, 256 byte model counts */

	ui1_p1 = out_buffer;

	//fill checksum with zero as a placeholder
	*(ui4 *)(ui1_p1) = 0; ui1_p1 += 4;
		
	comp_block_len = (ui4)((rng_st.ob_p - out_buffer) - BLOCK_HEADER_BYTES);
	if (block_hdr != NULL) block_hdr->compressed_bytes = comp_block_len;
	*(ui4 *)(ui1_p1) = comp_block_len; ui1_p1 += 4;
	
	if (block_hdr != NULL) block_hdr->block_start_time = uUTC_time;
	*(ui8 *)(ui1_p1) = uUTC_time; ui1_p1 += 8;
	
	if (block_hdr != NULL) block_hdr->difference_count = diff_cnts;
	*(ui4 *)(ui1_p1) = diff_cnts; ui1_p1 += 4;
	
	if (block_hdr != NULL) block_hdr->sample_count = num_entries;
	*(ui4 *)(ui1_p1) = num_entries; ui1_p1 += 4;
	
	if (block_hdr != NULL) block_hdr->max_value = max_data_value;
	ui1_p2 = (ui1 *) &max_data_value; //encode max and min values as si3
	for (i = 0; i < 3; ++i)
		*ui1_p1++ = *ui1_p2++;
	
	if (block_hdr != NULL) block_hdr->min_value = min_data_value;
	ui1_p2 = (ui1 *) &min_data_value; //encode max and min values as si3
	for (i = 0; i < 3; ++i) 
		*ui1_p1++ = *ui1_p2++;
	
	if (block_hdr != NULL) block_hdr->discontinuity = discontinuity; 
	*ui1_p1++ = discontinuity;
	
	ehbp = ui1_p1;
	
	for (i = 0; i < 256; ++i)
			*ui1_p1++ = (ui1) cnts[i];

	if (*key)
		AES_encryptWithKey(ehbp, ehbp, key); //expanded key
		//AES_encrypt(ehbp, ehbp, key); // password
		
	//calculate CRC checksum and save in block header- skip first 4 bytes
	checksum = 0xffffffff;
	for (i = 4; i < comp_block_len + BLOCK_HEADER_BYTES; i++)
		checksum = update_crc_32(checksum, *(out_buffer+i));
	
	if (block_hdr != NULL) block_hdr->CRC_32 = checksum;
	ui1_p1 = out_buffer;
	ui1_p2 = (ui1 *) &checksum;
	for (i = 0; i < 4; ++i)
		*ui1_p1++ = *ui1_p2++;
	
	return(comp_block_len + BLOCK_HEADER_BYTES);
}
