#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "mex.h"

void uutc_time_from_date(char *tz, double yr, double mo, double dy, double hr, double mn, double sc, unsigned long long *uutc_time)
{
	struct tm	tm;
	time_t		UTC_secs;
	long		gm_offset;
	
	tm.tm_sec = (int) sc;
	tm.tm_min = (int) mn;
	tm.tm_hour = (int) hr;
	tm.tm_mday = (int) dy;
	tm.tm_mon = (int) (mo - 1.0);
	tm.tm_year = (int) (yr - 1900.0);
	tm.tm_zone = tz;
	
	switch (tz[0]) {
		case 'E': gm_offset = -5; break;
		case 'C': gm_offset = -6; break;
		case 'M': gm_offset = -7; break;
		case 'P': gm_offset = -8; break;
		default:
			fprintf(stderr, "Unrecognized timezone");
			return;
	}	
	if (tz[1] == 'D') {
		gm_offset -= 1;
		tm.tm_isdst = 1;
	}
	tm.tm_gmtoff = gm_offset * 3600;
		
	UTC_secs = mktime(&tm);
	
	*uutc_time = (unsigned long long) (UTC_secs - (int) sc) * 1000000;
	*uutc_time += (unsigned long long) ((sc * 1000000.0) + 0.5);
	
	return;
}


/* The gateway routine */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	int			i, dims[2];
	char			timezone[4];
	double			year, month, day, hour, minute, second;
	unsigned long long int	*uutc_time;
	
	/* called from Matlab as uutc_time = uutc_time_from_date(char *timezone, double year, double month, double day, double hour, double minute, double second); */
	
	/*  Check for proper number of arguments */
	if (nrhs != 7) 
		mexErrMsgTxt("Seven inputs required: timezone, year, month, day, hour, minute, second");
	if (nlhs != 1) 
		mexErrMsgTxt("One output required: uutc_time");
	
	/* Check to make input arguments are scalar */
	for (i = 1; i < 7; ++i) {
		if( !mxIsDouble(prhs[i]) || mxIsComplex(prhs[i]) || (mxGetN(prhs[i]) * mxGetM(prhs[i]) != 1) ) {
			mexErrMsgTxt("Time inputs must be a scalar.");
		}			
	}
	
	/* get arguments */
	mxGetString(prhs[0], timezone, 4);
	year = (double) mxGetScalar(prhs[1]);
	month = (double) mxGetScalar(prhs[2]);
	day = (double) mxGetScalar(prhs[3]);
	hour = (double) mxGetScalar(prhs[4]);
	minute = (double) mxGetScalar(prhs[5]);
	second = (double) mxGetScalar(prhs[6]);
	
	/* Set the output pointer to the output matrix. */
	dims[0] = 1; dims[1] = 1;
	plhs[0] = mxCreateNumericArray(2, dims, mxUINT64_CLASS, mxREAL);
	
	/* Create a C pointer to a copy of the output matrix. */
	uutc_time = (unsigned long long *) mxGetPr(plhs[0]);
	
	/* Call the C subroutine. */
	uutc_time_from_date(timezone, year, month, day, hour, minute, second, uutc_time);
	
	return;
}
