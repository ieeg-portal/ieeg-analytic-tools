#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "mex.h"
#include "mef_header_2_0.h"
#include "mef_lib.h"
#include "RED_codec.h"

#define BIG_ENDIAN_CODE		0
#define LITTLE_ENDIAN_CODE	1


void readHeader(char *f_name, char *password, unsigned long long int *tot_index_fields, unsigned long long int *num_samples, unsigned long long int *index_data_offset, unsigned int *max_block_length, char encryptionKey[240]) {
	
	unsigned char		*header;
	unsigned int		cpu_endianness, n_read;
	unsigned int		i, n_index_entries;
	unsigned long long int  RED_decompress_block();
	FILE			*fp;
	MEF_HEADER_INFO         hdr_info;
	RED_BLOCK_HDR_INFO      block_hdr;
	void                    AES_KeyExpansion();

	/* read header */
	fp = fopen(f_name, "r");
	if (fp == NULL) { 
		printf("[decomp_mef2] could not open the file \"%s\" => exiting\n",  f_name);
		return;
	}
	header = (unsigned char *) malloc(MEF_HEADER_LENGTH);  // malloc to ensure boundary alignment
	n_read = fread((void *) header, sizeof(char), (size_t) MEF_HEADER_LENGTH, fp);
	if (n_read != MEF_HEADER_LENGTH) {
		printf("[decomp_mef2] error reading the file \"%s\" => exiting\n",  f_name);
		return;
	}	
	if ((read_mef_header_block(header, &hdr_info, password))) {
		printf("[decomp_mef2] header read error for file \"%s\" => exiting\n", f_name);
		return;		
	}
	free(header);
	
	/* get file endianness */
	if (hdr_info.byte_order_code != LITTLE_ENDIAN_CODE) {
		mexErrMsgTxt("[decomp_mef2] is currently only compatible with little-endian files (file \"%s\") => exiting");
		return;
	}

	if (hdr_info.data_encryption_used) {
		AES_KeyExpansion(4, 10, encryptionKey, hdr_info.session_password); 
	}
	else
		*encryptionKey = 0;

	/* read in necessary data */
	n_index_entries = (unsigned long long int) hdr_info.number_of_index_entries;	
	*tot_index_fields = (unsigned long long int) n_index_entries * 3;	// 3 fields per entry
	*num_samples = (unsigned long long int) hdr_info.number_of_samples;
	*index_data_offset = (unsigned long long int) hdr_info.index_data_offset;
	*max_block_length = (unsigned long long int) hdr_info.maximum_block_length;
	rewind(fp);
	fclose(fp);
}


void readIndex(char *f_name, char *password, unsigned long long int tot_index_fields, unsigned long long int index_data_offset, unsigned long long int *index_data) {
        unsigned int	        n_read, i;	
	FILE			*fp;
	
	/* open file */
	fp = fopen(f_name, "r");
	if (fp == NULL) { 
		printf("[decomp_mef2] could not open the file \"%s\" => exiting\n",  f_name);
		return;
	}
	
	fseeko(fp, (off_t) index_data_offset, SEEK_SET);

	n_read = fread(index_data, sizeof(unsigned long long int), (size_t) tot_index_fields, fp);
	if (n_read != tot_index_fields) {
	   printf("[decomp_mef2] error reading index data for file \"%s\" => exiting\n", f_name);
	   return;
	}	
	rewind(fp);
	fclose(fp);
}

void decomp_mef2( char *f_name, char encryptionKey[240], unsigned long long int tot_index_fields, unsigned long long int num_samples, unsigned long long int index_data_offset, unsigned int max_block_length, unsigned long long int *index_data, unsigned long long int start_idx, unsigned long long int end_idx, char *password, int *decomp_data)
{
        char			*c, *comp_data, *cdp, *last_block_p;
	unsigned char		*diff_buffer;
	int			*dcdp, *temp_data_buf;
	unsigned int		cpu_endianness, n_read, comp_data_len, bytes_decoded, tot_samples;
	unsigned int		i, j, k, kept_samples, skipped_samples;
	unsigned long long int	start_block_file_offset, end_block_file_offset, start_block_idx, end_block_idx;
	unsigned long long int	last_block_len, RED_decompress_block();
	FILE			*fp;
	RED_BLOCK_HDR_INFO	block_hdr;
	
	/* open file */
	fp = fopen(f_name, "r");
	if (fp == NULL) { 
		printf("[decomp_mef2] could not open the file \"%s\" => exiting\n",  f_name);
		return;
	}

	/* find block containing start of requested range */
	if (start_idx >= num_samples) {
		printf("[decomp_mef2] start index for file \"%s\" exceeds the number of samples in the file => exiting\n", f_name);
		return;
	}
	for (i = 2; i < tot_index_fields; i += 3)
		if (index_data[i] > start_idx)
			break;
	i -= 3; // rewind one triplet
	start_block_idx = index_data[i]; // sample index of start of block containing start index
	start_block_file_offset = index_data[i - 1];  // file offset of block containing start index
	
	/* find block containing end of requested range */
	if (end_idx >= num_samples) {
		printf("[decomp_mef2] end index for file \"%s\" exceeds the number of samples in the file => tail values will be zeros\n", f_name);
		end_idx = num_samples - 1;
	}
	for (; i < tot_index_fields; i += 3)
		if (index_data[i] > end_idx)
			break;
	i -= 3; // rewind one triplet
	end_block_idx = index_data[i]; // sample index of start of block containing end index
	end_block_file_offset = index_data[i - 1];  // file offset of block containing end index
	
	if (i == (tot_index_fields - 1)) {
		last_block_len = index_data_offset - end_block_file_offset;  // file offset of index data
	} else {
		last_block_len = index_data[i + 2] - end_block_file_offset;  // file offset of next block [this is in bytes]
	}


	/* allocate input buffer */
	comp_data_len = (unsigned int) (end_block_file_offset - start_block_file_offset + last_block_len);
	comp_data = (char *) malloc(comp_data_len); 
	if (comp_data == NULL) {
		printf("[decomp_mef2] could not allocate enough memory for file \"%s\" => exiting\n", f_name);
		return;
	}


	/* read in compressed data */
	fseeko(fp, (off_t) start_block_file_offset, SEEK_SET);
	n_read = fread(comp_data, sizeof(char), (size_t) comp_data_len, fp);
	if (n_read != comp_data_len) {
		printf("[decomp_mef2] error reading data for file \"%s\" => exiting\n", f_name);
		return;
	}
	fclose(fp);	
	
	/* decompress data */
	
	// decode first block to temp array
	cdp = comp_data;  
	diff_buffer = (unsigned char *) malloc(max_block_length * 4);
	temp_data_buf = (int *) malloc(max_block_length * 4);
	bytes_decoded = (unsigned int) RED_decompress_block(cdp, temp_data_buf, diff_buffer, encryptionKey, 0, &block_hdr);
	cdp += bytes_decoded;
	
	// copy requested samples from first block to output buffer
	skipped_samples = (unsigned int) (start_idx - start_block_idx);
	kept_samples = block_hdr.sample_count - skipped_samples;
	tot_samples = (unsigned int) (end_idx - start_idx + 1);
	if (kept_samples >= tot_samples) { // start and end indices in same block => already done
		memcpy((void *) decomp_data, (void *) (temp_data_buf + skipped_samples), tot_samples * sizeof(int));
		free(comp_data);	    
		return;
	}
	memcpy((void *) decomp_data, (void *) (temp_data_buf + skipped_samples), kept_samples * sizeof(int));
	dcdp = decomp_data + kept_samples;
	
	last_block_p = comp_data + (unsigned int) (end_block_file_offset - start_block_file_offset);
	while (cdp < last_block_p) {
		bytes_decoded = (unsigned int) RED_decompress_block(cdp, dcdp, diff_buffer, encryptionKey, 0, &block_hdr);
		cdp += bytes_decoded;
		dcdp += block_hdr.sample_count; 
	}
	
	// decode last block to temp array
	(void) RED_decompress_block(cdp, temp_data_buf, diff_buffer, encryptionKey, 0, &block_hdr);
	
	// copy requested samples from last block to output buffer
	kept_samples = (unsigned int) (end_idx - end_block_idx + 1);
	memcpy((void *) dcdp, (void *) temp_data_buf, kept_samples * sizeof(int));
	
	free(comp_data);
	free(diff_buffer);
	free(temp_data_buf);
	
	return;
}



// The mex gateway routine 
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  char			*f_name, *password, encryptionKey[240];
	int			buf_len, status, decomp_data_len, dims[2], *decomp_data, i;
	unsigned int            index_output, freeFlag, max_block_length;
	unsigned long long int	start_idx, end_idx, tot_index_fields, num_samples, index_data_offset, long_decomp_data_len, *index_data, *index_data_input;
	void			readHeader(), readIndex(), decomp_mef2();
		
	//  Check for proper number of arguments 
	if (nrhs != 4 && nrhs != 5) 
		mexErrMsgTxt("[decomp_mef2] four or five inputs required: file_name, start_index, stop_index, password, (index_data)");
	if (nlhs != 1 && nlhs != 2) 
		mexErrMsgTxt("[decomp_mef2] one or two outputs required: decompressed_array, (index_data)");
	
	// get the input file name (argument 1)
	if (mxIsChar(prhs[0]) != 1) { // Check to make sure the first input argument is a string 
		mexErrMsgTxt("[decomp_mef2] file name must be a string => exiting");
		return;
	}	
	buf_len = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 2; // Get the length of the input string 
	f_name = malloc(buf_len); // Allocate memory for file_name string
	status = mxGetString(prhs[0], f_name, buf_len);
	if (status != 0) {
		mexWarnMsgTxt("[decomp_mef2] not enough space for input file name string => exiting");
		return;
	}
	
	//  get the start index (argument 2)
	if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1]) || (mxGetN(prhs[1]) * mxGetM(prhs[1]) != 1) ) { // Check to make sure the second input argument is a scalar
		mexErrMsgTxt("[decomp_mef2] start index must be a scalar => exiting");
		return;
	}	
	start_idx = (unsigned long long int) mxGetScalar(prhs[1]);
	if (start_idx > 0.0)
		start_idx -= 1.0;     // convert to C indexing
	
	//  get the end index (argument 3)
	if (!mxIsDouble(prhs[2]) || mxIsComplex(prhs[2]) || (mxGetN(prhs[2]) * mxGetM(prhs[2]) != 1) ) { // Check to make sure the third input argument is a scalar
		mexErrMsgTxt("[decomp_mef2] end index must be a scalar => exiting");
		return;
	}	
	end_idx = (unsigned long long int) mxGetScalar(prhs[2]);
	end_idx -= 1.0;     // convert to C indexing
	
	// check that indices are in proper order
	if (end_idx < start_idx) {
		mexErrMsgTxt("[decomp_mef2] end index exceeds start index => exiting");
		return;
	}

	// get the password (argument 4)
	if (mxIsChar(prhs[3]) != 1) { // Check to make sure the fourth input argument is a string 
		mexErrMsgTxt("[decomp_mef2] Password must be a string => exiting");
		return;
	}	
	buf_len = (mxGetM(prhs[3]) * mxGetN(prhs[3])) + 2; // Get the length of the input string 
	password = malloc(buf_len); // Allocate memory for file_name string
	status = mxGetString(prhs[3], password, buf_len);
	if (status != 0) {
		mexWarnMsgTxt("[decomp_mef2] not enough space for password string => exiting");
		return;
	}
	/*------------------------------------------------------------------ALLISON CODE---------------------------------------------------------------------------*/
	// handle index data input/output (optional argument 5)
	// make sure index data input is properly formatted
	if (nrhs == 5 && ( !(mxGetM(prhs[4]) == 1 || mxGetN(prhs[4]) == 1) )) {
	    if ( !(mxGetM(prhs[4]) == 1 || mxGetN(prhs[4]) == 1) ) {
	      	mexErrMsgTxt("[decomp_mef2] index data input should be a vector => exiting");
		return;
	    }
	    if ( mxIsUint64(prhs[4]) != 1) {
	      	mexErrMsgTxt("[decomp_mef2] index data input should be type uint64 => exiting");
		return;
	    }
	  }

	freeFlag = 0;
	if (nlhs == 1) {
	  if (nrhs == 5) { // no index data output with input
	    readHeader(f_name, password, &tot_index_fields, &num_samples, &index_data_offset, &max_block_length, encryptionKey);
	    index_data = (unsigned long long int *) mxGetPr(prhs[4]);
	  } else { //no index data output without input
	     readHeader(f_name, password, &tot_index_fields, &num_samples, &index_data_offset, &max_block_length, encryptionKey);
	    index_data = (unsigned long long int *) malloc(tot_index_fields * sizeof(unsigned long long int));
	    if (index_data == NULL) {
		printf("[decomp_mef2] could not allocate enough memory for file \"%s\" => exiting\n", f_name);
		return;
	    }
	    freeFlag = 1;
	    readIndex(f_name, password, tot_index_fields, index_data_offset, index_data);
	  }
	} else {
	  if (nrhs == 5 ) { // index data output with index data input (slowest, but no one should do this)
	    readHeader(f_name, password, &tot_index_fields, &num_samples, &index_data_offset, &max_block_length, encryptionKey);
	    plhs[1] = mxCreateNumericMatrix(tot_index_fields, 1, mxUINT64_CLASS, mxREAL);
	    index_data = (unsigned long long int *) mxGetPr(plhs[1]);
	    index_data_input = (unsigned long long int *) mxGetPr(prhs[4]);
	    memcpy(index_data, index_data_input, tot_index_fields * sizeof(unsigned long long int));
	  } else { // index data output with no index data input
	    readHeader(f_name, password, &tot_index_fields, &num_samples, &index_data_offset, &max_block_length, encryptionKey);
	    plhs[1] = mxCreateNumericMatrix(tot_index_fields, 1, mxUINT64_CLASS, mxREAL);
	    index_data = (unsigned long long int *) mxGetPr(plhs[1]);
	    readIndex(f_name, password, tot_index_fields, index_data_offset, index_data);
	  }
	}

	/*--------------------------------------------------------------------------------------------------------------------------------------------------------------*/	

	// Set the output pointer to the output data matrix. 
	long_decomp_data_len = end_idx - start_idx + (unsigned long long int) 1;
	if (long_decomp_data_len >= (unsigned long long int) (1 << 31)) {
		mexErrMsgTxt("[decomp_mef2] requested memory exceeds Matlab limit => exiting");
		return;
	}
	decomp_data_len = (int) long_decomp_data_len;
	dims[0] = decomp_data_len; dims[1] = 1;
	plhs[0] = mxCreateNumericArray(2, dims, mxINT32_CLASS, mxREAL);
	
	// Create a C pointer to a copy of the output matrix. 
	decomp_data = (int *) mxGetPr(plhs[0]);
	if (decomp_data == NULL) {
		mexErrMsgTxt("[decomp_mef2] could not allocate enough memory => exiting");
		return;
	}



	/*------------------------------------------------------------------ALLISON CODE---------------------------------------------------------------------------*/
	// Call the C subroutine. 
	decomp_mef2(f_name, encryptionKey, tot_index_fields, num_samples, index_data_offset, max_block_length, index_data, start_idx, end_idx, password, decomp_data);
	    
	if (freeFlag == 1) {
	  free(index_data);
	}
	
	return;
} 
