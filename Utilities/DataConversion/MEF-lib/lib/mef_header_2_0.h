/*									mef_header_2_0.h
*
* Specification for Mayo EEG Format (MEF) version 2.0, 
* copyright 2008, Mayo Foundation, Rochester MN

 This file specifies the offsets to and sizes of (in bytes) all header values needed for generation of .mef files, as
 well as a structure for the header. Data types are specified in comments where applicable, shorthand notation as follows 
 (see size_types.h):
  signed char		si1
  unsigned char		ui1
  signed short		si2
  unsigned short	ui2
  signed int		si4
  unsigned int		ui4
  float			sf4
  long signedint	si8
  long unsigned int	ui8
  double		sf8
  n-char string		$(n)  -allow 1 space for termination character

 Header Encryption:
 The header begins with 176 unencrypted bytes, including two text fields and a series of numeric values defining the file’s 
 format and characteristics. The remainder of the header is encrypted with either a “subject” or “file” password. The passwords 
 are zero-terminated strings with a 15 character limit at this time. The subject password is used to access the file password 
 for decryption. The file password decrypts all but subject identifying header fields. The encryption / decryption algorithm 
 is the 128-bit AES standard (http://www.csrc.nist.gov/publications/fips/fips197/fips-197.pdf).

 Header Alignment:
 Fields in the header have required byte alignments relative to its start. 16-byte alignment facilitates encryption/decryption 
 beginning at that offset. Other alignment requirements are determined by the data-types: e.g. 8-byte alignment facilitates 
 reading si8, ui8, and sf8 data types
 
 Time Data:
 Each mef file ends in a block of recording time data. The offset to this data and the number of data entries are given in the file header. 
 This block contains triplets of times, file offsets, and sample indices of EEG data. Triplets are ui8 values containing the elapsed microseconds 
 since January 1, 1970 at 00:00:00 in the GMT (Greenwich, England) time zone. These values are easily converted to UTC time format (seconds since 
 1/1/1970 at 00:00:00 GMT), referred to hereafter as uUTC for "micro-UTC"
 
*/

#ifndef MEF_HEADER_IN
#define MEF_HEADER_IN

#include "size_types.h"


/************* header version & constants *******************/

#define HEADER_MAJOR_VERSION				2
#define HEADER_MINOR_VERSION				0
#define MEF_HEADER_LENGTH					1024
#define DATA_START_OFFSET					MEF_HEADER_LENGTH
#define UNENCRYPTED_REGION_OFFSET			0
#define UNENCRYPTED_REGION_LENGTH			176
#define SUBJECT_ENCRYPTION_OFFSET			176
#define SUBJECT_ENCRYPTION_LENGTH			160
#define SESSION_ENCRYPTION_OFFSET			352
#define SESSION_ENCRYPTION_LENGTH			496 /*maintain multiple of 16*/
#define ENCRYPTION_BLOCK_BITS				128
#define ENCRYPTION_BLOCK_BYTES				(ENCRYPTION_BLOCK_BITS / 8)


/******************** header fields *************************/

/* Begin Unencrypted Block*/
#define INSTITUTION_OFFSET					0
#define INSTITUTION_LENGTH					64		/* $(63)*/
#define UNENCRYPTED_TEXT_FIELD_OFFSET		64
#define UNENCRYPTED_TEXT_FIELD_LENGTH		64		/* $(63)*/
#define ENCRYPTION_ALGORITHM_OFFSET			128
#define ENCRYPTION_ALGORITHM_LENGTH			32		/* $(29)*/
#define SUBJECT_ENCRYPTION_USED_OFFSET		160
#define SUBJECT_ENCRYPTION_USED_LENGTH		1		/* ui1*/
#define SESSION_ENCRYPTION_USED_OFFSET		161
#define SESSION_ENCRYPTION_USED_LENGTH		1		/* ui1 */
#define DATA_ENCRYPTION_USED_OFFSET			162
#define DATA_ENCRYPTION_USED_LENGTH			1		/* ui1*/
#define BYTE_ORDER_CODE_OFFSET				163
#define BYTE_ORDER_CODE_LENGTH				1		/* ui1*/
#define HEADER_MAJOR_VERSION_OFFSET			164
#define HEADER_MAJOR_VERSION_LENGTH			1		/*ui1*/
#define HEADER_MINOR_VERSION_OFFSET			165
#define HEADER_MINOR_VERSION_LENGTH			1		/* ui1*/
#define HEADER_LENGTH_OFFSET				166
#define HEADER_LENGTH_LENGTH				2		/* ui2*/
#define SESSION_UNIQUE_ID_OFFSET			168
#define SESSION_UNIQUE_ID_LENGTH			8		/* ui1*/
/*End Unencrypted Block*/

/* Begin Subject Encrypted Block*/
#define SUBJECT_FIRST_NAME_OFFSET			176
#define SUBJECT_FIRST_NAME_LENGTH			32		/* $(31)*/
#define SUBJECT_SECOND_NAME_OFFSET			208
#define SUBJECT_SECOND_NAME_LENGTH			32		/* $(31)*/
#define SUBJECT_THIRD_NAME_OFFSET			240
#define SUBJECT_THIRD_NAME_LENGTH			32		/* $(31) */
#define SUBJECT_ID_OFFSET					272
#define SUBJECT_ID_LENGTH					32		/* $(31) */
#define SESSION_PASSWORD_OFFSET				304
#define SESSION_PASSWORD_LENGTH				ENCRYPTION_BLOCK_BYTES		/* $(15)*/
#define SUBJECT_VALIDATION_FIELD_OFFSET		320
#define SUBJECT_VALIDATION_FIELD_LENGTH		16
/* End Subject Encrypted Block*/

/* Begin Protected Block*/
#define PROTECTED_REGION_OFFSET				336
#define PROTECTED_REGION_LENGTH				16
/* End Protected Block*/

/*/ Begin Session Encrypted Block*/
#define SESSION_VALIDATION_FIELD_OFFSET		352
#define SESSION_VALIDATION_FIELD_LENGTH		16		/* ui1*/
#define NUMBER_OF_SAMPLES_OFFSET			368
#define NUMBER_OF_SAMPLES_LENGTH			8	/* ui8*/
#define CHANNEL_NAME_OFFSET					376
#define CHANNEL_NAME_LENGTH					32		/* $(31)	*/
#define RECORDING_START_TIME_OFFSET			408
#define RECORDING_START_TIME_LENGTH			8		/* ui8*/
#define RECORDING_END_TIME_OFFSET			416
#define RECORDING_END_TIME_LENGTH			8		/* ui8*/
#define SAMPLING_FREQUENCY_OFFSET			424
#define SAMPLING_FREQUENCY_LENGTH			8		/* sf8*/
#define LOW_FREQUENCY_FILTER_SETTING_OFFSET		432
#define LOW_FREQUENCY_FILTER_SETTING_LENGTH		8		/*sf8*/
#define HIGH_FREQUENCY_FILTER_SETTING_OFFSET	440
#define HIGH_FREQUENCY_FILTER_SETTING_LENGTH	8		/* sf8*/
#define NOTCH_FILTER_FREQUENCY_OFFSET		448
#define NOTCH_FILTER_FREQUENCY_LENGTH		8		/* sf8*/
#define VOLTAGE_CONVERSION_FACTOR_OFFSET	456
#define VOLTAGE_CONVERSION_FACTOR_LENGTH	8		/* sf8*/
#define ACQUISITION_SYSTEM_OFFSET			464
#define ACQUISITION_SYSTEM_LENGTH			32		/* $(31)*/
#define CHANNEL_COMMENTS_OFFSET				496
#define CHANNEL_COMMENTS_LENGTH				128		/* $(127)*/
#define STUDY_COMMENTS_OFFSET				624
#define STUDY_COMMENTS_LENGTH				128		/* $(127)*/
#define PHYSICAL_CHANNEL_NUMBER_OFFSET		752
#define PHYSICAL_CHANNEL_NUMBER_LENGTH		4		/* si4*/
#define COMPRESSION_ALGORITHM_OFFSET		756
#define COMPRESSION_ALGORITHM_LENGTH		32		/* $(31)*/
#define MAXIMUM_COMPRESSED_BLOCK_SIZE_OFFSET	788
#define MAXIMUM_COMPRESSED_BLOCK_SIZE_LENGTH	4		/* ui4*/
#define MAXIMUM_BLOCK_LENGTH_OFFSET			792
#define MAXIMUM_BLOCK_LENGTH_LENGTH			8		/* ui8*/
#define BLOCK_INTERVAL_OFFSET				800
#define BLOCK_INTERVAL_LENGTH				8		/* sf8*/
#define MAXIMUM_DATA_VALUE_OFFSET			808
#define MAXIMUM_DATA_VALUE_LENGTH			4		/* si4*/
#define MINIMUM_DATA_VALUE_OFFSET			812
#define MINIMUM_DATA_VALUE_LENGTH			4		/* si4*/
#define INDEX_DATA_OFFSET_OFFSET			816
#define	INDEX_DATA_OFFSET_LENGTH			8		/* ui8*/
#define NUMBER_OF_INDEX_ENTRIES_OFFSET		824
#define NUMBER_OF_INDEX_ENTRIES_LENGTH		8		/* ui8*/
#define BLOCK_HEADER_LENGTH_OFFSET			832
#define BLOCK_HEADER_LENGTH_LENGTH			2		/* ui2*/
#define UNUSED_HEADER_SPACE_OFFSET			834
#define UNUSED_HEADER_SPACE_LENGTH			190
/* End Session Encrypted Block*/


/******************** structure & type definitions *****************/

typedef struct {
	si1	institution[INSTITUTION_LENGTH];
	si1	unencrypted_text_field[UNENCRYPTED_TEXT_FIELD_LENGTH];
	si1	encryption_algorithm[ENCRYPTION_ALGORITHM_LENGTH];
	ui1	subject_encryption_used;
	ui1	session_encryption_used;
	ui1	data_encryption_used;
	ui1	byte_order_code;
	ui1	header_version_major;
	ui1	header_version_minor;
	ui1	session_unique_ID[SESSION_UNIQUE_ID_LENGTH];
	ui2	header_length;
	si1	subject_first_name[SUBJECT_FIRST_NAME_LENGTH];
	si1	subject_second_name[SUBJECT_SECOND_NAME_LENGTH];
	si1	subject_third_name[SUBJECT_THIRD_NAME_LENGTH];
	si1	subject_id[SUBJECT_ID_LENGTH];
	si1	session_password[SESSION_PASSWORD_LENGTH];
	si1	subject_validation_field[SUBJECT_VALIDATION_FIELD_LENGTH];
	si1	session_validation_field[SESSION_VALIDATION_FIELD_LENGTH];
	si1	protected_region[PROTECTED_REGION_LENGTH];
	ui8	number_of_samples;
	si1	channel_name[CHANNEL_NAME_LENGTH];
	ui8	recording_start_time;
	ui8	recording_end_time;
	sf8	sampling_frequency;
	sf8	low_frequency_filter_setting;
	sf8	high_frequency_filter_setting;
	sf8	notch_filter_frequency;
	sf8	voltage_conversion_factor;
	si1	acquisition_system[ACQUISITION_SYSTEM_LENGTH];
	si1	channel_comments[CHANNEL_COMMENTS_LENGTH];
	si1	study_comments[STUDY_COMMENTS_LENGTH];
	si4	physical_channel_number;
	si1	compression_algorithm[COMPRESSION_ALGORITHM_LENGTH];
	ui4	maximum_compressed_block_size;
	ui8 maximum_block_length; 
	ui8	block_interval;
	si4 maximum_data_value;
	si4 minimum_data_value;
	ui8	index_data_offset;
	ui8	number_of_index_entries;
	ui2 block_header_length;
} MEF_HEADER_INFO;

typedef struct {
	ui8	time;
	ui8	file_offset;
	ui8	sample_number;
} INDEX_DATA;


#endif



