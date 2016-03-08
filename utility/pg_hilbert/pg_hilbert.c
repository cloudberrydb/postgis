/*
 * The MIT License
 *
 * Copyright (c) 2015 Kuien Liu
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "postgres.h"
#include "fmgr.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "hilbert.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

Datum st_hilbert (PG_FUNCTION_ARGS);

/*
 * Turn this into a PostreSQL callable PL/C function
 *
 * Ref. http://www.postgresql.org/docs/9.2/static/xfunc-c.html
 *
 * Function: TEXT st_hilbert(FLOAT8 lat, FLOAT8 lon)
 *
 * CREATE FUNCTION st_hilbert(FLOAT8, FLOAT8) RETURNS integer 
 *   AS 'pg_hilbert', 'st_hilbert'
 *   LANGUAGE C;
 *
 *   psql      C           header
 * -----------------------------------------------
 *  float8   float8*     postgres.h
 *  varchar  VarChar*    postgres.h
 *  text     text*       postgres.h
 *
 */

PG_FUNCTION_INFO_V1 (st_hilbert);
Datum
st_hilbert(PG_FUNCTION_ARGS)
{
    double x, y;
    int l;
	long r;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1)) {
      PG_RETURN_NULL();
    }

    x = PG_GETARG_FLOAT8(0);
    y = PG_GETARG_FLOAT8(1);
    l = PG_GETARG_INT32(2);
    r = st_encode(x, y, l);

	/* elog(WARNING, "st_encode(%lf,%lf,%d)=%ld",x,y,l,r); */

    PG_RETURN_INT64(r);
}
