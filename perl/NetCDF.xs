/*
 * Undocumented things I've learned about writing XSUB's:
 *
 *  1.  av_len(AV*) returns the 0-based index of the last element (i.e.
 *      the number of elements minus 1).
 *
 *  2.  My way to distinguish between a reference to a scalar value and a
 *      reference to an array value is to obtain the referenced value and
 *      then do `SvIOK(sv) || SvNOK(sv) || SvPOK(sv)'.
 *
 *  3.  av_push() doesn't copy the pointed-to values.
 *
 *  4.  Values returned via arguments must be immortal.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdlib.h>	/* for malloc() */
#include <stdio.h>	/* for printing */
#include <string.h>	/* for memcpy() */
#include <assert.h>
#include <limits.h>
#include "netcdf.h"

/*
 * Macro for setting a scalar value either directly or through a reference:
 */
#define SV_SET(func, var, val)	func(SvROK(var) ? SvRV(var) : var, val)


typedef enum IntType
{
    IT_UNKNOWN,
    IT_CHAR,
    IT_SHORT,
    IT_INT,
    IT_NCLONG,
    IT_LONG,
    IT_FLOAT,
    IT_DOUBLE
} IntType;


typedef struct Value
{
    IntType	type;
    union
    {
	char	c;
	short	s;
	int	i;
	nclong	n;
	long	l;
	float	f;
	double	d;
    }		datum;
} Value;


typedef struct Vector
{
    char	*data;
    long	nelt;
    IntType	type;
    int		initialized;
} Vector;


typedef struct Record
{
    void	**data;
    Vector	*vecs;
    int		nvar;
    int		initialized;
} Record;


static IntType
nctype_inttype(nctype)
    nc_type	nctype;
{
    switch (nctype)
    {
	case NC_BYTE:
	    return IT_CHAR;
	case NC_CHAR:
	    return IT_CHAR;
	case NC_SHORT:
	    return IT_SHORT;
	case NC_LONG:
	    return IT_NCLONG;
	case NC_FLOAT:
	    return IT_FLOAT;
	case NC_DOUBLE:
	    return IT_DOUBLE;
	default:
	    return IT_UNKNOWN;
    }
}


static size_t
inttype_len(type)
    IntType	type;
{
    switch (type)
    {
	case IT_CHAR:
	    return sizeof(char);
	case IT_SHORT:
	    return sizeof(short);
	case IT_INT:
	    return sizeof(int);
	case IT_NCLONG:
	    return sizeof(nclong);
	case IT_LONG:
	    return sizeof(long);
	case IT_FLOAT:
	    return sizeof(float);
	case IT_DOUBLE:
	    return sizeof(double);
	default:
	    return 0;
    }
}


/*
 * Initialize a value from a specification.
 */
static void
value_initspec(value, type)
    Value	*value;
    IntType	type;
{
    value->type = type;
}


/*
 * Initialize a value structure from a perl reference value.
 */
static void
value_initref(value, type, ref)
    Value	*value;
    IntType	type;
    SV *	ref;
{
    value->type = type;

    switch (type)
    {
	case IT_CHAR:
	    value->datum.c = SvIV(ref);
	    break;
	case IT_SHORT:
	    value->datum.s = SvIV(ref);
	    break;
	case IT_INT:
	    value->datum.i = SvIV(ref);
	    break;
	case IT_NCLONG:
	    value->datum.n = SvIV(ref);
	    break;
	case IT_LONG:
	    value->datum.l = SvIV(ref);
	    break;
	case IT_FLOAT:
	    value->datum.f = SvNV(ref);
	    break;
	case IT_DOUBLE:
	    value->datum.d = SvNV(ref);
	    break;
	default:
	    break;
    }
}


/*
 * Print a value structure.
 */
#if 0
static void
value_print(value, stream, prefix)
    Value	*value;
    FILE	*stream;
    char	*prefix;
{
    (void) fprintf(stream, "%sType: ", prefix);

    switch (value->type)
    {
	case IT_CHAR:
	    (void) fputs("IT_CHAR\n", stream);
	    (void) fprintf(stream, "%sValue: %d\n",
			   prefix, value->datum.c);
	    break;
	case IT_SHORT:
	    (void) fputs("IT_SHORT\n", stream);
	    (void) fprintf(stream, "%sValue: %d\n",
			   prefix, value->datum.s);
	    break;
	case IT_INT:
	    (void) fputs("IT_INT\n", stream);
	    (void) fprintf(stream, "%sValue: %d\n",
			   prefix, value->datum.i);
	    break;
	case IT_NCLONG:
	    (void) fputs("IT_NCLONG\n", stream);
	    (void) fprintf(stream, "%sValue: %ld\n",
			   prefix, (long)value->datum.n);
	    break;
	case IT_LONG:
	    (void) fputs("IT_LONG\n", stream);
	    (void) fprintf(stream, "%sValue: %ld\n",
			   prefix, value->datum.l);
	    break;
	case IT_FLOAT:
	    (void) fputs("IT_FLOAT\n", stream);
	    (void) fprintf(stream, "%sValue: %g\n",
			   prefix, value->datum.f);
	    break;
	case IT_DOUBLE:
	    (void) fputs("IT_DOUBLE\n", stream);
	    (void) fprintf(stream, "%sValue: %g\n",
			   prefix, value->datum.d);
	    break;
    }
}
#endif


/*
 * Initialize a perl scalar value from a value structure.
 */
static void
sv_initvalue(scalar, value)
    SV		*scalar;
    Value	*value;
{
    switch (value->type)
    {
	case IT_CHAR:
	    sv_setiv(scalar, (IV)value->datum.c);
	    break;
	case IT_SHORT:
	    sv_setiv(scalar, (IV)value->datum.s);
	    break;
	case IT_INT:
	    sv_setiv(scalar, (IV)value->datum.i);
	    break;
	case IT_NCLONG:
	    sv_setiv(scalar, (IV)value->datum.n);
	    break;
	case IT_LONG:
	    sv_setiv(scalar, (IV)value->datum.l);
	    break;
	case IT_FLOAT:
	    sv_setnv(scalar, (double)value->datum.f);
	    break;
	case IT_DOUBLE:
	    sv_setnv(scalar, (double)value->datum.d);
	    break;
	default:
	    break;
    }
}


/*
 * Initialize a perl scalar value from an internal vector structure.
 *
 * Returns:
 *	1	Success
 *	0	Error
 */
static int
sv_initvec(sv, vec)
    SV		*sv;
    Vector	*vec;
{
    int		ok = 0;				/* error */

    if (vec->type != IT_CHAR && vec->nelt != 1)
	warn("Can't convert multi-element vector to scalar");
    else
    {
	switch (vec->type)
	{
	    case IT_CHAR:
		sv_setpvn(sv, (char*)vec->data, (int)vec->nelt);
		break;
	    case IT_SHORT:
		sv_setiv(sv, (IV)*(short*)vec->data);
		break;
	    case IT_INT:
		sv_setiv(sv, (IV)*(int*)vec->data);
		break;
	    case IT_NCLONG:
		sv_setiv(sv, (IV)*(nclong*)vec->data);
		break;
	    case IT_LONG:
		sv_setiv(sv, (IV)*(long*)vec->data);
		break;
	    case IT_FLOAT:
		sv_setnv(sv, (double)*(float*)vec->data);
		break;
	    case IT_DOUBLE:
		sv_setnv(sv, (double)*(double*)vec->data);
		break;
	    default:
		break;
	}

	ok = 1;
    }

    return ok;
}


/*
 * Destroy a perl reference value.
 */
static void
ref_destroy(ref)
    SV	*ref;
{
    sv_2mortal(ref);
}


/*
 * Initialize a perl array value from a vector.
 */
static int
av_initvec(av, vec)
    AV		*av;
    Vector	*vec;
{
    av_clear(av);	/* delete all elements in the AV */

    switch (vec->type)
    {
	case IT_CHAR:
	{
	    char	*ptr = (char*)vec->data;
	    char	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSViv((IV)*ptr));
	    break;
	}
	case IT_SHORT:
	{
	    short	*ptr = (short*)vec->data;
	    short	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSViv((IV)*ptr));
	    break;
	}
	case IT_INT:
	{
	    int	*ptr = (int*)vec->data;
	    int	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSViv((IV)*ptr));
	    break;
	}
	case IT_NCLONG:
	{
	    nclong	*ptr = (nclong*)vec->data;
	    nclong	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSViv((IV)*ptr));
	    break;
	}
	case IT_LONG:
	{
	    long	*ptr = (long*)vec->data;
	    long	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSViv((IV)*ptr));
	    break;
	}
	case IT_FLOAT:
	{
	    float	*ptr = (float*)vec->data;
	    float	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSVnv((double)*ptr));
	    break;
	}
	case IT_DOUBLE:
	{
	    double	*ptr = (double*)vec->data;
	    double	*end = ptr + vec->nelt;

	    for (; ptr < end; ++ptr)
		av_push(av, newSVnv((double)*ptr));
	    break;
	}
	default:
	    break;
    }

    return 1;
}


/*
 * Destroy a perl(1) array value.
 */
static void
av_destroy(av)
    AV		*av;
{
    av_undef(av);
}


/*
 * Destroy a perl scalar value.
 */
static void
sv_destroy(sv)
    SV		*sv;
{
    sv_2mortal(sv);
}


/*
 * Initialize a perl(1) reference from a vector structure.  The referenced
 * value shall exist.
 *
 * Returns:
 *	0	Error
 *	1	Success
 */
static int
ref_initvec(ref, vec)
    SV		*ref;			/* a perl(1) reference (in/out) */
    Vector	*vec;			/* vector of values (in) */
{
    int		ok = 0;			/* error */
    SV		*sv;

    sv = SvRV(ref);

    if (SvOK(sv) || SvIOK(sv) || SvNOK(sv) || SvPOK(sv))
    {
	/*
	 * The referenced value is scalar.
	 */
	if (sv_initvec(sv, vec))
	    ok = 1;
    }
    else
    {
	/*
	 * The referenced value must be an array.
	 */
	AV	*av = (AV*)sv;

	if (av_initvec(av, vec))
	    ok = 1;
    }

    return ok;
}


/*
 * Return a new perl(1) reference that has been initialized from a vector
 * structure.
 *
 * Returns:
 *	 NULL	Error
 *	!NULL	Success
 */
static SV*
ref_newvec(vec)
    Vector	*vec;			/* vector of values (in) */
{
    SV		*ref = NULL;

    if (vec->type == IT_CHAR)
    {
	/*
	 * Generate a perl string from the vector structure.
	 */
	SV	*sv;

	sv = newSVpv((char*)vec->data, (int)vec->nelt);

	if (sv == NULL)
	    warn("Couldn't allocate new perl string value");
	else
	{
	    ref = newRV(sv);
	    if (ref == NULL)
	    {
		sv_destroy(sv);
		warn("Couldn't allocate new perl reference to string value");
	    }
	}
    }
    else
    {
	/*
	 * Generate a perl array value from the vector structure.
	 */
	AV	*av = newAV();

	if (av == NULL)
	    warn("Couldn't allocate new perl array value");
	else
	{
	    int	ok = 0;

	    if (av_initvec(av, vec))
	    {
		ref = newRV((SV*)av);

		if (ref != NULL)
		    ok = 1;			/* success */
	    }

	    if (!ok)
		av_destroy(av);
	}					/* new AV obtained */
    }

    return ref;
}


/*
 * Initialize a perl(1) array value from a record structure.
 *
 * Returns:
 *	0	Error
 *	1	Success
 */
static int
av_initrec(av, rec)
    AV		*av;
    Record	*rec;
{
    int		ivar;
    int		ok = 0;				/* error */
    int		nelt = av_len(av) + 1;

    if (nelt && nelt != rec->nvar)
    {
	(void) fprintf(stderr, "av_initrec(): nvar=%d, nref=%d\n", 
		       rec->nvar, nelt);
	warn("Number of record variables doesn't match number of references");
    }
    else if (nelt == 0)
    {
	/*
	 * The array is empty.  Create references and add them.
	 */
	for (ivar = 0; ivar < rec->nvar; ++ivar)
	{
	    SV	*ref = ref_newvec(&rec->vecs[ivar]);

	    if (ref == NULL)
		break;

	    av_push(av, ref);
	}

	if (ivar >= rec->nvar)
	    ok = 1;
	else
	{
	    /* ivar is the index of the reference that wasn't initialized. */
	    while (ivar--)
		ref_destroy(av_pop(av));
	}
    }
    else
    {
	/*
	 * The array contains the correct number of references.  Put the
	 * data in the referenced variables.
	 */
	for (ivar = 0; ivar < rec->nvar; ++ivar)
	{
	    SV	**ref = av_fetch(av, (I32)ivar, (I32)0);

	    if (!SvROK(*ref))
	    {
		warn("Array value member is not a reference");
		break;
	    }
	    else
	    {
		SV	*sv = SvRV(*ref);

		if (SvIOK(sv) || SvNOK(sv) || SvPOK(sv))
		{
		    /*
		     * The perl reference refers to a scalar value.
		     */
		    if (!sv_initvec(sv, &rec->vecs[ivar]))
			break;
		}
		else
		{
		    /*
		     * The referenced variable is undefined or the 
		     * reference refers to an array value.
		     */
		    AV	*av = (AV*)sv;

		    if (!av_initvec(av, &rec->vecs[ivar]))
			break;
		}
	    }
	}

	if (ivar >= rec->nvar)
	    ok = 1;
    }

    return ok;
}


/*
 * Initialize a perl(1) reference variable from a record structure.
 *
 * Returns:
 *	0	Error
 *	1	Success
 */
#if 0
static int
ref_initrec(ref, rec)
    SV		**ref;
    Record	*rec;
{
    int		ok = 0;				/* error */
    AV		*av = newAV();

    if (av == NULL)
	warn("Couldn't allocate new perl array value");
    else
    {
	int	ivar;

	for (ivar = 0; ivar < rec->nvar; ++ivar)
	{
	    SV	*eltref = ref_newvec(&rec->vecs[ivar]);

	    if (eltref == NULL)
		break;

	    av_push(av, eltref);
	}

	if (ivar < rec->nvar)
	{
	    /* ivar is the index of the reference that wasn't initialized. */
	    while (ivar--)
		ref_destroy(av_pop(av));
	}
	else
	{
	    SV	*sv = newRV((SV*)av);

	    if (sv == NULL)
		warn("Couldn't allocate new perl reference value");
	    else
	    {
		*ref = sv;
		ok = 1;
	    }
	}
    }

    return ok;
}
#endif


/*
 * Return total number of data elements for a perl value.
 *
 * Recursive function.
 */
static long
pv_nelt(pv, type)
    SV		*pv;
    IntType	type;
{
    long	ntotal;

    if (SvROK(pv))
    {
	/*
	 * The scalar variable is a perl reference.
	 */
	ntotal = pv_nelt(SvRV(pv), type);
    }
    else
    {
	/*
	 * The scalar variable is not a perl reference.
	 */
	if (SvIOK(pv) || SvNOK(pv))
	{
	    /*
	     * The scalar variable is a numeric value.
	     */
	    ntotal = 1;
	}
	else
	if (SvPOK(pv))
	{
	    /*
	     * The scalar value is a string.
	     */
	    ntotal = type == IT_CHAR
			? SvCUR(pv)
			: 1;
	}
	else
	{
	    /*
	     * The `scalar variable' must be an array value.
	     */
	    AV		*list;
	    int		nelt;
	    int		i;

	    list = (AV*)pv;
	    nelt = av_len(list) + 1;
	    ntotal = 0;

#   	    if 0
		(void) fprintf(stderr, "pv_nelt(): nelt=%d\n", nelt);
#   	    endif

	    for (i = 0; i < nelt; ++i)
	    {
		SV	**sv;

#   	        if NP_DIAG_REF_NELT
		    (void) fprintf(stderr, "pv_nelt(): handling element %d\n",
				   i);
#   	        endif

		sv = av_fetch(list, (I32)i, (I32)0);

		ntotal += pv_nelt(*sv, type);
	    }
	}
    }

    return ntotal;
}


/*
 * Extract the data portion of a perl(1) value into contiguous memory.
 *
 * Recursive function.
 *
 * Can't fail.
 */
static char*
pv_data(pv, type, data)
    SV		*pv;
    IntType	type;
    char	*data;			/* SHALL have sufficient room */
{
    if (SvROK(pv))
    {
	/*
	 * The perl value is a perl reference.
	 */
	data = pv_data(SvRV(pv), type, data);
    }
    else
    if (!SvIOK(pv) && !SvNOK(pv) && !SvPOK(pv))
    {
	/*
	 * The perl value must be an array value.
	 */
	AV	*list;
	int	n;
	int	i;

	list = (AV*)pv;
	n = av_len(list) + 1;

	for (i = 0; i < n; ++i)
	{
	    SV	**sv;

#   	    if NP_DIAG_REF_DATA
		(void) fprintf(stderr, "pv_data(): handling element %d\n", i);
#   	    endif

	    sv = av_fetch(list, (I32)i, (I32)0);

	    data = pv_data(*sv, type, data);
	}
    }
    else
    {
	/*
	 * The perl value is a scalar value.
	 */
	switch (type)
	{
	    case IT_CHAR:
	    {
		if (SvPOK(pv))
		{
		    (void) memcpy(
			(char*)data, SvPV_nolen(pv), (size_t)SvCUR(pv));
		    data += SvCUR(pv);
		}
		else
		{
		    *(char*)data = SvIV(pv);
		    data += sizeof(char);
		}
		break;
	    }
	    case IT_SHORT:
	    {
		*(short*)data = SvIV(pv);
		data += sizeof(short);
		break;
	    }
	    case IT_INT:
	    {
		*(int*)data = SvIV(pv);
		data += sizeof(int);
		break;
	    }
	    case IT_NCLONG:
	    {
		*(nclong*)data = SvIV(pv);
		data += sizeof(nclong);
		break;
	    }
	    case IT_LONG:
	    {
		*(long*)data = SvIV(pv);
		data += sizeof(long);
		break;
	    }
	    case IT_FLOAT:
	    {
		*(float*)data = SvNV(pv);
		data += sizeof(float);
		break;
	    }
	    case IT_DOUBLE:
	    {
		*(double*)data = SvNV(pv);
		data += sizeof(double);
		break;
	    }
	    default:
		break;
	}
    }

    return data;
}


/*
 * Destroy a vector structure.
 */
static void
vec_destroy(vec)
    Vector	*vec;
{
    if (vec->data != NULL)
    {
	free((char*)vec->data);
	vec->data = NULL;
    }
    vec->type = 0;
    vec->nelt = 0;
    vec->initialized = 0;
}


/*
 * Initialize a vector structure from a perl(1) reference.
 */
static void
vec_initref(vec, type, ref)
    Vector	*vec;
    IntType	type;
    SV		*ref;
{
    size_t	nelt;
    char	*data;

#   if 0
	(void) fprintf(stderr, "vec_initref(): type=%d\n", (int)type);
#   endif

    nelt = pv_nelt(ref, type);
#   if 0
	(void) fprintf(stderr, "vec_initref(): nelt=%lu\n",
		       (unsigned long)nelt);
#   endif
    data = (char*)malloc(nelt * inttype_len(type));

    vec->initialized = 0;
    vec->nelt = 0;
    vec->data = 0;

    if (data == NULL)
    {
	warn("Couldn't allocate memory for vector data");
    }
    else
    {
	(void) pv_data(ref, type, data);

	vec->data = data;
	vec->type = type;
	vec->nelt = nelt;
	vec->initialized = 1;
    }
}


/*
 * Initialize a vector structure from a specification.
 */
static void
vec_initspec(vec, type, nelt)
    Vector	*vec;
    IntType	type;
    long	nelt;
{
    char	*data = malloc((size_t)(nelt * inttype_len(type)));

    if (data == NULL)
	warn("Couldn't allocate memory for vector structure");
    else
    {
	    vec->data = data;
	    vec->type = type;
	    vec->nelt = nelt;
	    vec->initialized = 1;
    }
}


/*
 * Initialize a record-variable vector-structure from a perl reference
 * and a netCDF dataset.  The pearl reference must match the netCDF record.
 */
static void
vec_initrecref(vec, ref, ncid, varid)
    Vector	*vec;
    SV		*ref;
    int		ncid;
    int		varid;
{
    nc_type	nctype;
    int		ndim;
    int		dimids[MAX_NC_DIMS];

#   if NP_DIAG_VEC_INITRECREF
	(void) fprintf(stderr, "vec_initrecref(): ncid=%d, varid=%d\n",
		       ncid, varid);
#   endif

    if (ncvarinq(ncid, varid, (char*)0, &nctype, &ndim, dimids, (int*)0)
	!= -1)
    {
	vec_initref(vec, nctype_inttype(nctype), ref);

	if (vec->initialized)
	{
	    int	ok = 0;

	    if (vec->nelt == 0)
	    {
		/* Empty record variable. */
		ok = 1;
	    }
	    else
	    {
		int	idim;
		long	nelt = 1;

		for (idim = 1; idim < ndim; ++idim)
		{
		    long	length;

		    if (ncdiminq(ncid, dimids[idim], (char*)0, &length) ==
			-1)
		    {
			break;
		    }

		    nelt *= length;
		}

#		if 0
		    (void) fprintf(stderr,
			"vec_initrecref(): vec->nelt=%d, nelt=%d\n",
			vec->nelt, nelt);
#		endif

		if (idim >= ndim)
		{
		    if (vec->nelt != nelt)
			warn("perl/netCDF record variable size mismatch");
		    else
			ok = 1;
		}
	    }

	    if (!ok)
		vec_destroy(vec);
	}					/* vector initialized */
    }						/* variable info obtained */
}


/*
 * Initialize a vector structure from a record variable.
 *
 * The values are read into the vector.
 */
static void
vec_initrec(vec, ncid, varid, recid)
    Vector	*vec;
    int		ncid;
    int		varid;
    long	recid;
{
    int		ndim;
    int		dimids[MAX_NC_DIMS];
    nc_type	nctype;

    vec->type = 0;
    vec->nelt = 0;
    vec->data = NULL;
    vec->initialized = 0;

    if (ncvarinq(ncid, varid, (char*)0, &nctype, &ndim, dimids, (int*)0) != -1)
    {
	int	idim;
	long	count[MAX_NC_DIMS];
	long	nelt = 1;

	/* Skip dimension 0, which must be the record dimension. */
	count[0] = 1;
	for (idim = 1; idim < ndim; ++idim)
	{
	    if (ncdiminq(ncid, dimids[idim], (char*)NULL, count+idim) == -1)
		break;
	    nelt *= count[idim];
	}

	if (idim >= ndim)
	{
	    vec_initspec(vec, nctype_inttype(nctype), nelt);
	    if (vec->initialized)
	    {
		static long	start[MAX_NC_DIMS];

		start[0] = recid;

		if (ncvarget(ncid, varid, start, count, vec->data) == -1)
		    vec_destroy(vec);
	    }
	}
    }
}


/*
 * Compute the integer product of the elements of a vector structure.
 */
static long
vec_prod(vec)
    Vector	*vec;
{
    char	*data = vec->data;
    char	*out = vec->data + vec->nelt * inttype_len(vec->type);
    long	prod = 1;

    switch (vec->type)
    {
	case IT_CHAR:
	{
	    char	*ptr = (char*)data;
	    char	*end = (char*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_SHORT:
	{
	    short	*ptr = (short*)data;
	    short	*end = (short*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_INT:
	{
	    int		*ptr = (int*)data;
	    int		*end = (int*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_NCLONG:
	{
	    nclong	*ptr = (nclong*)data;
	    nclong	*end = (nclong*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_LONG:
	{
	    long	*ptr = (long*)data;
	    long	*end = (long*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_FLOAT:
	{
	    float	*ptr = (float*)data;
	    float	*end = (float*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	case IT_DOUBLE:
	{
	    double	*ptr = (double*)data;
	    double	*end = (double*)out;

	    while (ptr < end)
		prod *= *ptr++;
	    break;
	}
	default:
	    break;
    }

    return prod;
}


/*
 * Print a vector structure.
 */
#if 0
static void
vec_print(vec, stream, prefix)
    Vector	*vec;
    FILE	*stream;
    char	*prefix;
{
    if (!vec->initialized)
	warn("vec_print(): Vector not initialized");
    else
    {
	(void) fprintf(stream, "%sVector type = %s\n",
		       prefix,
		       vec->type == IT_CHAR
			    ? "IT_CHAR"
			    : vec->type == IT_SHORT
				? "IT_SHORT"
				: vec->type == IT_INT
				    ? "IT_INT"
				    : vec->type == IT_NCLONG
					? "IT_NCLONG"
					: vec->type == IT_LONG
					    ? "IT_LONG"
					    : vec->type == IT_FLOAT
						? "IT_FLOAT"
						: vec->type == IT_DOUBLE
						    ? "IT_DOUBLE"
						    : "UNKNOWN");
	(void) fprintf(stream, "%sVector size = %ld\n", prefix, vec->nelt);
	(void) fprintf(stream, "%sValues = ", prefix);
	switch (vec->type)
	{
	    case IT_CHAR:
	    {
		char	*ptr = (char*)vec->data;
		char	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%d ", *ptr);
		break;
	    }
	    case IT_SHORT:
	    {
		short	*ptr = (short*)vec->data;
		short	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%d ", *ptr);
		break;
	    }
	    case IT_INT:
	    {
		int	*ptr = (int*)vec->data;
		int	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%d ", *ptr);
		break;
	    }
	    case IT_NCLONG:
	    {
		nclong	*ptr = (nclong*)vec->data;
		nclong	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%ld ", (long)*ptr);
		break;
	    }
	    case IT_LONG:
	    {
		long	*ptr = (long*)vec->data;
		long	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%ld ", *ptr);
		break;
	    }
	    case IT_FLOAT:
	    {
		float	*ptr = (float*)vec->data;
		float	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%g ", *ptr);
		break;
	    }
	    case IT_DOUBLE:
	    {
		double	*ptr = (double*)vec->data;
		double	*out = ptr + vec->nelt;

		for (; ptr < out; ++ptr)
		    (void) fprintf(stream, "%g ", *ptr);
		break;
	    }
	}					/* type switch */
	(void) putc('\n', stream);
    }						/* vector was initialized */
}
#endif


/*
 * Initialize a record from a reference and a netCDF dataset.
 */
static void
rec_initref(rec, ref, ncid)
    Record	*rec;
    SV		*ref;
    int		ncid;
{
    AV		*list = (AV*)SvRV(ref);
    int		nvar = av_len(list) + 1;
    int		*varids   = (int*)   malloc((size_t)(nvar*sizeof(int*)));
    long	*varsizes = (long*)  malloc((size_t)(nvar*sizeof(long)));
    void	**data    = (void**) malloc((size_t)(nvar*sizeof(void*)));
    Vector	*vecs     = (Vector*)malloc((size_t)(nvar*sizeof(Vector)));

#   if NP_DIAG_REC_INITREF
	(void) fprintf(stderr, "rec_initref(): ncid=%d\n", ncid);
#   endif

    rec->data = NULL;
    rec->vecs = NULL;
    rec->nvar = 0;
    rec->initialized = 0;

    if (vecs == NULL || data == NULL || varids == NULL || varsizes == NULL)
	warn("Couldn't allocate memory for record variables");
    else
    {
	int	ncnvar;

	if (ncrecinq(ncid, &ncnvar, varids, varsizes) != -1)
	{
	    if (ncnvar != nvar)
		warn("perl/netCDF record mismatch");
	    else
	    {
		int	ivar;

		for (ivar = 0; ivar < nvar; ++ivar)
		{
		    SV	**sv;

#   		    if NP_DIAG_REC_INITREF
			(void) fprintf(stderr, 
				       "rec_initref(): handling variable %d\n",
				       ivar);
#   		    endif

		    sv = av_fetch(list, (I32)ivar, (I32)0);

		    if (!SvROK(*sv))
		    {
			warn("Invalid perl record structure");
			break;
		    }

		    vec_initrecref(&vecs[ivar], *sv, ncid, varids[ivar]);
		    if (!vecs[ivar].initialized)
			break;

#   		    if NP_DIAG_REC_INITREF
			(void) fputs("Record vector:\n", stderr);
			vec_print(&vecs[ivar], stderr, "    ");
#   		    endif

		    data[ivar] = vecs[ivar].nelt == 0
				    ? NULL
				    : (void*)vecs[ivar].data;
		}				/* variable loop */

		if (ivar < nvar)
		{
		    /*
		     * ivar is the index of the vector that wasn't initialized.
		     */
		    while (ivar--)
			vec_destroy(&vecs[ivar]);
		}
		else
		{
		    rec->data = data;
		    rec->vecs = vecs;
		    rec->nvar = nvar;
		    rec->initialized = 1;
		}
	    }					/* same number variables */
	}					/* record info obtained */
    }						/* memory allocated */

    if (varids != NULL)
	free((char*)varids);
    if (varsizes != NULL)
	free((char*)varsizes);
    if (!rec->initialized)
    {
	if (data != NULL)
	    free((char*)data);
	if (vecs != NULL)
	    free((char*)vecs);
    }
}


/*
 * Initialize a record structure from a netCDF dataset.
 */
void rec_initnc(rec, ncid, recid)
    Record	*rec;
    int		ncid;
    long	recid;
{
    int		nvar;

    rec->data = NULL;
    rec->vecs = NULL;
    rec->nvar = 0;
    rec->initialized = 0;

    if (ncrecinq(ncid, &nvar, (int*)NULL, (long*)NULL) != -1)
    {
	int	*varids   = (int*)   malloc((size_t)(nvar*sizeof(int)));
	long	*varsizes = (long*)  malloc((size_t)(nvar*sizeof(long)));
	void	**data    = (void**) malloc((size_t)(nvar*sizeof(void*)));
	Vector	*vecs     = (Vector*)malloc((size_t)(nvar*sizeof(Vector)));

	if (varids == NULL || data == NULL || 
	    varsizes == NULL || vecs == NULL)
	{
	    warn("Couldn't allocate memory for record variables");
	}
	else if (ncrecinq(ncid, &nvar, varids, varsizes) != -1)
	{
	    int	ivar;

	    for (ivar = 0; ivar < nvar; ++ivar)
	    {
		vec_initrec(&vecs[ivar], ncid, varids[ivar], recid);
		if (!vecs[ivar].initialized)
		    break;

		data[ivar] = (void*)vecs[ivar].data;
	    }

	    if (ivar < nvar)
	    {
		/* ivar is the index of the vector that wasn't initialized. */
		while (ivar--)
		    vec_destroy(&vecs[ivar]);
	    }
	    else
	    {
		rec->data = data;
		rec->vecs = vecs;
		rec->nvar = nvar;
		rec->initialized = 1;
	    }
	}

	if (varids != NULL)
	    free((char*)varids);
	if (varsizes != NULL)
	    free((char*)varsizes);
	if (!rec->initialized)
	{
	    if (data != NULL)
		free((char*)data);
	    if (vecs != NULL)
		free((char*)vecs);
	}
    }
}


/*
 * Destroy a record.
 */
static void
rec_destroy(rec)
    Record	*rec;
{
    if (rec->data != NULL)
    {
	free((char*)rec->data);
	rec->data = NULL;
    }

    if (rec->vecs != NULL)
    {
	int	ivar;

	for (ivar = 0; ivar < rec->nvar; ++ivar)
	    vec_destroy(&rec->vecs[ivar]);

	free((char*)rec->vecs);
	rec->vecs = NULL;
    }

    rec->nvar = 0;
    rec->initialized = 0;
}


/*
 * Print a record.
 */
#if 0
static void
rec_print(rec, stream, prefix)
    Record	*rec;
    FILE	*stream;
    char	*prefix;
{
    if (!rec->initialized)
    {
	warn("rec_print(): Record not initialized");
    }
    else
    {
	int	ivar;

	(void) fprintf(stream, "%sNumber of variables = %d\n", 
		       prefix, rec->nvar);

	for (ivar = 0; ivar < rec->nvar; ++ivar)
	{
	    char	buf[128];

	    (void) fprintf(stream, "%sRecord variable %d:\n", prefix, ivar);

	    (void) strcat(strcpy(buf, prefix), "    ");

	    vec_print(&rec->vecs[ivar], stream, buf);

	    (void) fprintf(stream, "%sData pointers: %p ?= %p\n", 
			   buf, rec->data[ivar], rec->vecs[ivar].data);
	}
    }
}
#endif


#if 0
static int
not_here(s)
char *s;
{
    warn("%s not implemented on this architecture", s);
    return -1;
}
#endif

static double
constant(name, arg)
char *name;
int arg;
{
#if 0
    (void)printf("constant(): name=\"%s\", arg=%d\n", name, arg);
#endif
    errno = 0;
    switch (*name) {
    case 'A':
	break;
    case 'B':
	if (strEQ(name, "BYTE"))
	    return NC_BYTE;
	break;
    case 'C':
	if (strEQ(name, "CHAR"))
	    return NC_CHAR;
	if (strEQ(name, "CLOBBER"))
	    return NC_CLOBBER;
	break;
    case 'D':
	if (strEQ(name, "DOUBLE"))
	    return NC_DOUBLE;
	break;
    case 'E':
	if (strEQ(name, "EBADDIM"))
	    return NC_EBADDIM;
	if (strEQ(name, "EBADID"))
	    return NC_EBADID;
	if (strEQ(name, "EBADTYPE"))
	    return NC_EBADTYPE;
	if (strEQ(name, "EEXIST"))
	    return NC_EEXIST;
	if (strEQ(name, "EGLOBAL"))
	    return NC_EGLOBAL;
	if (strEQ(name, "EINDEFINE"))
	    return NC_EINDEFINE;
	if (strEQ(name, "EINVAL"))
	    return NC_EINVAL;
	if (strEQ(name, "EINVALCOORDS"))
	    return NC_EINVALCOORDS;
	if (strEQ(name, "EMAXATTS"))
	    return NC_EMAXATTS;
	if (strEQ(name, "EMAXDIMS"))
	    return NC_EMAXDIMS;
	if (strEQ(name, "EMAXNAME"))
	    return NC_EMAXNAME;
	if (strEQ(name, "EMAXVARS"))
	    return NC_EMAXVARS;
	if (strEQ(name, "ENAMEINUSE"))
	    return NC_ENAMEINUSE;
	if (strEQ(name, "ENFILE"))
	    return NC_ENFILE;
	if (strEQ(name, "ENOTATT"))
	    return NC_ENOTATT;
	if (strEQ(name, "ENOTINDEFINE"))
	    return NC_ENOTINDEFINE;
	if (strEQ(name, "ENOTNC"))
	    return NC_ENOTNC;
	if (strEQ(name, "ENOTVAR"))
	    return NC_ENOTVAR;
	if (strEQ(name, "ENTOOL"))
	    return NC_ENTOOL;
	if (strEQ(name, "EPERM"))
	    return NC_EPERM;
	if (strEQ(name, "ESTS"))
	    return NC_ESTS;
	if (strEQ(name, "EUNLIMIT"))
	    return NC_EUNLIMIT;
	if (strEQ(name, "EUNLIMPOS"))
	    return NC_EUNLIMPOS;
	if (strEQ(name, "EXDR"))
	    return NC_EXDR;
	break;
    case 'F':
	if (strEQ(name, "FATAL"))
	    return NC_FATAL;
	if (strEQ(name, "FILL"))
	    return NC_FILL;
	if (strEQ(name, "FILL_BYTE"))
	    return FILL_BYTE;
	if (strEQ(name, "FILL_CHAR"))
	    return FILL_CHAR;
	if (strEQ(name, "FILL_DOUBLE"))
	    return FILL_DOUBLE;
	if (strEQ(name, "FILL_FLOAT"))
	    return FILL_FLOAT;
	if (strEQ(name, "FILL_LONG"))
	    return FILL_LONG;
	if (strEQ(name, "FILL_SHORT"))
	    return FILL_SHORT;
	if (strEQ(name, "FLOAT"))
	    return NC_FLOAT;
	break;
    case 'G':
	if (strEQ(name, "GLOBAL"))
	    return NC_GLOBAL;
	break;
    case 'H':
	break;
    case 'I':
	break;
    case 'J':
	break;
    case 'K':
	break;
    case 'L':
	if (strEQ(name, "LONG"))
	    return NC_LONG;
	break;
    case 'M':
	if (strEQ(name, "MAX_ATTRS"))
	    return MAX_NC_ATTRS;
	if (strEQ(name, "MAX_DIMS"))
	    return MAX_NC_DIMS;
	if (strEQ(name, "MAX_NAME"))
	    return MAX_NC_NAME;
	if (strEQ(name, "MAX_OPEN"))
#ifdef MAX_NC_OPEN
	    return MAX_NC_OPEN;
#else
	    return UINT_MAX;
#endif
	if (strEQ(name, "MAX_VARS"))
	    return MAX_NC_VARS;
	if (strEQ(name, "MAX_VAR_DIMS"))
	    return MAX_VAR_DIMS;
	break;
    case 'N':
	if (strEQ(name, "NOCLOBBER"))
	    return NC_NOCLOBBER;
	if (strEQ(name, "NOERR"))
	    return NC_NOERR;
	if (strEQ(name, "NOFILL"))
	    return NC_NOFILL;
	if (strEQ(name, "NOWRITE"))
	    return NC_NOWRITE;
	break;
    case 'O':
	break;
    case 'P':
	break;
    case 'Q':
	break;
    case 'R':
	break;
    case 'S':
	if (strEQ(name, "SHORT"))
	    return NC_SHORT;
	if (strEQ(name, "SYSERR"))
	    return NC_SYSERR;
	break;
    case 'T':
	break;
    case 'U':
	if (strEQ(name, "UNLIMITED"))
	    return NC_UNLIMITED;
	break;
    case 'V':
	if (strEQ(name, "VERBOSE"))
	    return NC_VERBOSE;
	break;
    case 'W':
	if (strEQ(name, "WRITE"))
	    return NC_WRITE;
	break;
    case 'X':
	if (strEQ(name, "XDR_D_INFINITY"))
#ifdef XDR_D_INFINITY
	    return XDR_D_INFINITY;
#else
	    goto not_there;
#endif
	if (strEQ(name, "XDR_F_INFINITY"))
#ifdef XDR_F_INFINITY
	    return XDR_F_INFINITY;
#else
	    goto not_there;
#endif
	break;
    case 'Y':
	break;
    case 'Z':
	break;
    case 'a':
	break;
    case 'b':
	break;
    case 'c':
	break;
    case 'd':
	break;
    case 'e':
	break;
    case 'f':
	break;
    case 'g':
	break;
    case 'h':
	break;
    case 'i':
	break;
    case 'j':
	break;
    case 'k':
	break;
    case 'l':
	break;
    case 'm':
	break;
    case 'n':
	break;
    case 'o':
	break;
    case 'p':
	break;
    case 'q':
	break;
    case 'r':
	break;
    case 's':
	break;
    case 't':
	break;
    case 'u':
	break;
    case 'v':
	break;
    case 'w':
	break;
    case 'x':
	break;
    case 'y':
	break;
    case 'z':
	break;
    case '_':
	break;
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}


MODULE = NetCDF		PACKAGE = NetCDF	PREFIX=nc

double
constant(name,arg)
	char *		name
	int		arg


################################################################################
# netCDF control operations:
#

int
nccreate(path, cmode)
    char *	path
    int		cmode


int
ncopen(path, mode)
    char *	path
    int		mode
    CODE:
    {
	/*
	(void) fprintf(stderr, "ncopen(): path=\"%s\", mode=%d\n",
		       path, mode);
	*/

	RETVAL = ncopen(path, mode);
    }
    OUTPUT:
	RETVAL


int
ncredef(ncid)
    int		ncid


int
ncendef(ncid)
    int		ncid


int
ncclose(ncid)
    int		ncid


int
ncinquire(ncid, ndims, nvars, natts, recdim)
    int		ncid
    SV *	ndims
    SV *	nvars
    SV *	natts
    SV *	recdim
    CODE:
    {
	int	nd, nv, na0, rd;

	RETVAL = -1;				/* error */

	if (ncinquire(ncid, &nd, &nv, &na0, &rd) != -1)
	{
	    SV_SET(sv_setiv, ndims, (IV)nd);
	    SV_SET(sv_setiv, nvars, (IV)nv);
	    SV_SET(sv_setiv, natts, (IV)na0);
	    SV_SET(sv_setiv, recdim, (IV)rd);

	    RETVAL = 0;				/* success */
	}
    }
    OUTPUT:
	RETVAL


int
ncsync(ncid)
    int		ncid


int
ncabort(ncid)
    int		ncid


int
ncsetfill(ncid, fillmode)
    int		ncid
    int		fillmode


################################################################################
# Dimension control operations:
#

int
ncdimdef(ncid, name, size)
    int		ncid
    char *	name
    long	size


int
ncdimid(ncid, name)
    int		ncid
    char *	name


int
ncdiminq(ncid, dimid, name, length)
    int		ncid
    int		dimid
    SV *	name
    SV *	length
    CODE:
    {
	char	buf[MAX_NC_NAME+1];
	long	len;

	RETVAL = -1;				/* error */
	if (ncdiminq(ncid, dimid, buf, &len) != -1)
	{
	    SV_SET(sv_setpv, name, buf);
	    SV_SET(sv_setiv, length, (IV)len);

	    RETVAL = 0;				/* success */
	}
    }
    OUTPUT:
	RETVAL


int
ncdimrename(ncid, dimid, name)
    int		ncid
    int		dimid
    char *	name



################################################################################
# Variable operations:
#

int
ncvardef(ncid, name, type, dimids)
    int		ncid
    char *	name
    int		type
    SV *	dimids
    CODE:
    {
	Vector	dimvec;

	vec_initref(&dimvec, IT_INT, dimids);

	if (!dimvec.initialized)
	    RETVAL = -1;
	else
	{
	    RETVAL = ncvardef(ncid, name, type, (int)dimvec.nelt,
			      (int*)dimvec.data);
	    vec_destroy(&dimvec);
	}
    }
    OUTPUT:
	RETVAL


int
ncvarid(ncid, name)
    int		ncid
    char *	name


int
ncvarinq(ncid, varid, name, datatype, ndims, dimids, natts)
    int		ncid
    int		varid
    SV *	name
    SV *	datatype
    SV *	ndims
    SV *	dimids
    SV *	natts
    CODE:
    {
	Vector	dids;				/* dimension IDs */

	RETVAL = -1;				/* error */

	vec_initspec(&dids, IT_INT, (long)MAX_NC_DIMS);
	if (dids.initialized)
	{
	    int		nd;
	    int		na0;
	    char	nam[MAX_NC_NAME+1];
	    nc_type	type;

	    if (ncvarinq(ncid, varid, nam, &type, &nd, (int*)dids.data,
			 &na0) != -1)
	    {
#if 0
		SV *	ref;

		if (ref_initvec(&ref, dids))
		{
		    SV_SET(sv_setpv, name, nam);
		    SV_SET(sv_setiv, datatype, type);
		    SV_SET(sv_setiv, ndims, nd);
		    SV_SET(sv_setsv, dimids, ref);
		    SV_SET(sv_setiv, natts, na0);
		    RETVAL = 0;			/* success */
		}
#else
		if (av_initvec((AV*)SvRV(dimids), &dids))
		{
		    SV_SET(sv_setpv, name, nam);
		    SV_SET(sv_setiv, datatype, type);
		    SV_SET(sv_setiv, ndims, nd);
		    SV_SET(sv_setiv, natts, na0);
		    RETVAL = 0;			/* success */
		}
#endif
	    }
	    vec_destroy(&dids);
	}
    }
    OUTPUT:
	RETVAL


int
ncvarput1(ncid, varid, coords, value)
    int		ncid
    int		varid
    SV *	coords
    SV *	value
    CODE:
    {
	Vector	where;

	RETVAL = -1;				/* error */

	vec_initref(&where, IT_LONG, coords);
	if (where.initialized)
	{
	    nc_type	nctype;

	    if (ncvarinq(ncid, varid, (char*)NULL, &nctype, (int*)NULL,
			 (int*)NULL, (int*)NULL) != -1)
	    {
		Value	val;

		value_initref(&val, nctype_inttype(nctype), value);

		RETVAL = ncvarput1(ncid, varid, (long*)where.data, 
				   (char*)&val.datum);
	    }

	    vec_destroy(&where);
	}
    }
    OUTPUT:
	RETVAL


int
ncvarget1(ncid, varid, coords, value)
    int		ncid
    int		varid
    SV *	coords
    SV *	value
    CODE:
    {
	Vector	where;

	RETVAL = -1;				/* error */

	vec_initref(&where, IT_LONG, coords);

	/*
	(void) fputs("ncvarget1(): co-ordinate vector:\n", stderr);
	vec_print(&where, stderr, "    ");
	*/

	if (where.initialized)
	{
	    nc_type	nctype;

	    if (ncvarinq(ncid, varid, (char*)NULL, &nctype, (int*)NULL,
			 (int*)NULL, (int*)NULL) != -1)
	    {
		Value	val;

		value_initspec(&val, nctype_inttype(nctype));

		if (ncvarget1(ncid, varid, (long*)where.data, &val.datum) != -1)
		{
		    /*
		    (void) fputs("ncvarget1(): value obtained:\n", stderr);
		    value_print(&val, stderr, "    ");
		    */
		    sv_initvalue(value, &val);
		    RETVAL = 0;
		}
	    }

	    vec_destroy(&where);
	}
    }
    OUTPUT:
	RETVAL


int
ncvarput(ncid, varid, start, count, values)
    int		ncid
    int		varid
    SV *	start
    SV *	count
    SV *	values
    CODE:
    {
	nc_type		nctype;

	RETVAL = -1;				/* error */

	if (ncvarinq(ncid, varid, (char*)0, &nctype, (int*)0, (int*)0, (int*)0)
	    != -1)
	{
	    Vector	start_vec;

	    vec_initref(&start_vec, IT_LONG, start);
	    if (start_vec.initialized)
	    {
		Vector	count_vec;

		vec_initref(&count_vec, IT_LONG, count);
		if (count_vec.initialized)
		{
		    Vector	value_vec;

		    vec_initref(&value_vec, nctype_inttype(nctype), values);
		    if (value_vec.initialized)
		    {
			RETVAL = ncvarput(ncid,
					  varid,
					  (long*)start_vec.data,
					  (long*)count_vec.data,
					  value_vec.data);
			vec_destroy(&value_vec);
		    }
		    vec_destroy(&count_vec);
		}
		vec_destroy(&start_vec);
	    }
	}
    }
    OUTPUT:
	RETVAL


int
ncvarget(ncid, varid, start, count, values)
    int		ncid
    int		varid
    SV *	start
    SV *	count
    SV *	values
    CODE:
    {
	Vector	start_vec;

	RETVAL = -1;				/* error */

	vec_initref(&start_vec, IT_LONG, start);
	if (start_vec.initialized)
	{
	    Vector	count_vec;

	    vec_initref(&count_vec, IT_LONG, count);
	    if (count_vec.initialized)
	    {
		nc_type	nctype;

		if (ncvarinq(ncid, varid, (char*)0, &nctype, (int*)0,
			     (int*)0, (int*)0) != -1)
		{
		    Vector	value_vec;

		    vec_initspec(&value_vec,
				 nctype_inttype(nctype),
				 vec_prod(&count_vec));
		    if (value_vec.initialized)
		    {
			if (ncvarget(ncid, varid, (long*)start_vec.data,
				     (long*)count_vec.data, value_vec.data)
			    != -1)
			{
			    if (av_initvec((AV*)SvRV(values), &value_vec))
				RETVAL = 0;	/* success */
			}
			vec_destroy(&value_vec);
		    }				/* value vector initialized */
		}				/* value type obtained */
		vec_destroy(&count_vec);
	    }					/* count vector set */
	    vec_destroy(&start_vec);
	}					/* start vector set */
    }
    OUTPUT:
	RETVAL


int
ncvarrename(ncid, varid, name)
    int		ncid
    int		varid
    char *	name


################################################################################
# Attribute operations:
#

int
ncattput(ncid, varid, name, type, values)
    int		ncid
    int		varid
    char *	name
    int		type
    SV *	values
    CODE:
    {
	/*
	(void) fprintf(stderr, 
		       "ncattput(): ncid=%d, varid=%d, name=\"%s\", type=%d\n",
		       ncid, varid, name, type);
	*/

	if (SvROK(values))
	{
	    /*
	     * Reference value: must be a vector attribute.
	     */
	    Vector	vec;

	    vec_initref(&vec, nctype_inttype(type), values); 

	    if (!vec.initialized)
		RETVAL = -1;
	    else
	    {
		/*
		(void) fprintf(stderr, 
			       "ncattput(): nelt=%d\n", (int)vec.nelt);
		*/

		RETVAL = ncattput(ncid, varid, name, type, (int)vec.nelt, 
				  vec.data);
		vec_destroy(&vec);
	    }
	}					/* vector attribute */
	else
	{
	    /*
	     * Non-reference value: must be a scalar attribute.
	     */
	    union
	    {
		char	c;
		short	s;
		nclong	l;
		float	f;
		double	d;
	    }	val;
	    char	*ptr = (char*)&val;
	    int		len = 1;

	    switch (type)
	    {
		case NC_CHAR:
		    ptr = SvPV_nolen(values);
		    len = strlen(ptr) + 1;
		    break;
		case NC_BYTE:
		    val.c = SvIV(values);
		    break;
		case NC_SHORT:
		    val.s = SvIV(values);
		    break;
		case NC_LONG:
		    val.l = SvIV(values);
		    break;
		case NC_FLOAT:
		    val.f = SvNV(values);
		    break;
		case NC_DOUBLE:
		    val.d = SvNV(values);
		    break;
	    }

	    RETVAL = ncattput(ncid, varid, name, type, len, ptr);
	}					/* scalar attribute */
    }
    OUTPUT:
	RETVAL


int
ncattinq(ncid, varid, name, datatype, length)
    int		ncid
    int		varid
    char *	name
    SV *	datatype
    SV *	length
    CODE:
    {
	int	len;
	nc_type	nctype;

	RETVAL = -1;				/* error */

	if (ncattinq(ncid, varid, name, &nctype, &len) != -1)
	{
	    SV_SET(sv_setiv, datatype, (IV)nctype);
	    SV_SET(sv_setiv, length, (IV)len);
	    RETVAL = 0;				/* success */
	}
    }
    OUTPUT:
	RETVAL


int
ncattget(ncid, varid, name, value)
    int		ncid
    int		varid
    char *	name
    SV *	value
    CODE:
    {
	int	len;
	nc_type	nctype;

	/*
	(void) fprintf(stderr,
		       "ncattget(): ncid=%d, varid=%d, name=\"%s\"\n",
		       ncid, varid, name);
	 */

	RETVAL = -1;				/* error */

	if (ncattinq(ncid, varid, name, &nctype, &len) != -1)
	{
	    Vector	vec;

	    vec_initspec(&vec, nctype_inttype(nctype), (long)len);
	    if (vec.initialized)
	    {
		if (ncattget(ncid, varid, name, vec.data) != -1)
		{
		    /*
		    (void) fputs("ncattget(): Returned vector:\n", stderr);
		    vec_print(&vec, stderr, "    ");
		     */

		    if (ref_initvec(value, &vec))
		    {
			/*
			(void) fputs("ncattget(): Returned reference:\n",
				     stderr);
			vec_print(&vec, stderr, "    ");
			 */
			RETVAL = 0;		/* success */
		    }
		}

		vec_destroy(&vec);
	    }
	}
    }
    OUTPUT:
	RETVAL


int
ncattcopy(incdf, invar, name, outcdf, outvar)
    int		incdf
    int		invar
    char *	name
    int		outcdf
    int		outvar


int
ncattname(ncid, varid, attnum, name)
    int		ncid
    int		varid
    int		attnum
    SV *	name
    CODE:
    {
	char	buf[MAX_NC_NAME+1];

	RETVAL = ncattname(ncid, varid, attnum, buf);
	if (RETVAL != -1)
	{
	    buf[MAX_NC_NAME] = 0;
	    SV_SET(sv_setpv, name, buf);
	}
    }
    OUTPUT:
	RETVAL


int
ncattrename(ncid, varid, name, newname)
    int		ncid
    int		varid
    char *	name
    char *	newname


int
ncattdel(ncid, varid, name)
    int		ncid
    int		varid
    char *	name


################################################################################
# Record I/O operations:
#

int
ncrecput(ncid, recid, data)
    int		ncid
    long	recid
    SV *	data
    CODE:
    {
	Record	rec;

	/*
	(void) fprintf(stderr, "XS_NetCDF::recput(): ncid=%d, recid=%ld\n",
		       ncid, recid);
	*/

	RETVAL = -1;				/* error */

	rec_initref(&rec, data, ncid);
	if (rec.initialized)
	{
	    /*
	    (void) fputs("ncrecput() record:\n", stderr);
	    rec_print(&rec, stderr, "   ");
	    (void) fprintf(stderr, "*(short*)rec.data[0] = %d\n",
			   *(short*)rec.data[0]);
	     */

	    RETVAL = ncrecput(ncid, recid, rec.data);

	    rec_destroy(&rec);
	}
    }
    OUTPUT:
	RETVAL


int
ncrecget(ncid, recid, data)
    int		ncid
    long	recid
    SV *	data
    CODE:
    {
	Record	rec;

	RETVAL = -1;				/* error */

	rec_initnc(&rec, ncid, recid);

	if (rec.initialized)
	{
	    if (av_initrec((AV*)SvRV(data), &rec))
		RETVAL = 0;			/* success */

	    rec_destroy(&rec);
	}
    }
    OUTPUT:
	RETVAL


int
ncrecinq(ncid, nrecvars, recvarids, recsizes)
    int		ncid
    SV *	nrecvars
    SV *	recvarids
    SV *	recsizes
    CODE:
    {
	int	nvar;

	/*
	(void) fprintf(stderr, "ncrecinq(): ncid=%d\n");
	*/

	RETVAL = -1;				/* error */

	if (ncrecinq(ncid, &nvar, (int*)NULL, (long*)NULL) != -1)
	{
	    Vector	varids;

	    vec_initspec(&varids, IT_INT, (long)nvar);
	    if (varids.initialized)
	    {
		Vector	varlens;

		vec_initspec(&varlens, IT_LONG, (long)nvar);
		if (varlens.initialized)
		{
		    if (ncrecinq(ncid, (int*)NULL, (int*)varids.data,
				 (long*)varlens.data) != -1)
		    {
			if (av_initvec((AV*)SvRV(recvarids), &varids) &&
			    av_initvec((AV*)SvRV(recsizes), &varlens))
			{
			    /*
			    (void) fputs("ncrecinq(): Variable IDs:\n", stderr);
			    vec_print(&varids, stderr, "    ");
			    (void) fputs("ncrecinq(): Record sizes:\n", stderr);
			    vec_print(&varlens, stderr, "    ");
			    */

			    SV_SET(sv_setiv, nrecvars, (IV)nvar);
			    RETVAL = 0;		/* success */
			}
		    }

		    vec_destroy(&varlens);
		}

		vec_destroy(&varids);
	    }
	}
    }
    OUTPUT:
	RETVAL


################################################################################
# Miscellaneous operations:
#

int
nctypelen(datatype)
    int		datatype


int
ncopts(mode)
    int		mode
    CODE:
    {
	RETVAL = ncopts;
	ncopts = mode;
    }
    OUTPUT:
	RETVAL


int
ncerr()
    CODE:
	RETVAL = ncerr;
    OUTPUT:
	RETVAL


int
foo(outarg)
    SV *	outarg
    CODE:
    {
	if (!SvROK(outarg))
	{
	    (void) fputs("Setting scalar\n", stderr);
	    SV_SET(sv_setpv, outarg, "Scalar works!");
	}
	else
	{
#if 1
	    AV		*av = newAV();
	    SV		*ref = sv_2mortal(newRV((SV*)av));
	    /*
	     * Making the following 2 variables mortal causes no output
	     * values to be printed.
	     */
	    SV		*sv1 = newSVpv("one", 3);
	    SV		*sv2 = newSVpv("two", 3);

	    (void) fputs("Setting reference\n", stderr);

	    /*
	     * av_push() doesn't copy the pointed-to values.
	     */
	    av_push(av, sv1);
	    av_push(av, sv2);

	    /*
	     * Using either of the following causes $outarg to not be
	     * an array.
	     *    *outarg = *ref
	     *     outarg =  ref;
	     */

	    /* Using (SV*)av in the following causes a SEGV. */
	    SV_SET(sv_setsv, outarg, ref);
#else
	    char	*string = "Reference works!";
	    SV		*newval = sv_2mortal(newSVpv(string, strlen(string)));
	    SV		*ref = sv_2mortal(newRV(newval));

	    SV_SET(sv_setsv, outarg, ref);
#endif
	}
	/*
	 * It is not necessary to set ST(1) from outarg.
	 *
	 * SV_SET(sv_setsv, ST(1), outarg);
	 */
	RETVAL = 1;				/* success */
    }
    OUTPUT:
	RETVAL


void
foo2()
    PPCODE:
    {
	AV	*av = newAV();

	av_push(av, newSViv(1));
	av_push(av, newSViv(2));

	EXTEND(sp, 1);
	PUSHs(sv_2mortal(newRV((SV*)av)));
    }


void
foo3()
    PPCODE:
    {
	EXTEND(sp, 2);
	PUSHs(sv_2mortal(newSViv(3)));
	PUSHs(sv_2mortal(newSViv(4)));
    }


int
foo4(ref)
    SV *	ref
    CODE:
    {
	AV	*av = newAV();

	av_push(av, newSViv(5));
	av_push(av, newSViv(6));

	SV_SET(sv_setsv, ref, newRV((SV*)av));

	RETVAL = 1;
    }
    OUTPUT:
	RETVAL

int
foo5(ref)
    SV *	ref
    CODE:
    {
	int	vals[5];
	Vector	vec;

	vals[0] = 0;
	vals[1] = 1;
	vals[2] = 2;
	vals[3] = 3;
	vals[4] = 4;

	vec_initspec(&vec, IT_INT, 4);
	if (vec.initialized)
	{
	    (void) memcpy((void*)vec.data, vals, sizeof(int)*4);
	    if (av_initvec((AV*)SvRV(ref), &vec))
		RETVAL = 0;
	    vec_destroy(&vec);
	}
    }
    OUTPUT:
	RETVAL
