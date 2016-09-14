
#include "size_types.h"

/* get cpu endianness: 0 = big, 1 = little */
ui1	cpu_endianness()
{
	ui2	x = 1;
	
	return(*((ui1 *) &x));
}
	
/* in place */
void	reverse_in_place(void *x, si4 len)
{
	ui1	*pf, *pb, t;
	si4	i;
	
	pf = (ui1 *) x;
	pb = pf + len;
	for (i = len >> 1; i--;) {
		t = *pf;
		*pf++ = *--pb;
		*pb = t;
	}
}

/* value returning functions */
si2	rev_si2(si2 x)
{
	ui1	*pf, *pb;
	si2	xr;
	
	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 1;
	
	*pb-- = *pf++;
	*pb = *pf;
	
	return(xr);
}

ui2	rev_ui2(ui2 x)
{
	ui1	*pf, *pb;
	ui2	xr;
	
	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 1;
	
	*pb-- = *pf++;
	*pb = *pf;
			
	return(xr);
}

si4	rev_si4(si4 x)
{
	ui1	*pf, *pb;
	si4	xr;
	
	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 3;
	
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb = *pf;
	
	return(xr);
}

ui4	rev_ui4(ui4 x)
{
	ui1	*pf, *pb;
	ui4	xr;
	
	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 3;
	
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb = *pf;
	
	return(xr);
}

sf4	rev_sf4(sf4 x)
{
	ui1	*pf, *pb;
	sf4	xr;
	
	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 3;
	
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb = *pf;
	
	return(xr);
}

si8	rev_si8(si8 x)
{
	ui1	*pf, *pb;
	si8	xr;

	pf = (ui1 *) &x;
	pb = (ui1 *) &xr + 7;
	
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb-- = *pf++;
	*pb = *pf;
	
	return(xr);

}

ui8	rev_ui8(ui8 x)
{
	ui1	*pf, *pb;
	ui8	xr;
	
	if (x)
	{
		pf = (ui1 *) &x;
		pb = (ui1 *) &xr + 7;
		
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb = *pf; 
		
		return(xr);
	}
	else
	{
		return(x);
	}
}

sf8	rev_sf8(sf8 x)
{
	ui1	*pf, *pb;
	sf8	xr;
	
		pf = (ui1 *) &x;
		pb = (ui1 *) &xr + 7;
		
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb-- = *pf++;
		*pb = *pf;
		
		return(xr);

}

