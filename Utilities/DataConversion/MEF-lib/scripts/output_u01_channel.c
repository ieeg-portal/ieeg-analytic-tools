#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <pthread.h>
#include <strings.h>
#include <math.h>
#include <time.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/resource.h>

#include "mef.h"

#define DBUG 1
#define MIN_BLOCK_SECS 5

si4	ctrl_c_hit;

si4 write_u01_files(si1 *inFileName, si1 *timestamp_file, sf8 sampling_frequency, si1 *uid, si1 *session_password, si1 *subject_password, sf8 secs_per_block, si4 anonymize_flag)
{
    ui8 nr, nw, flen, num_bytes_read, timestamp_basis;
    FILE *infile, *outfile;
    si4 fd;
    char header_string[1024];
    char outFileName[1024];
	sf4 feature_val, feature_invalidity;
    MEF_HEADER_INFO header_struct;
	ui1 header[MEF_HEADER_LENGTH];
    ui8 timestamp;
    ui8 sample_counter;
	sf4 zero_val;
	
	infile = fopen(inFileName, "r");
	if (infile == NULL) { fprintf(stderr, "Error reading mef file\n"); exit(1); }

	// read header block
	nr = (int)fread(header, sizeof(ui1), MEF_HEADER_LENGTH, infile);
	if (nr != MEF_HEADER_LENGTH)
	{
		fprintf(stderr, "%s: Error opening input file header\n", __FUNCTION__);
		return(1);
	}
	read_mef_header_block(header, &header_struct, subject_password);
	
	timestamp_basis = header_struct.recording_start_time;
	fprintf(stderr, "recording start time = %lu\n", timestamp_basis);
	fprintf(stderr, "recording end time = %lu\n", header_struct.recording_end_time);
	
	sprintf(outFileName, "u01outputfile.dat");
	outfile = fopen(outFileName, "w");
	if (outfile == NULL) { fprintf(stderr, "Error writing u01 output file\n"); exit(1); }
	
	sample_counter = 0;
	zero_val = 0.0;
	
	// TBD these presets can go away
	feature_val = 0;
	feature_invalidity = 0;
	
	while (1)
	{
		// calculate new timestamp.  Each 30750 seconds a new base timestamp is calucated.  This is
		// done to be as precise as possible.  Actual sampling rate = (1/((24000*82)/32768)), which is very close,
		// but not quite equal to 1 sample per minute (1/60 Hz).
		timestamp = timestamp_basis + (((double)sample_counter / sampling_frequency) * 1000000.0);
		sample_counter++;
		if (sample_counter == 512)
		{
			sample_counter = 0;
			timestamp_basis += 30750000000;  // add about 8.5 hours
		}
		
		// if we're at the end of the recording, we are done
		if (timestamp >= header_struct.recording_end_time)
			break;
		
		fprintf(stderr, "considering timestamp: %lu\n", timestamp);
		
		// using this timestamp, query database and gather statistics.  Write two values:
		// 1) float32 feature or classifer value
		// 2) float32 data invalidity bit
		
		// **************************
		// TBD make this do something
		// **************************
		
/*		// dummy test code
		// for now let's test by making it do something dumb
		// make feature_val slowly go up then back down to zero
		feature_val = feature_val += .01;
		if (feature_val >= 1.0)
			feature_val = 0;
		// make feature_invalidity toggle
		if (feature_invalidity < 0.5)
			feature_invalidity = 1;
		else
			feature_invalidity = 0;
 */
		
		// add entries to output file
		if (feature_invalidity <= 0.5)
			nw = fwrite(&feature_val, sizeof(sf4), (size_t) 1, outfile); 
		else
			// if feature is invalid, write zero instead of feature
			nw = fwrite(&zero_val, sizeof(sf4), (size_t) 1, outfile); 
		nw = fwrite(&feature_invalidity, sizeof(sf4), (size_t) 1, outfile);
	}
	
	fclose(infile);
	fclose(outfile);
	
	return 0;
}

