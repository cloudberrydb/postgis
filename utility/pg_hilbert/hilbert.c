/*
The MIT License

Copyright (c) 2011 lyo.kato@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include <ctype.h>
#include <stddef.h>
#include <stdlib.h>

#include "hilbert.h"

/*
 * Interleave the bits from two input longeger values
 * @param odd longeger holding bit values for odd bit positions
 * @param even longeger holding bit values for even bit positions
 * @return the longeger that results from longerleaving the input bits
 */
long interleaveBits(long odd, long even)
{
    long val = 0;
    long m = (odd >= even) ? odd:even;
    int n = 0, i = 0;
    long bitMask, a, b;

    while (m > 0)
    {
      n++;
      m >>= 1;
    }

    for (i = 0; i < n; i++)
    {
        bitMask = 1 << i;
        a = (even & bitMask) > 0 ? (1 << (2*i)) : 0;
        b = (odd & bitMask) > 0 ? (1 << (2*i+1)) : 0;
        val += a + b;
    }

    return val;
}

/* Find the Hilbert order (=vertex index) for the given grid cell
 * coordinates.
 * @param x cell column (from 0)
 * @param y cell row (from 0)
 * @param r resolution of Hilbert curve (grid will have Math.pow(2,r)
 * rows and cols)
 * @return Hilbert order
 */
long encode(long x, long y, int r)
{
    long mask = (1 << r) - 1;
    long hodd = 0;
    long heven = x ^ y;
    long notx = ~x & mask;
    long noty = ~y & mask;
    long temp = notx ^ y;
    int k;
    long v0 = 0, v1 = 0;

    for (k = 1; k < r; k++)
    {
        v1 = ((v1 & heven) | ((v0 ^ noty) & temp)) >> 1;
        v0 = ((v0 & (v1 ^ notx)) | (~v0 & (v1 ^ noty))) >> 1;
    }
    hodd = (~v0 & (v1 ^ x)) | (v0 & (v1 ^ noty));

    return  interleaveBits(hodd, heven);
}

long st_encode(double x, double y, int r)
{
    return encode(
        ((long)((x+180.0) * (1<<(r>>1)) / 360.0)),
        ((long)((y+90.0) * (1<<(r>>1)) / 180.0)),
		r
	);
}

