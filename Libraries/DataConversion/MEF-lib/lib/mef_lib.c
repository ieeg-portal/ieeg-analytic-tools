//	MEF library
//	Note: need to compile with AES_encryption.c, RED_encode.c and RED_decode.c
//

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "size_types.h"
#include "mef_header_2_0.h"
#include "RED_codec.h"
#include "mef_lib.h"


#define EXPORT __attribute__((visibility("default")))
#define EPSILON 0.0001
#define FLOAT_EQUAL(x,y) ( ((y - EPSILON) < x) && (x <( y + EPSILON)) )


//==============================================================================================
//
//	si4	build_mef_header_block(ui1 *encrypted_hdr_block, MEF_HEADER_INFO *hdr_struct, si1 *password)
//
//	inputs: 
//		unsigned char pointer to writable block header space
//		pointer to mef header structure containing hdr information
//		subject password 
//
//	return values:
//		0 for success, 1 for failure
//
//	this routine fills in block with values from the hdr structure, then encrypts the block header 
//	using 128 bit AES decryption using session and subject passwords as the encryption keys. File password is read
//	from the header structure
//
//	
//

EXPORT
	#include <sys/time.h>
	
	#include <fcntl.h>
	#include <stdlib.h>
	#include <time.h>
	#include <unistd.h>
	srandomdev(void)
	{
	        struct timeval tv;
	        unsigned int seed;
	        int fd;
	
	        if ((fd = open("/dev/urandom", O_RDONLY)) >= 0 ||
	            (fd = open("/dev/random", O_RDONLY)) >= 0) {
	                read(fd, &seed, sizeof seed);
	                close(fd);
	        } else {
	                gettimeofday(&tv, NULL);
	                seed = (getpid() << 16) ^ tv.tv_sec ^ tv.tv_usec;
	        }
	        srandom(seed);
	}

si4	build_mef_header_block(ui1 *encrypted_hdr_block, MEF_HEADER_INFO *hdr_struct, si1 *password)
{
	MEF_HEADER_INFO	*hs;
	si4		i, encrypted_segments, l, *rn;
	ui1		*ehbp, *ehb;
	void		AES_encrypt();

	//check inputs
	if (hdr_struct == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL structure pointer passed\n", __FUNCTION__);
		return(1);
	}
	
	if (encrypted_hdr_block == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL header block pointer passed\n", __FUNCTION__);
		return(1);
	}
	
	if (password == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL password pointer passed\n", __FUNCTION__);
		return(1);
	}	
	
	check_header_block_alignment(encrypted_hdr_block);
	
	ehb = encrypted_hdr_block;
	hs = hdr_struct;
	
	/* check passwords */
	if (hs->subject_encryption_used) 
	{
		l = (si4) strlen(password); //entered password should be subject
		if (l >= ENCRYPTION_BLOCK_BYTES || l == 0) {
			(void) printf("\n%s: subject password error\n", __FUNCTION__);
			return(1);
		}
	}
	if (hs->session_encryption_used)
	{
		if (hs->subject_encryption_used) //subject AND session encryption used:
			l = (si4) strlen(hs->session_password);   // session password taken from the mef header structure
		else //session encryption ONLY used
		{
			l = (si4) strlen(password); //entered password should be session
			if (l == 0)
			{
				//OR - session password may just be in the header - copy to password field
				l = (si4) strlen(hs->session_password);
				if (l) strncpy2(password, hs->session_password, SESSION_PASSWORD_LENGTH); //no need for else here- l=0 case passes to error check below
			}
			else
			{
				//if session password isn't in header structure copy it there
				if (hs->session_password[0] == 0)
					strncpy2(hs->session_password, password, SESSION_PASSWORD_LENGTH);
			} //Now session password should be in both the header and the password variable
		}
		if (l >= ENCRYPTION_BLOCK_BYTES || l == 0) {
			(void) printf("\n%s: session password error\n", __FUNCTION__);
			return(1);
		}
	}
	
	if (hs->subject_encryption_used || hs->session_encryption_used) {
		/* fill header with random numbers */
		srandomdev();
		rn = (si4 *) ehb;
		for (i = MEF_HEADER_LENGTH / 4; i--;)
			*rn++ = (si4)random();
	}
	
	/* build unencrypted block */
	strncpy2((si1 *) (ehb + INSTITUTION_OFFSET), hs->institution, INSTITUTION_LENGTH);
	strncpy2((si1 *) (ehb + UNENCRYPTED_TEXT_FIELD_OFFSET), hs->unencrypted_text_field, UNENCRYPTED_TEXT_FIELD_LENGTH);	
	sprintf((si1 *) (ehb + ENCRYPTION_ALGORITHM_OFFSET), "%d-bit AES", ENCRYPTION_BLOCK_BITS);	
	*((ui1 *) (ehb + SUBJECT_ENCRYPTION_USED_OFFSET)) = hs->subject_encryption_used;		
	*((ui1 *) (ehb + SESSION_ENCRYPTION_USED_OFFSET)) = hs->session_encryption_used;		
	*((ui1 *) (ehb + DATA_ENCRYPTION_USED_OFFSET)) = hs->data_encryption_used;		
	*(ehb + BYTE_ORDER_CODE_OFFSET) = hs->byte_order_code;				
//	strncpy2((si1 *) (ehb + FILE_TYPE_OFFSET), hs->file_type, FILE_TYPE_LENGTH);		
	*(ehb + HEADER_MAJOR_VERSION_OFFSET) = hs->header_version_major;	
	*(ehb + HEADER_MINOR_VERSION_OFFSET) = hs->header_version_minor;			
	memcpy(ehb + SESSION_UNIQUE_ID_OFFSET, hs->session_unique_ID, SESSION_UNIQUE_ID_LENGTH);
	*((ui2 *) (ehb + HEADER_LENGTH_OFFSET)) = hs->header_length;
	
	/* build subject encrypted block */
	strncpy2((si1 *) (ehb + SUBJECT_FIRST_NAME_OFFSET), hs->subject_first_name, SUBJECT_FIRST_NAME_LENGTH);	
	strncpy2((si1 *) (ehb + SUBJECT_SECOND_NAME_OFFSET), hs->subject_second_name, SUBJECT_SECOND_NAME_LENGTH);
	strncpy2((si1 *) (ehb + SUBJECT_THIRD_NAME_OFFSET), hs->subject_third_name, SUBJECT_THIRD_NAME_LENGTH);
	strncpy2((si1 *) (ehb + SUBJECT_ID_OFFSET), hs->subject_id, SUBJECT_ID_LENGTH);
	
	if (hs->session_encryption_used && hs->subject_encryption_used)
		strncpy2((si1 *) (ehb + SESSION_PASSWORD_OFFSET), hs->session_password, SESSION_PASSWORD_LENGTH);
	else
		*(si1 *) (ehb + SESSION_PASSWORD_OFFSET) = 0;
	
	/* apply subject encryption to subject block */
	if (hs->subject_encryption_used) {
		//copy subject password into validation field in pascal format string
		l = (ui1) strlen(password);
		*(ehb + SUBJECT_VALIDATION_FIELD_OFFSET) = l;
		memcpy(ehb + SUBJECT_VALIDATION_FIELD_OFFSET + 1, password, l);  //memcpy doesn't add a trailing zero		
		
		encrypted_segments = SUBJECT_ENCRYPTION_LENGTH / ENCRYPTION_BLOCK_BYTES;
		ehbp = ehb + SUBJECT_ENCRYPTION_OFFSET;
		for (i = encrypted_segments; i--;) {
			AES_encrypt(ehbp, ehbp, password);
			ehbp += ENCRYPTION_BLOCK_BYTES;
		}
	}
	
	/* build session encrypted block */
	*((ui8 *) (ehb + NUMBER_OF_SAMPLES_OFFSET)) = hs->number_of_samples;
	strncpy2((si1 *) (ehb + CHANNEL_NAME_OFFSET), hs->channel_name, CHANNEL_NAME_LENGTH);	
	*((ui8 *) (ehb + RECORDING_START_TIME_OFFSET)) = hs->recording_start_time;
	*((ui8 *) (ehb + RECORDING_END_TIME_OFFSET)) = hs->recording_end_time;
	*((sf8 *) (ehb + SAMPLING_FREQUENCY_OFFSET)) = hs->sampling_frequency;	
	*((sf8 *) (ehb + LOW_FREQUENCY_FILTER_SETTING_OFFSET)) = hs->low_frequency_filter_setting;
	*((sf8 *) (ehb + HIGH_FREQUENCY_FILTER_SETTING_OFFSET)) = hs->high_frequency_filter_setting;
	*((sf8 *) (ehb + NOTCH_FILTER_FREQUENCY_OFFSET)) = hs->notch_filter_frequency;
	*((sf8 *) (ehb + VOLTAGE_CONVERSION_FACTOR_OFFSET)) = hs->voltage_conversion_factor;	
	strncpy2((si1 *) (ehb + ACQUISITION_SYSTEM_OFFSET), hs->acquisition_system, ACQUISITION_SYSTEM_LENGTH);
	strncpy2((si1 *) (ehb + CHANNEL_COMMENTS_OFFSET), hs->channel_comments, CHANNEL_COMMENTS_LENGTH);
	strncpy2((si1 *) (ehb + STUDY_COMMENTS_OFFSET), hs->study_comments, STUDY_COMMENTS_LENGTH);
	*((si4 *) (ehb + PHYSICAL_CHANNEL_NUMBER_OFFSET)) = hs->physical_channel_number;
	strncpy2((si1 *) (ehb + COMPRESSION_ALGORITHM_OFFSET), hs->compression_algorithm, COMPRESSION_ALGORITHM_LENGTH);
	*((ui4 *) (ehb + MAXIMUM_COMPRESSED_BLOCK_SIZE_OFFSET)) = hs->maximum_compressed_block_size;
	*((ui8 *) (ehb + MAXIMUM_BLOCK_LENGTH_OFFSET)) = hs->maximum_block_length;
	*((ui8 *) (ehb + BLOCK_INTERVAL_OFFSET)) = hs->block_interval;
	*((si4 *) (ehb + MAXIMUM_DATA_VALUE_OFFSET)) = hs->maximum_data_value;
	*((si4 *) (ehb + MINIMUM_DATA_VALUE_OFFSET)) = hs->minimum_data_value;
	*((ui8 *) (ehb + INDEX_DATA_OFFSET_OFFSET)) = hs->index_data_offset;
	*((ui8 *) (ehb + NUMBER_OF_INDEX_ENTRIES_OFFSET)) = hs->number_of_index_entries;
	*((ui8 *) (ehb + BLOCK_HEADER_LENGTH_OFFSET)) = hs->block_header_length;
	
	// apply session encryption to session block
	if (hs->session_encryption_used) {
		//copy session password into password validation field in pascal format string
		l = (ui1) strlen(hs->session_password);
		*(ehb + SESSION_VALIDATION_FIELD_OFFSET) = l;
		memcpy(ehb + SESSION_VALIDATION_FIELD_OFFSET + 1, hs->session_password, l);  //memcpy doesn't add a trailing zero		
		
		encrypted_segments = SESSION_ENCRYPTION_LENGTH / ENCRYPTION_BLOCK_BYTES;
		ehbp = ehb + SESSION_ENCRYPTION_OFFSET;
		for (i = encrypted_segments; i--;) {
			AES_encrypt(ehbp, ehbp, hs->session_password);
			ehbp += ENCRYPTION_BLOCK_BYTES;
		}
	}
		
	return(0);
}

//==============================================================================================
//
//	si4	read_mef_header_block(ui1 *header_block, MEF_HEADER_INFO *header_struct, si1 *password)
//
//	inputs: 
//		unsigned char pointer to encrypted block header
//		pointer to mef header structure
//		password 
//
//	return values:
//		0 for success, 1 for failure
//
//	this routine decrypts the block header using 128 bit AES decryption using password as the decryption key
//	(checking to see if it's subject or session pwd), then fills in hdr structure with decrypted values
//
//	
//
EXPORT
si4	read_mef_header_block(ui1 *header_block, MEF_HEADER_INFO *header_struct, si1 *password)
{
	MEF_HEADER_INFO	*hs;
	si4		i, privileges, encrypted_segments, session_is_readable, subject_is_readable;
	si1		*encrypted_string;
	ui1		*hb, *dhbp, dhb[MEF_HEADER_LENGTH], cpu_endianness();
	si1		dummy;
	void	AES_decrypt();
	si2		rev_si2();
	ui2		rev_ui2();
	ui8		rev_ui8();
	sf8		rev_sf8();
	si4		rev_si4(),  validate_password();
	ui4		rev_ui4();
	
	//check inputs
	if (header_struct == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL structure pointer passed\n", __FUNCTION__);
		return(1);
	}
	
	if (header_block == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL header block pointer passed\n", __FUNCTION__);
		return(1);
	}
	
	check_header_block_alignment(header_block);

	hb = header_block;
	hs = header_struct;
	subject_is_readable = 0; session_is_readable = 0;
	encrypted_string = "encrypted";
	
	/* check to see if encryption algorithm matches that assumed by this function */
	(void) sprintf((si1 *) dhb, "%d-bit AES", ENCRYPTION_BLOCK_BITS);
	if (strcmp((si1 *) hb + ENCRYPTION_ALGORITHM_OFFSET, (si1 *) dhb)) {
		(void) fprintf(stderr, "%s: unknown encryption algorithm\n", __FUNCTION__);
		return(1);
	}

	memcpy(dhb, header_block, MEF_HEADER_LENGTH);
	memset(header_struct, 0, sizeof(MEF_HEADER_INFO));
	
	//read all unencrypted fields
	strncpy2(hs->institution, (si1 *) (dhb + INSTITUTION_OFFSET), INSTITUTION_LENGTH);
	strncpy2(hs->unencrypted_text_field, (si1 *) (dhb + UNENCRYPTED_TEXT_FIELD_OFFSET), UNENCRYPTED_TEXT_FIELD_LENGTH);
	strncpy2(hs->encryption_algorithm, (si1 *) (dhb + ENCRYPTION_ALGORITHM_OFFSET), ENCRYPTION_ALGORITHM_LENGTH);
	hs->byte_order_code = *(dhb + BYTE_ORDER_CODE_OFFSET);
	hs->header_version_major = *(dhb + HEADER_MAJOR_VERSION_OFFSET);
	hs->header_version_minor = *(dhb + HEADER_MINOR_VERSION_OFFSET);
	for(i=0; i<SESSION_UNIQUE_ID_LENGTH; i++)
		hs->session_unique_ID[i] = *(dhb + SESSION_UNIQUE_ID_OFFSET + i*sizeof(ui1));
	
	if (hs->byte_order_code ^ cpu_endianness()) 
		hs->header_length = rev_ui2(*((ui2 *) (dhb + HEADER_LENGTH_OFFSET)));
	else
		hs->header_length = *((ui2 *) (dhb + HEADER_LENGTH_OFFSET));
	
	hs->subject_encryption_used = *(dhb + SUBJECT_ENCRYPTION_USED_OFFSET);
	hs->session_encryption_used = *(dhb + SESSION_ENCRYPTION_USED_OFFSET);
	hs->data_encryption_used = *(dhb + DATA_ENCRYPTION_USED_OFFSET);
	
		
	if(hs->subject_encryption_used==0) subject_is_readable = 1;
	if(hs->session_encryption_used==0) session_is_readable = 1;
	
	if (password == NULL)
	{
		password = &dummy;
		*password = 0;
		privileges = 0;
	}
	else
	{
		// get password privileges
		privileges = validate_password(hb, password);
		if ( (privileges==0) && (password[0]!=0) ) { 
			(void) fprintf(stderr, "%s: unrecognized password\n", __FUNCTION__);
			return(1);
		}
	}
	

	if (hs->subject_encryption_used && (privileges == 1)) //subject encryption case
	{
		//decrypt subject encryption block, fill in structure fields
		encrypted_segments = SUBJECT_ENCRYPTION_LENGTH / ENCRYPTION_BLOCK_BYTES;
		dhbp = dhb + SUBJECT_ENCRYPTION_OFFSET;
		for (i = encrypted_segments; i--;) 
		{
			AES_decrypt(dhbp, dhbp, password);
			dhbp += ENCRYPTION_BLOCK_BYTES;
		}
		subject_is_readable = 1;
	}
	
	if(subject_is_readable) {
		strncpy2(hs->subject_first_name, (si1 *) (dhb + SUBJECT_FIRST_NAME_OFFSET), SUBJECT_FIRST_NAME_LENGTH);
		strncpy2(hs->subject_second_name, (si1 *) (dhb + SUBJECT_SECOND_NAME_OFFSET), SUBJECT_SECOND_NAME_LENGTH);
		strncpy2(hs->subject_third_name, (si1 *) (dhb + SUBJECT_THIRD_NAME_OFFSET), SUBJECT_THIRD_NAME_LENGTH);
		strncpy2(hs->subject_id, (si1 *) (dhb + SUBJECT_ID_OFFSET), SUBJECT_ID_LENGTH);
		if (hs->session_encryption_used && hs->subject_encryption_used ) //if both subject and session encryptions used, session password should be in hdr
			strncpy2(hs->session_password, (si1 *) (dhb + SESSION_PASSWORD_OFFSET), SESSION_PASSWORD_LENGTH);
		else if (hs->session_encryption_used)
			strncpy2(hs->session_password, password, SESSION_PASSWORD_LENGTH);
	} 
	else { 
		//subject encryption used but not decoded
		strncpy2(hs->subject_first_name, encrypted_string, SUBJECT_FIRST_NAME_LENGTH);
		strncpy2(hs->subject_second_name, encrypted_string, SUBJECT_SECOND_NAME_LENGTH);
		strncpy2(hs->subject_third_name, encrypted_string, SUBJECT_THIRD_NAME_LENGTH);
		strncpy2(hs->subject_id, encrypted_string, SUBJECT_ID_LENGTH);
		strncpy2(hs->session_password, password, SESSION_PASSWORD_LENGTH); //session password must be passed in if no subject encryption used
	}
		
	if (hs->session_encryption_used && privileges > 0)
	{
		// decrypt session password encrypted fields 
		encrypted_segments = SESSION_ENCRYPTION_LENGTH / ENCRYPTION_BLOCK_BYTES;
		dhbp = dhb + SESSION_ENCRYPTION_OFFSET;
		for (i = encrypted_segments; i--;) 
		{
			AES_decrypt(dhbp, dhbp, hs->session_password);
			dhbp += ENCRYPTION_BLOCK_BYTES;
		}
		session_is_readable = 1;
	}
	
	if (session_is_readable)
	{
		// session password encrypted fields 
		strncpy2(hs->channel_name, (si1 *) (dhb + CHANNEL_NAME_OFFSET), CHANNEL_NAME_LENGTH);
		strncpy2(hs->acquisition_system, (si1 *) (dhb + ACQUISITION_SYSTEM_OFFSET), ACQUISITION_SYSTEM_LENGTH);
		strncpy2(hs->channel_comments, (si1 *) (dhb + CHANNEL_COMMENTS_OFFSET), CHANNEL_COMMENTS_LENGTH);
		strncpy2(hs->study_comments, (si1 *) (dhb + STUDY_COMMENTS_OFFSET), STUDY_COMMENTS_LENGTH);
		strncpy2(hs->compression_algorithm, (si1 *) (dhb + COMPRESSION_ALGORITHM_OFFSET), COMPRESSION_ALGORITHM_LENGTH);
		
		// reverse bytes in some fields for endian mismatch 
		if (hs->byte_order_code ^ cpu_endianness()) {
			//printf("Reversing byte order\n");
			hs->number_of_samples = rev_ui8(*((ui8 *) (dhb + NUMBER_OF_SAMPLES_OFFSET)));
			hs->recording_start_time = rev_ui8(*((ui8 *) (dhb + RECORDING_START_TIME_OFFSET)));
			hs->recording_end_time = rev_ui8(*((ui8 *) (dhb + RECORDING_END_TIME_OFFSET)));
			hs->sampling_frequency = rev_sf8(*((sf8 *) (dhb + SAMPLING_FREQUENCY_OFFSET)));
			hs->low_frequency_filter_setting = rev_sf8(*((sf8 *) (dhb + LOW_FREQUENCY_FILTER_SETTING_OFFSET)));
			hs->high_frequency_filter_setting = rev_sf8(*((sf8 *) (dhb + HIGH_FREQUENCY_FILTER_SETTING_OFFSET)));
			hs->notch_filter_frequency = rev_sf8(*((sf8 *) (dhb + NOTCH_FILTER_FREQUENCY_OFFSET)));
			hs->voltage_conversion_factor = rev_sf8(*((sf8 *) (dhb + VOLTAGE_CONVERSION_FACTOR_OFFSET)));
			hs->block_interval = rev_ui8(*((ui8 *) (dhb + BLOCK_INTERVAL_OFFSET)));
			hs->physical_channel_number = rev_si4(*((si4 *) (dhb + PHYSICAL_CHANNEL_NUMBER_OFFSET)));
			hs->maximum_compressed_block_size = rev_ui4(*((ui4 *) (dhb + MAXIMUM_COMPRESSED_BLOCK_SIZE_OFFSET)));
			hs->maximum_block_length = rev_ui8( *((ui8 *) (dhb + MAXIMUM_BLOCK_LENGTH_OFFSET)) );
			hs->maximum_data_value = rev_si4( *((si4 *) (dhb + MAXIMUM_DATA_VALUE_OFFSET)) );
			hs->minimum_data_value = rev_si4( *((si4 *) (dhb + MINIMUM_DATA_VALUE_OFFSET)) );
			hs->index_data_offset = rev_si4(*((ui8 *) (dhb + INDEX_DATA_OFFSET_OFFSET)));
			hs->number_of_index_entries = rev_si4(*((ui8 *) (dhb + NUMBER_OF_INDEX_ENTRIES_OFFSET)));
			hs->block_header_length = rev_ui2(*((ui2 *) (dhb + BLOCK_HEADER_LENGTH_OFFSET)));
		} else {
			//printf("Byte order matches CPU\n");
			hs->number_of_samples = *((ui8 *) (dhb + NUMBER_OF_SAMPLES_OFFSET));
			hs->recording_start_time = *((ui8 *) (dhb + RECORDING_START_TIME_OFFSET));
			hs->recording_end_time = *((ui8 *) (dhb + RECORDING_END_TIME_OFFSET));
			hs->sampling_frequency = *((sf8 *) (dhb + SAMPLING_FREQUENCY_OFFSET));
			hs->low_frequency_filter_setting = *((sf8 *) (dhb + LOW_FREQUENCY_FILTER_SETTING_OFFSET));
			hs->high_frequency_filter_setting = *((sf8 *) (dhb + HIGH_FREQUENCY_FILTER_SETTING_OFFSET));
			hs->notch_filter_frequency = *((sf8 *) (dhb + NOTCH_FILTER_FREQUENCY_OFFSET));
			hs->voltage_conversion_factor = *((sf8 *) (dhb + VOLTAGE_CONVERSION_FACTOR_OFFSET));
			hs->block_interval = *((ui8 *) (dhb + BLOCK_INTERVAL_OFFSET));
			hs->physical_channel_number = *((si4 *) (dhb + PHYSICAL_CHANNEL_NUMBER_OFFSET));
			hs->maximum_compressed_block_size = *((ui4 *) (dhb + MAXIMUM_COMPRESSED_BLOCK_SIZE_OFFSET));
			hs->maximum_block_length = *((ui8 *) (dhb + MAXIMUM_BLOCK_LENGTH_OFFSET));
			hs->maximum_data_value = *((si4 *) (dhb + MAXIMUM_DATA_VALUE_OFFSET));
			hs->minimum_data_value = *((si4 *) (dhb + MINIMUM_DATA_VALUE_OFFSET));
			hs->index_data_offset = *((ui8 *) (dhb + INDEX_DATA_OFFSET_OFFSET));
			hs->number_of_index_entries = *((ui8 *) (dhb + NUMBER_OF_INDEX_ENTRIES_OFFSET));
			hs->block_header_length = *((ui2 *) (dhb + BLOCK_HEADER_LENGTH_OFFSET));
		}
	}
	else {
		//session not readable - fill with encrypted strings
		strncpy2(hs->channel_name, encrypted_string, CHANNEL_NAME_LENGTH);
		strncpy2(hs->acquisition_system, encrypted_string, ACQUISITION_SYSTEM_LENGTH);
		strncpy2(hs->channel_comments, encrypted_string, CHANNEL_COMMENTS_LENGTH);
		strncpy2(hs->study_comments, encrypted_string, STUDY_COMMENTS_LENGTH);
		strncpy2(hs->compression_algorithm, encrypted_string, COMPRESSION_ALGORITHM_LENGTH);

		hs->number_of_samples = 0;
		hs->recording_start_time = 0;
		hs->recording_end_time = 0;
		hs->sampling_frequency = -1.0;
		hs->low_frequency_filter_setting = -1.0;
		hs->high_frequency_filter_setting = -1.0;
		hs->notch_filter_frequency = -1.0;
		hs->voltage_conversion_factor = 0.0;
		hs->block_interval = 0;
		hs->physical_channel_number = -1;
		hs->maximum_compressed_block_size = 0;
		hs->maximum_block_length = 0;
		hs->index_data_offset = 0;
		hs->number_of_index_entries = 0;
		hs->block_header_length = 0;
	}
	
	return(0);
}

//=================================================================================================================
//si4	validate_password(ui1 *header_block, si1 *password)
//
//check password for validity - returns 1 for subject password, 2 for session password, 0 for no match
//
EXPORT
si4	validate_password(ui1 *header_block, si1 *password)
{	
	ui1	decrypted_header[MEF_HEADER_LENGTH], *hbp, *dhbp;
	si1 temp_str[SESSION_PASSWORD_LENGTH];
	si4	encrypted_segments, l, i;
	void	AES_decrypt();
	
	//check for null pointers
	if (header_block == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL header pointer passed\n", __FUNCTION__);
		return(1);
	}

	if (password == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL string pointer passed\n", __FUNCTION__);
		return(1);
	}
	
	//check password length
	l = (si4) strlen(password);
	if (l >= ENCRYPTION_BLOCK_BYTES) {
		fprintf(stderr, "%s: Error- password length cannot exceed %d characters\n", __FUNCTION__, ENCRYPTION_BLOCK_BYTES);
		return(0);
	}
		
	// try password as subject pwd
	encrypted_segments = SUBJECT_VALIDATION_FIELD_LENGTH / ENCRYPTION_BLOCK_BYTES;
	hbp = header_block + SUBJECT_VALIDATION_FIELD_OFFSET;
	dhbp = decrypted_header + SUBJECT_VALIDATION_FIELD_OFFSET;
	for (i = encrypted_segments; i--;) {
		AES_decrypt(hbp, dhbp, password);
		hbp += ENCRYPTION_BLOCK_BYTES;
		dhbp += ENCRYPTION_BLOCK_BYTES;
	}
	
	// convert from pascal string
	dhbp = decrypted_header + SUBJECT_VALIDATION_FIELD_OFFSET;
	l = (si4) dhbp[0];
	if (l < ENCRYPTION_BLOCK_BYTES) {
		strncpy(temp_str, (const char *)(dhbp + 1), l);
		temp_str[l] = 0;
		// compare subject passwords
		if (strcmp(temp_str, password) == 0)
			return(1);
	}
	

	// try using passed password to decrypt session encrypted key
	encrypted_segments = SESSION_VALIDATION_FIELD_LENGTH / ENCRYPTION_BLOCK_BYTES;
	hbp = header_block + SESSION_VALIDATION_FIELD_OFFSET;
	dhbp = decrypted_header + SESSION_VALIDATION_FIELD_OFFSET;
	for (i = encrypted_segments; i--;) {
		AES_decrypt(hbp, dhbp, password);
		hbp += ENCRYPTION_BLOCK_BYTES;
		dhbp += ENCRYPTION_BLOCK_BYTES;
	}
	
	// convert from pascal string
	dhbp = decrypted_header + SESSION_VALIDATION_FIELD_OFFSET;
	l = (si4) dhbp[0];
	if (l < ENCRYPTION_BLOCK_BYTES) {
		strncpy(temp_str, (const char *)(dhbp + 1), l);
		temp_str[l] = 0;
		// compare session passwords
		if (strcmp(temp_str, password) == 0)
			return(2);
	}
	
	return(0);
}


//==============================================================================================
//
//	void showHeader(MEF_HEADER_INFO *headerStruct)
//
//	inputs: 
//		header structure
//
//	this routine prints values from the header structure to standard output
//
//	
//
EXPORT
void showHeader(MEF_HEADER_INFO *headerStruct)
{
	si8	long_file_time;
//	si4 file_time;
	si1	*time_str, temp_str[25];
	int i;
	
	//check input
	if (headerStruct == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL structure pointer passed\n", __FUNCTION__);
		return;
	}
	
	
	sprintf(temp_str, "not entered");
	if (headerStruct->institution[0]) (void) fprintf(stdout, "institution = %s\n", headerStruct->institution);
	else (void) fprintf(stdout, "institution = %s\n", temp_str);
	
	if (headerStruct->unencrypted_text_field[0]) (void) fprintf(stdout, "unencrypted_text_field = %s\n", headerStruct->unencrypted_text_field);
	else (void) fprintf(stdout, "unencrypted_text_field = %s\n", temp_str);
	
	(void) fprintf(stdout, "encryption_algorithm = %s\n", headerStruct->encryption_algorithm);
	
	if (headerStruct->byte_order_code) sprintf(temp_str, "little"); else sprintf(temp_str, "big");
	(void) fprintf(stdout, "byte_order_code = %s endian\n", temp_str);
	
	if (headerStruct->subject_encryption_used) sprintf(temp_str, "yes"); else sprintf(temp_str, "no");
	(void) fprintf(stdout, "subject_encryption_used = %s\n", temp_str);
	
	if (headerStruct->session_encryption_used) sprintf(temp_str, "yes"); else sprintf(temp_str, "no");
	(void) fprintf(stdout, "session_encryption_used = %s\n", temp_str);
	
	if (headerStruct->data_encryption_used) sprintf(temp_str, "yes"); else sprintf(temp_str, "no");
	(void) fprintf(stdout, "data_encryption_used = %s\n", temp_str);
	
	//	(void) fprintf(stdout, "file_type = %s\n", headerStruct->file_type);
	(void) fprintf(stdout, "header_version_major = %u\n", headerStruct->header_version_major);
	(void) fprintf(stdout, "header_version_minor = %u\n", headerStruct->header_version_minor);
	
	(void) fprintf(stdout, "file UID = ");
	for(i=0; i<SESSION_UNIQUE_ID_LENGTH; i++)
		(void) fprintf(stdout, "%u ", headerStruct->session_unique_ID[i]);
	(void) fprintf(stdout, "\n");
	
	(void) fprintf(stdout, "header_length = %hu\n", headerStruct->header_length);
	
	sprintf(temp_str, "not entered");
	if (headerStruct->subject_first_name[0]) (void) fprintf(stdout, "subject_first_name = %s\n", headerStruct->subject_first_name);
	else (void) fprintf(stdout, "subject_first_name = %s\n", temp_str);	
	
	if (headerStruct->subject_second_name[0]) (void) fprintf(stdout, "subject_second_name = %s\n", headerStruct->subject_second_name);
	else (void) fprintf(stdout, "subject_second_name = %s\n", temp_str);
	
	if (headerStruct->subject_third_name[0]) (void) fprintf(stdout, "subject_third_name = %s\n", headerStruct->subject_third_name);
	else (void) fprintf(stdout, "subject_third_name = %s\n", temp_str);
	
	if (headerStruct->subject_id[0]) (void) fprintf(stdout, "subject_id = %s\n", headerStruct->subject_id);
	else (void) fprintf(stdout, "subject_id = %s\n", temp_str);
	
	if (headerStruct->session_password[0]) (void) fprintf(stdout, "session_password = %s\n", headerStruct->session_password);
	else (void) fprintf(stdout, "session_password = %s\n", temp_str);
	
	if (headerStruct->number_of_samples) (void) fprintf(stdout, "number_of_samples = %lu\n", headerStruct->number_of_samples);
	else (void) fprintf(stdout, "number_of_samples = %s\n", temp_str);
	
	if (headerStruct->channel_name[0]) (void) fprintf(stdout, "channel_name = %s\n", headerStruct->channel_name);
	else (void) fprintf(stdout, "channel_name = %s\n", temp_str);
	
	long_file_time = (si8) (headerStruct->recording_start_time + 500000) / 1000000;
	time_str = ctime((time_t *) &long_file_time); time_str[24] = 0;
	if (headerStruct->recording_start_time) {
		(void) fprintf(stdout, "recording_start_time = %lu\t(%s)\n", headerStruct->recording_start_time, time_str);
	} else
		(void) fprintf(stdout, "recording_start_time = %s  (default value: %s)\n", temp_str, time_str);
	
	long_file_time = (si8) (headerStruct->recording_end_time + 500000) / 1000000;
	time_str = ctime((time_t *) &long_file_time); time_str[24] = 0;
	if (headerStruct->recording_start_time && headerStruct->recording_end_time) {
		(void) fprintf(stdout, "recording_end_time = %lu\t(%s)\n", headerStruct->recording_end_time, time_str);
	} else
		(void) fprintf(stdout, "recording_end_time = %s  (default value: %s)\n", temp_str, time_str);
	
	if (FLOAT_EQUAL (headerStruct->sampling_frequency, -1.0)) fprintf(stdout, "sampling_frequency = %s\n", temp_str);
	else (void) fprintf(stdout, "sampling_frequency = %lf\n", headerStruct->sampling_frequency);
	
	if (FLOAT_EQUAL (headerStruct->low_frequency_filter_setting, -1.0))  sprintf(temp_str, "not entered");
	else if (headerStruct->low_frequency_filter_setting < EPSILON) sprintf(temp_str, "no low frequency filter");
	else sprintf(temp_str, "%lf", headerStruct->low_frequency_filter_setting);
	(void) fprintf(stdout, "low_frequency_filter_setting = %s\n", temp_str);
	
	if (FLOAT_EQUAL (headerStruct->high_frequency_filter_setting, -1.0)) sprintf(temp_str, "not entered");
	else if (headerStruct->high_frequency_filter_setting < EPSILON) sprintf(temp_str, "no high frequency filter");
	else sprintf(temp_str, "%lf", headerStruct->high_frequency_filter_setting);
	(void) fprintf(stdout, "high_frequency_filter_setting = %s\n", temp_str);
	
	if (FLOAT_EQUAL (headerStruct->notch_filter_frequency, -1.0)) sprintf(temp_str, "not entered");
	else if (headerStruct->notch_filter_frequency < EPSILON) sprintf(temp_str, "no notch filter");
	else sprintf(temp_str, "%lf", headerStruct->notch_filter_frequency);
	(void) fprintf(stdout, "notch_filter_frequency = %s\n", temp_str);
	
	if (FLOAT_EQUAL(headerStruct->voltage_conversion_factor, 0.0)) sprintf(temp_str, "not entered");
	else sprintf(temp_str, "%lf", headerStruct->voltage_conversion_factor);
	(void) fprintf(stdout, "voltage_conversion_factor = %s (microvolts per A/D unit)", temp_str);
	if (headerStruct->voltage_conversion_factor < 0.0)
		(void) fprintf(stdout, " (negative indicates voltages are inverted)\n");
	else
		(void) fprintf(stdout, "\n");
	if( headerStruct->block_interval) (void) fprintf(stdout, "block_interval = %lu (microseconds)\n", headerStruct->block_interval);
	else (void) fprintf(stdout, "block_interval = %s\n", temp_str);
	
	(void) fprintf(stdout, "acquisition_system = %s\n", headerStruct->acquisition_system);
	
	if(headerStruct->physical_channel_number == -1)  (void) fprintf(stdout, "physical_channel_number = %s\n", temp_str);
	else (void) fprintf(stdout, "physical_channel_number = %d\n", headerStruct->physical_channel_number);
	
	sprintf(temp_str, "not entered");
	if (headerStruct->channel_comments[0]) (void) fprintf(stdout, "channel_comments = %s\n", headerStruct->channel_comments);
	else (void) fprintf(stdout, "channel_comments = %s\n", temp_str);
	
	if (headerStruct->study_comments[0]) (void) fprintf(stdout, "study_comments = %s\n", headerStruct->study_comments);
	else (void) fprintf(stdout, "study_comments = %s\n", temp_str);
	
	(void) fprintf(stdout, "compression_algorithm = %s\n", headerStruct->compression_algorithm);
	
	if(headerStruct->maximum_compressed_block_size) (void) fprintf(stdout, "maximum_compressed_block_size = %d\n", headerStruct->maximum_compressed_block_size);
	else fprintf(stdout, "maximum_compressed_block_size = %s\n", temp_str);
	
	if(headerStruct->maximum_block_length) (void) fprintf(stdout, "maximum_block_length = %lu\n", headerStruct->maximum_block_length);	
	else (void) fprintf(stdout, "maximum_block_length = %s\n", temp_str);
	
	if(headerStruct->maximum_data_value != headerStruct->minimum_data_value) {
		(void) fprintf(stdout, "maximum_data_value = %d\n", headerStruct->maximum_data_value);
		(void) fprintf(stdout, "minimum_data_value = %d\n", headerStruct->minimum_data_value);	
	}
	else {
		(void) fprintf(stdout, "maximum_data_value = %s\n", temp_str);
		(void) fprintf(stdout, "minimum_data_value = %s\n", temp_str);
	}
		
	if(headerStruct->index_data_offset) (void) fprintf(stdout, "index_data_offset = %lu\n", headerStruct->index_data_offset);
	else (void) fprintf(stdout, "index_data_offset = %s\n", temp_str);
	
	if(headerStruct->number_of_index_entries) (void) fprintf(stdout, "number_of_index_entries = %lu\n", headerStruct->number_of_index_entries);
	else (void) fprintf(stdout, "number_of_index_entries = %s\n", temp_str);

	if(headerStruct->block_header_length) (void) fprintf(stdout, "block_header_length = %d\n", headerStruct->block_header_length);
	else (void) fprintf(stdout, "block_header_length = %s\n", temp_str);

	return;
}


EXPORT
ui8 generate_unique_ID(ui1 *array)
{
	ui8 long_output = 0;
	si4 i;
	
	if (array == NULL) 
	{
		array = calloc(SESSION_UNIQUE_ID_LENGTH, sizeof(ui1));
	}
			
	srandomdev();
	for (i=0; i<SESSION_UNIQUE_ID_LENGTH; i++) 
	{
		array[i] = (ui1)(random() % 255);
		long_output += array[i] >> i; 
	}
	
	return (long_output);
}


EXPORT
void set_hdr_unique_ID(MEF_HEADER_INFO *header, ui1 *array)
{
	//check input
	if (header == NULL)
	{
		fprintf(stderr, "[%s] Error: NULL structure pointer passed\n", __FUNCTION__);
		return;
	}
	
	if (array == NULL) //generate new uid
	{
		array = calloc(SESSION_UNIQUE_ID_LENGTH, sizeof(ui1));
		(void)generate_unique_ID(array);
	}
	
	memcpy(header->session_unique_ID, array, SESSION_UNIQUE_ID_LENGTH);
	return;
}


EXPORT
void set_block_hdr_unique_ID(ui1 *block_header, ui1 *array)
{
	
	if (array == NULL) //generate new uid
	{
		array = calloc(SESSION_UNIQUE_ID_LENGTH, sizeof(ui1));
		(void)generate_unique_ID(array);
	}
	
	memcpy((block_header + SESSION_UNIQUE_ID_OFFSET), array, SESSION_UNIQUE_ID_LENGTH);
	return;
}


EXPORT
ui8 set_session_unique_ID(char *file_name, ui1 *array)
{
	FILE *mef_fp;
	si4 read_mef_header_block(), validate_password();
	
	
	//Open file
	mef_fp = fopen(file_name, "r+");
	if (mef_fp == NULL) {
		fprintf(stderr, "%s: Could not open file %s\n", __FUNCTION__, file_name);
		return(1);
	}
	

	if (array == NULL) {	
		array = calloc(SESSION_UNIQUE_ID_LENGTH, sizeof(ui1));
		(void)generate_unique_ID(array);
	}
	
	//write file unique ID to header
	fseek(mef_fp, SESSION_UNIQUE_ID_OFFSET, SEEK_SET);
	fwrite(array, sizeof(ui1), SESSION_UNIQUE_ID_LENGTH, mef_fp);
	
	fseek(mef_fp, 0, SEEK_END);
		
	fclose(mef_fp);
	
	return(0);
}


EXPORT
void check_header_block_alignment(ui1 *header_block)
{
	if ((ui8) header_block % 8) {
		(void) fprintf(stderr, "Header block is not 8 byte boundary aligned [use malloc() rather than heap declaration] ==> exiting\n");
		exit(1);
	}
	
	return;
}


EXPORT
void strncpy2(si1 *s1, si1 *s2, si4 n)
{
	si4      len;

	for (len = 1; len < n; ++len) {
		if (*s1++ = *s2++)
			continue;
		return;
	}
	s1[n-1] = 0;

	return;
}


void init_hdr_struct(MEF_HEADER_INFO *header)
{
	ui1 cpu_endianness();
	
	
	memset(header, 0, sizeof(MEF_HEADER_INFO));
	
	header->header_version_major=HEADER_MAJOR_VERSION;
	header->header_version_minor=HEADER_MINOR_VERSION;
	header->header_length=MEF_HEADER_LENGTH;
	header->block_header_length=BLOCK_HEADER_BYTES;
	
	sprintf(header->compression_algorithm, "Range Encoded Differences (RED)");
	sprintf(header->encryption_algorithm,  "AES %d-bit", ENCRYPTION_BLOCK_BITS);
	
	if (cpu_endianness())
		header->byte_order_code = 1;
	else
		header->byte_order_code = 0;
	
	return; 
}

EXPORT
si4	write_mef(si4 *samps, MEF_HEADER_INFO *mef_header, ui8 len, si1 *out_file, si1 *subject_password)
{
	ui1 *header, encryption_key[240], byte_padding[8], discontinuity_flag;
	si1	*compressed_buffer, *cbp;
	si4	sl, max_value, min_value, byte_offset, *sp;
	ui4 samps_per_block, max_block_size;
	si8	i;
	ui8 curr_time, nr, samps_left, index_data_offset, RED_block_size, dataCounter;
	ui8 entryCounter, num_blocks;
	FILE	*fp;
	RED_BLOCK_HDR_INFO RED_bk_hdr;
	INDEX_DATA *index_block, *ip;
	void	AES_KeyExpansion();
	ui8	RED_compress_block();
	si4	build_mef_header_block();
	
	if ( mef_header==NULL ) {
		fprintf(stderr, "[%s] NULL header passed in\n", __FUNCTION__);
		return(1);
	}
	
	curr_time = mef_header->recording_start_time;
	
	//Check input header values for validity
	if ( mef_header->sampling_frequency < 0.001) {
		fprintf(stderr, "[%s] Improper sampling frequency (%lf Hz) in header %s\n", __FUNCTION__,  mef_header->sampling_frequency, 
				mef_header->channel_name);
		return(1);
	}
	
	if ( mef_header->block_interval < 0.001) {
		fprintf(stderr, "[%s] Improper block interval (%lu microseconds) in header %s\n", __FUNCTION__,  mef_header->block_interval, 
				mef_header->channel_name);
		return(1);
	}	
	samps_per_block = (ui4)((sf8)mef_header->block_interval * mef_header->sampling_frequency/ 1000000.0); 
	
	if (samps_per_block < 1) {
		fprintf(stderr, "[%s] Improper header info- must encode 1 or more samples in each block\n", __FUNCTION__);
		return(1);
	}
	if (samps_per_block > mef_header->number_of_samples) {
		fprintf(stderr, "[%s] Improper header info- samples per block %u greater than total entries %lu for %s\n", __FUNCTION__, samps_per_block,
				mef_header->number_of_samples, mef_header->channel_name);
		return(1);
	}
	num_blocks = ceil( (sf8)len / (sf8)samps_per_block  );
	
	if (num_blocks < 1) {
		fprintf(stderr, "[%s] Improper header info- must encode 1 or more blocks\n", __FUNCTION__);
		return(1);
	}
	
	mef_header->number_of_samples = (ui8) len;  //number of samples may be different from original file
	mef_header->maximum_block_length = samps_per_block;
		

	encryption_key[0] = 0;
	if (mef_header->data_encryption_used)
		AES_KeyExpansion(4, 10, encryption_key, mef_header->session_password); 
	
	
	index_block = (INDEX_DATA *)calloc(num_blocks, sizeof(INDEX_DATA));
	compressed_buffer = calloc(num_blocks*samps_per_block/2, sizeof(si4)); //we'll assume at least 50% compression
	
	if (index_block == NULL || compressed_buffer == NULL) {
		fprintf(stderr, "[%s] malloc error\n", __FUNCTION__);
		return(1);
	}
	
	sl = (si4)strlen(out_file);
	if ((strcmp((out_file + sl - 4), ".mef"))) {
		fprintf(stderr, "no \".mef\" on input name => exiting\n");
		return(1);
	}
	fp = fopen(out_file, "w");
	
	header = malloc(MEF_HEADER_LENGTH);
	memset(header, 0, MEF_HEADER_LENGTH); //fill mef header space with zeros - will write real info after writing blocks and indices
	fwrite(header, 1, MEF_HEADER_LENGTH, fp);
	
	sp = samps;	
	cbp = compressed_buffer; 
	ip = index_block;
	dataCounter = MEF_HEADER_LENGTH; 
	entryCounter=0; 
	discontinuity_flag = 1;
	max_value = 1<<31; min_value = max_value-1; 
	max_block_size = 0;
	
	
	samps_left = len;
	for (i=0; i<num_blocks; i++) {
		ip->time = mef_header->recording_start_time + i * mef_header->block_interval*1000000;
		ip->file_offset = dataCounter; 
		ip->sample_number = i * samps_per_block;
		
		//printf("%ld ip %lu\t %lu\t %lu\t \n", i, ip->time, ip->file_offset, ip->sample_number );
		
		if (samps_left < samps_per_block) samps_per_block = (ui4)samps_left;		
		
		RED_block_size = RED_compress_block(sp, cbp, samps_per_block, ip->time, (ui1)discontinuity_flag, encryption_key, &RED_bk_hdr);
		
		dataCounter += RED_block_size;
		cbp += RED_block_size;
		entryCounter += RED_bk_hdr.sample_count;
		samps_left -= RED_bk_hdr.sample_count;
		sp += RED_bk_hdr.sample_count;
		ip++;
		
		if (RED_bk_hdr.max_value > max_value) max_value = RED_bk_hdr.max_value;
		if (RED_bk_hdr.min_value < min_value) min_value = RED_bk_hdr.min_value;
		if (RED_block_size > max_block_size) max_block_size = (ui4)RED_block_size;
		
		discontinuity_flag = 0; //only the first block has a discontinuity		
	}
	
	//update mef header with new values
	mef_header->maximum_data_value = max_value;
	mef_header->minimum_data_value = min_value;
	mef_header->maximum_compressed_block_size = max_block_size;
	mef_header->number_of_index_entries = num_blocks;
	
	// write mef entries
	nr = fwrite(compressed_buffer, sizeof(si1), (size_t) dataCounter, fp); 
	if (nr != dataCounter) { fprintf(stderr, "Error writing file\n"); fclose(fp); return(1); }
	
	//byte align index data if needed
	index_data_offset = ftell(fp);
	byte_offset = (si4)index_data_offset % 8;
	if (byte_offset) {
		memset(byte_padding, 0, 8);
		fwrite(byte_padding, sizeof(ui1), 8 - byte_offset, fp);
		index_data_offset += 8 - byte_offset;
	}
	mef_header->index_data_offset = index_data_offset;
	
	//write index offset block to end of file
	nr = fwrite(index_block, sizeof(INDEX_DATA), (size_t) num_blocks, fp); 
	
	//build mef header from structure
	nr = build_mef_header_block(header, mef_header, subject_password); //recycle nr
	if (nr) { fprintf(stderr, "Error building mef header\n"); return(1); }
	
	fseek(fp, 0, SEEK_SET); //reset fp to beginning of file to write mef header
	nr = fwrite(header, sizeof(ui1), (size_t) MEF_HEADER_LENGTH, fp);
	if (nr != MEF_HEADER_LENGTH) { fprintf(stderr, "Error writing mef header\n"); return(1); }
	
	fclose(fp);
	
	free(compressed_buffer);
	free(index_block);
	
	return(0);
}

