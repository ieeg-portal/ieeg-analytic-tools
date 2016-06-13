#include <stdio.h>
#include <stdlib.h>
#include <pthread.h> 
#include "RED_codec.h"
#include "size_types.h"
#include "mef_header_2_0.h"


static inline void dec_normalize(ui4 *range, ui4 *low_bound, ui1 *in_byte, ui1 **ib_p)
{
	ui4 low, rng;
	ui1 in, *ib;
	
	low = *low_bound; 
	in = *in_byte;
	rng = *range;
	ib = *ib_p;
	
	while (rng <= BOTTOM_VALUE)
	{   low = (low << 8) | ((in << EXTRA_BITS) & 0xff);
		in = *ib++;
		low |= in >> (8 - EXTRA_BITS);
		rng <<= 8;
	}
	*low_bound = low; 
	*in_byte = in;
	*range = rng;
	*ib_p = ib;
	
	return;
}
 

ui8 RED_decompress_block(ui1 *in_buffer, si4 *out_buffer, ui1 *diff_buffer, si1 *key, ui1 validate_CRC, RED_BLOCK_HDR_INFO *block_hdr_struct)
{
	ui4	cc, cnts[256], cum_cnts[257], block_len, comp_block_len, checksum;
	ui4	symbol, scaled_tot_cnts, tmp, range_per_cnt, diff_cnts, checksum_read;
	ui1	*ui1_p, *db_p;
	si1	*si1_p1, *si1_p2, discontinuity;
	si4	i, current_val, *ob_p, max_data_value, min_data_value;
	ui8 time_value;
	ui4 update_crc_32();
	void AES_decryptWithKey(), AES_decrypt();
	ui4	low_bound;
	ui4	range;
	ui1	in_byte;
	ui1	*ib_p;
	
	
	
	/*** parse block header ***/
	ib_p = in_buffer;
	checksum_read = *(ui4 *)ib_p; ib_p += 4;
	comp_block_len = *(ui4 *)ib_p; ib_p += 4;
	time_value = *(ui8 *)ib_p; ib_p += 8;
	diff_cnts = *(ui4 *)ib_p; ib_p += 4;
	block_len = *(ui4 *)ib_p; ib_p += 4;
	
	max_data_value = 0; min_data_value = 0;
	ui1_p = (ui1 *) &max_data_value; 
	for (i = 0; i < 3; ++i) { *ui1_p++ = *ib_p++; }	
	*ui1_p++ = (*(si1 *)(ib_p-1)<0) ? -1 : 0; /*sign extend*/
	ui1_p = (ui1 *) &min_data_value; 
	for (i = 0; i < 3; ++i) { *ui1_p++ = *ib_p++; }	
	*ui1_p++ = (*(si1 *)(ib_p-1)<0) ? -1 : 0; /*sign extend*/

	discontinuity = *ib_p++;

	if (validate_CRC) {
		/*calculate CRC checksum to validate- skip first 4 bytes*/
		checksum = 0xffffffff;
		for (i = 4; i < comp_block_len + BLOCK_HEADER_BYTES; i++)
			checksum = update_crc_32(checksum, *(out_buffer+i));
		
		if (checksum != checksum_read) block_hdr_struct->CRC_validated = 0;
		else block_hdr_struct->CRC_validated = 1;
	}
	
	if (*key) 
		AES_decryptWithKey(ib_p, ib_p, key); /*pass in expanded key
		//AES_decrypt(ib_p, ib_p, key); password*/
	
	for (i = 0; i < 256; ++i) { cnts[i] = (ui4) *ib_p++; }

	if (block_hdr_struct != NULL) {	
		block_hdr_struct->CRC_32 = checksum_read;
		block_hdr_struct->block_start_time = time_value;
		block_hdr_struct->compressed_bytes = comp_block_len;
		block_hdr_struct->difference_count = diff_cnts;
		block_hdr_struct->sample_count = block_len;
		block_hdr_struct->max_value = max_data_value;
		block_hdr_struct->min_value = min_data_value;
		block_hdr_struct->discontinuity = discontinuity;
	}
	
	/*** generate statistics ***/
	cum_cnts[0] = 0;
	for (i = 0; i < 256; ++i)
		cum_cnts[i + 1] = cnts[i] + cum_cnts[i];
	scaled_tot_cnts = cum_cnts[256];

	
	/*** range decode ***/
	diff_buffer[0] = -128; db_p = diff_buffer + 1;	++diff_cnts;	/* initial -128 not coded in encode (low frequency symbol)*/
	ib_p = in_buffer + BLOCK_HEADER_BYTES + 1;	/* skip initial dummy byte from encode*/
	in_byte = *ib_p++;
	low_bound = in_byte >> (8 - EXTRA_BITS);
	range = (ui4) 1 << EXTRA_BITS;
	for (i = diff_cnts; i--;) {
		/*printf("in %u %u\t", range, low_bound);*/
		dec_normalize(&range, &low_bound, &in_byte, &ib_p);
		/*printf("out %u %u\n", range, low_bound);*/
		tmp = low_bound / (range_per_cnt = range / scaled_tot_cnts);			
		cc = (tmp >= scaled_tot_cnts ? (scaled_tot_cnts - 1) : tmp);
		if (cc > cum_cnts[128]) {
			for (symbol = 255; cum_cnts[symbol] > cc; symbol--);
		} else {
			for (symbol = 1; cum_cnts[symbol] <= cc; symbol++);
			--symbol;
		}
		low_bound -= (tmp = range_per_cnt * cum_cnts[symbol]);
		if (symbol < 255)
			range = range_per_cnt * cnts[symbol];
		else
			range -= tmp;
		*db_p++ = symbol;
	}
	dec_normalize(&range, &low_bound, &in_byte, &ib_p);
	/*printf("end %u %u\n", range, low_bound);
	*** generate output data from differences ***/
	si1_p1 = (si1 *) diff_buffer;
	ob_p = out_buffer;
	for (current_val = 0, i = block_len; i--;) {
		if (*si1_p1 == -128) {					/*assumes little endian input*/
			si1_p2 = (si1 *) &current_val;
			*si1_p2++ = *++si1_p1; *si1_p2++ = *++si1_p1; *si1_p2++ = *++si1_p1;
			*si1_p2 = (*si1_p1++ < 0) ? -1 : 0;
		} else
			current_val += (si4) *si1_p1++;
		*ob_p++ = current_val;
	}

	return(comp_block_len + BLOCK_HEADER_BYTES);
}

