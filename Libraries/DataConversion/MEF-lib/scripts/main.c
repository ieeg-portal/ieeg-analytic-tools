/*
 copyright 2012 Mayo Foundation 
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
//#include <CoreFoundation/CFByteOrder.h>

#include "mef.h"


int main (int argc, const char * argv[]) {
	int dataFailed = 0, path_len;
	int verbose, i, numFiles, uid, encryption_flag, anon_flag, bit_shift_flag, dst_flag;
	ui1	*uid_array;
	char subject_password[32], session_password[32];
	time_t start, end;
	sf8 sampling_frequency, secs_per_block;
	
	time(&start);
	

	if (argc < 1) 
	{
		(void) printf("USAGE: %s mef_file\n", argv[0]);
		return(1);
	}
	
	//defaults
	numFiles = argc - 1;
	verbose = 0; uid = 1;
	secs_per_block = 5.0;
    //sampling_frequency = 399.609756097560976;  // sampling freq of u01 (32768 / 82)
	sampling_frequency = 0.01665040650407; // sampling freq of roughly 1 sample per min (1/((24000*82)/32768))
	encryption_flag = 1;
	anon_flag = 0;
	bit_shift_flag = 1;
    dst_flag = 0;

	
	time(&start);
	
	uid_array = NULL;

    *subject_password = 0;
    *session_password = 0;
    
    dataFailed = write_u01_files(argv[1], NULL, sampling_frequency, uid_array, session_password, subject_password, secs_per_block, anon_flag);
    
    if (dataFailed)
        return 1;

	time(&end);
	fprintf(stdout, "\nProcessing completed in %2.0lf seconds.\n", difftime(end, start) );
	
	return 0;
}
