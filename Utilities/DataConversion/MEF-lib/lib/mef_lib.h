
/* mef_lib.h

	Public interface to MEF library




	si4	build_mef_header_block(ui1 *encrypted_hdr_block, MEF_HEADER_INFO *hdr_struct, si1 *subject_password)

inputs: 
		unsigned char pointer to writable block header space
		pointer to mef header structure containing hdr information
		subject password 

	return values:		0 for success, 1 for failure

	this routine fills in block with values from the hdr structure, then encrypts the block header 
	using 128 bit AES decryption using file and master passwords as the encryption keys. File password is read
	from the header structure*/

si4	build_mef_header_block(ui1 *encrypted_hdr_block, MEF_HEADER_INFO *hdr_struct, si1 *master_password);

/*
	si4	read_mef_header_block(ui1 *header_block, MEF_HEADER_INFO *header_struct, si1 *password)

	inputs: 
		unsigned char pointer to encrypted block header
		pointer to mef header structure
		password 

	return values:
		0 for success, 1 for failure

	this routine decrypts the block header using 128 bit AES decryption using password as the decryption key
	(checking to see if it's master or file pwd), then fills in hdr structure with decrypted values
*/
si4	read_mef_header_block(ui1 *header_block, MEF_HEADER_INFO *header_struct, si1 *password);

/*
	si4	validate_password(ui1 *header_block, si1 *password);

	inputs: 
		unsigned char pointer to encrypted block header
		password 
	return values:
		0 password does not match
		1 for master password
		2 for file password

	this routine decrypts the block header using 128 bit AES decryption using password as the decryption key
	(checking to see if it's master or file pwd), then fills in hdr structure with decrypted values
*/
si4	validate_password(ui1 *header_block, si1 *password);

/*
	void showHeader(MEF_HEADER_INFO *headerStruct);

	inputs: 
		pointer to mef header structure

	this routine prints values from the header structure to standard output
*/
void showHeader(MEF_HEADER_INFO *headerStruct);

/*
	ui8 generate_unique_ID(ui1 *array)

	inputs: 
		pointer to blank char array (7 fields)

	this routine fills the blank array with 7 random unsigned char values. This array is to be shared between 
	all .mvf event files and .mef eeg files acquired in a particular recording session/time frame
*/
ui8 generate_unique_ID(ui1 *array);

/*
  void set_hdr_unique_ID(MEF_HEADER_INFO *header, ui1 *array)

	inputs: 
		pointer to mef header structure
		pointer to unsigned char array (7 fields)

	this routine copies the 7 unsigned char unique ID to the header structure. If array is NULL, 
	a new UID is generated.
*/
void set_hdr_unique_ID(MEF_HEADER_INFO *header, ui1 *array);

/*
//	void set_block_hdr_unique_ID(ui1 *block_header, ui1 *array)
//
//	inputs: 
//		unsigned char pointer to encrypted block header
//		pointer to unsigned char array (7 fields)
//
//	this routine copies the 7 unsigned char unique ID to the block header. If array is NULL, 
//	a new UID is generated. No password is required because the UID is stored in an unencrypted field.
*/
void set_block_hdr_unique_ID(ui1 *block_header, ui1 *array);

/*
//	ui8 set_session_unique_ID(char *file_name, ui1 *array)
//
//	inputs: 
//		char pointer to file name string
//		pointer to unsigned char array
//
//	return values:
//		0 for success, 1 for failure
//
//	this routine copies the 7 unsigned char unique ID to the file's header. If array is NULL, 
//	a new UID is generated. No password is required because the UID is stored in an unencrypted field.
*/
ui8 set_session_unique_ID(char *file_name, ui1 *array);

/*
//	void check_header_block_alignment(ui1 *header_block)
//	input: header block address
//
//	return values: none
//
//	This routine exits if the header block is not 8-byte boundary aligned which can happen if the
//	memory was allocated on the heap, rather than dynamically allocated.
*/
void check_header_block_alignment(ui1 *header_block);

/*
//	void strncpy2(si1 *s1, si1 *s2, si4 n)
//
//	inputs:
//		s1 (destination string), s2 (source string), n (maximum length of string including terminal 0)
//
//	return values: none
//
//	strncpy but does not zero out remaining bytes and always zeros terminates
//	maximum characters is n-1
*/
void strncpy2(si1 *s1, si1 *s2, si4 n);

/*
//	void init_hdr_struct(MEF_HEADER_INFO *header);
//
//	inputs:
//		header (pointer to mef header structure)
//
//	return values: none
//
//	initializes known/constant fields in the header structure, sets everything else to zero
//	Fields initialized with values: header_version_major, header_version_minor, header_length,
//		byte_order_code, compression_algorithm, encryption_algorithm
*/
void init_hdr_struct(MEF_HEADER_INFO *header);

/*
// si4	write_mef2(si4 *samps, MEF_HEADER_INFO *mef_header, ui8 len, si1 *out_file, si1 *subject_password)
//
//	inputs: 
//		pointer to integer array of samples
//		pointer to mef header structure
//		length of sample array
//		string output file name
//		string subject password
//
//	return values:
//		0 for success, 1 for failure
//
//	This routine writes an array of values (si4) to a mef file. Critical parameters, including sampling
//		frequency, block interval, session password, byte order, encryption flags (subject, session, data)
//		subject identifying information, and recording times are read from header structure and used to 
//		build the file. The total number of samples is set by len, and the number of index entries, max and
//		min data values, and index offset are calculated by the routine. 
*/
si4	write_mef(si4 *samps, MEF_HEADER_INFO *mef_header, ui8 len, si1 *out_file, si1 *subject_password);

