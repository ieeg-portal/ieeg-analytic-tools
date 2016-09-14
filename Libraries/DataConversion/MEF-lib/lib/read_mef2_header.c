//
//
// 
// mex read_mef2_header.c RED_decode.c endian_functions.c mef_lib.c AES_encryption.c
//
//

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "mex.h"
#include "matrix.h"
#include "mef_header_2_0.h"
#include "mef_lib.h"
#include "RED_codec.h"

#define BIG_ENDIAN_CODE		0
#define LITTLE_ENDIAN_CODE	1

void read_mef2_header(char *f_name, MEF_HEADER_INFO *hdr_info, char *password)
{
	char			*c, *comp_data;
	unsigned char		*header;
	unsigned int		cpu_endianness, n_read;
	unsigned int		i;
//	unsigned long long int	start_block_file_offset, end_block_file_offset, start_block_idx, end_block_idx;
//	unsigned long long int	*index_data, last_block_len, RED_decompress_block();
	FILE			*fp;
	
	/* get cpu endianness */
	cpu_endianness = 1;
	c = (char *) &cpu_endianness;
	cpu_endianness = (unsigned int) *c;
	if (cpu_endianness != LITTLE_ENDIAN_CODE) {
		mexErrMsgTxt("[read_mef2_header] is currently only compatible with little-endian machines => exiting");
		return;
	}
	
	/* read header */
	fp = fopen(f_name, "r");
	if (fp == NULL) { 
		printf("[read_mef2_header] could not open the file \"%s\" => exiting\n",  f_name);
		return;
	}
	header = (unsigned char *) malloc(MEF_HEADER_LENGTH);  // malloc to ensure boundary alignment
	n_read = fread((void *) header, sizeof(char), (size_t) MEF_HEADER_LENGTH, fp);
	if (n_read != MEF_HEADER_LENGTH) {
		printf("[read_mef2_header] error reading the file \"%s\" => exiting\n",  f_name);
		return;
	}	
	if ((read_mef_header_block(header, hdr_info, password))) {
		printf("[read_mef2_header] header read error for file \"%s\" => exiting\n", f_name);
		return;		
	}
	free(header);
	
	/* get file endianness */
	if (hdr_info->byte_order_code != LITTLE_ENDIAN_CODE) {
		mexErrMsgTxt("[read_mef2_header] is currently only compatible with little-endian files (file \"%s\") => exiting");
		return;
	}

	return;
}


// The mex gateway routine 
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	char		*f_name, *password;
	unsigned char *ucp;
	mxArray		*fout;
	const mwSize	dims[] = {1,8};
	int			buf_len, status, i, hdr_struct_len;
	unsigned long long int	start_idx, end_idx, long_decomp_data_len;
	void			read_mef2_header();
	MEF_HEADER_INFO header;
	const char		*fnames[] = {	"institution", "unencrypted_text_field", "encryption_algorithm", 
		"subject_encryption_used", "session_encryption_used", "data_encryption_used", "byte_order_code", 
		"header_version_major", "header_version_minor", "session_unique_ID", "header_length", 
		"subject_first_name", "subject_second_name", "subject_third_name", "subject_id", "session_password", 
		"number_of_samples", "channel_name", "recording_start_time", "recording_end_time", "sampling_frequency", 
		"low_frequency_filter_setting", "high_frequency_filter_setting", "notch_filter_frequency", 
		"voltage_conversion_factor", "acquisition_system", "channel_comments", "study_comments", 
		"physical_channel_number", "compression_algorithm", "maximum_compressed_block_size", "maximum_block_length", 
		"block_interval", "maximum_data_value", "minimum_data_value", "index_data_offset", "number_of_index_entries"	};	

	//  Check for proper number of arguments 
	if (nrhs != 2) 
		mexErrMsgTxt("[read_mef2_header] two inputs required: file_name, password");
	if (nlhs != 1) 
		mexErrMsgTxt("[read_mef2_header] one output required: header_structure");
	
	// get the input file name (argument 1)
	if (mxIsChar(prhs[0]) != 1) { // Check to make sure the first input argument is a string 
		mexErrMsgTxt("[read_mef2_header] file name must be a string => exiting");
		return;
	}		
	buf_len = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 2; // Get the length of the input string 
	f_name = malloc(buf_len); // Allocate memory for file_name string
	status = mxGetString(prhs[0], f_name, buf_len);
	if (status != 0) {
		mexWarnMsgTxt("[read_mef2_header] not enough space for input file name string => exiting");
		return;
	}
	

	// get the password (argument 2)
	if (mxIsChar(prhs[1]) != 1) { // Check to make sure the fourth input argument is a string 
		mexErrMsgTxt("[read_mef2_header] Password must be a stringx => exiting");
		return;
	}	
	buf_len = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 2; // Get the length of the input string 
	password = malloc(buf_len); // Allocate memory for file_name string
	status = mxGetString(prhs[1], password, buf_len);
	if (status != 0) {
		mexErrMsgTxt("[read_mef2_header] not enough space for password string => exiting");
		return;
	}

	// Set the output pointer to the output matrix. 
	hdr_struct_len = sizeof(MEF_HEADER_INFO);
	if (hdr_struct_len >= (unsigned long long int) (1 << 31)) {
		mexErrMsgTxt("[read_mef2_header] requested memory exceeds Matlab limit => exiting");
		return;
	}	
	
	// Call the C subroutine. 
	read_mef2_header(f_name, &header, password);
	
	//create output structure
	plhs[0] = mxCreateStructMatrix(1, 1, 37, fnames);
	
	
	//populate structure with header information
	fout = mxCreateString(header.institution);
	mxSetFieldByNumber(plhs[0], 0, 0, fout);
	
	fout = mxCreateString(header.unencrypted_text_field);
	mxSetFieldByNumber(plhs[0], 0, 1, fout);
	
	fout = mxCreateString(header.encryption_algorithm);
	mxSetFieldByNumber(plhs[0], 0, 2, fout);
	
	fout = mxCreateLogicalScalar(header.subject_encryption_used);
	mxSetFieldByNumber(plhs[0], 0, 3, fout);
	
	fout = mxCreateLogicalScalar(header.session_encryption_used);
	mxSetFieldByNumber(plhs[0], 0, 4, fout);
	
	fout = mxCreateLogicalScalar(header.data_encryption_used);
	mxSetFieldByNumber(plhs[0], 0, 5, fout);

	if (header.byte_order_code) fout = mxCreateString("little-endian");
	else fout = mxCreateString("big-endian");
	mxSetFieldByNumber(plhs[0], 0, 6, fout);
	
	fout = mxCreateDoubleScalar((double)header.header_version_major);
	mxSetFieldByNumber(plhs[0], 0, 7, fout);

	fout = mxCreateDoubleScalar((double)header.header_version_minor);
	mxSetFieldByNumber(plhs[0], 0, 8, fout);
	
	fout = mxCreateNumericArray(2, dims, mxUINT8_CLASS, mxREAL); /////// fill in values here-----
	ucp = (unsigned char *)mxGetData(fout);
	for (i=0; i<8; i++) ucp[i] = header.session_unique_ID[i];
	mxSetFieldByNumber(plhs[0], 0, 9, fout);

	fout = mxCreateDoubleScalar((double)header.header_length);
	mxSetFieldByNumber(plhs[0], 0, 10, fout);

	fout = mxCreateString(header.subject_first_name);
	mxSetFieldByNumber(plhs[0], 0, 11, fout);
	
	fout = mxCreateString(header.subject_second_name);
	mxSetFieldByNumber(plhs[0], 0, 12, fout);	
	
	fout = mxCreateString(header.subject_third_name);
	mxSetFieldByNumber(plhs[0], 0, 13, fout);	
	
	fout = mxCreateString(header.subject_id);
	mxSetFieldByNumber(plhs[0], 0, 14, fout);	
	
	fout = mxCreateString(header.session_password);
	mxSetFieldByNumber(plhs[0], 0, 15, fout);	
	
	fout = mxCreateDoubleScalar((double)header.number_of_samples);
	mxSetFieldByNumber(plhs[0], 0, 16, fout);
	
	fout = mxCreateString(header.channel_name);
	mxSetFieldByNumber(plhs[0], 0, 17, fout);
	
	fout = mxCreateDoubleScalar((double)header.recording_start_time);
	mxSetFieldByNumber(plhs[0], 0, 18, fout);
	
	fout = mxCreateDoubleScalar((double)header.recording_end_time);
	mxSetFieldByNumber(plhs[0], 0, 19, fout);
	
	fout = mxCreateDoubleScalar(header.sampling_frequency);
	mxSetFieldByNumber(plhs[0], 0, 20, fout);
	
	fout = mxCreateDoubleScalar(header.low_frequency_filter_setting);
	mxSetFieldByNumber(plhs[0], 0, 21, fout);
	
	fout = mxCreateDoubleScalar(header.high_frequency_filter_setting);
	mxSetFieldByNumber(plhs[0], 0, 22, fout);
	
	fout = mxCreateDoubleScalar(header.notch_filter_frequency);
	mxSetFieldByNumber(plhs[0], 0, 23, fout);
	
	fout = mxCreateDoubleScalar(header.voltage_conversion_factor);
	mxSetFieldByNumber(plhs[0], 0, 24, fout);
	
	fout = mxCreateString(header.acquisition_system);
	mxSetFieldByNumber(plhs[0], 0, 25, fout);
	
	fout = mxCreateString(header.channel_comments);
	mxSetFieldByNumber(plhs[0], 0, 26, fout);
	
	fout = mxCreateString(header.study_comments);
	mxSetFieldByNumber(plhs[0], 0, 27, fout);
	
	fout = mxCreateDoubleScalar((double)header.physical_channel_number);
	mxSetFieldByNumber(plhs[0], 0, 28, fout);
	
	fout = mxCreateString(header.compression_algorithm);
	mxSetFieldByNumber(plhs[0], 0, 29, fout);
	
	fout = mxCreateDoubleScalar((double)header.maximum_compressed_block_size);
	mxSetFieldByNumber(plhs[0], 0, 30, fout);

	fout = mxCreateDoubleScalar((double)header.maximum_block_length);
	mxSetFieldByNumber(plhs[0], 0, 31, fout);
	
	fout = mxCreateDoubleScalar((double)header.block_interval);
	mxSetFieldByNumber(plhs[0], 0, 32, fout);
	
	fout = mxCreateDoubleScalar((double)header.maximum_data_value);
	mxSetFieldByNumber(plhs[0], 0, 33, fout);

	fout = mxCreateDoubleScalar((double)header.minimum_data_value);
	mxSetFieldByNumber(plhs[0], 0, 34, fout);
	
	fout = mxCreateDoubleScalar((double)header.index_data_offset);
	mxSetFieldByNumber(plhs[0], 0, 35, fout);
	
	fout = mxCreateDoubleScalar((double)header.number_of_index_entries);
	mxSetFieldByNumber(plhs[0], 0, 36, fout);
	
	free(f_name);
	free(password);
	
	return;
} 
