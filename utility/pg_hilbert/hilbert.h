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

#ifndef _LIB_HILBERT_H_
#define _LIB_HILBERT_H_

#include <stdbool.h>

#if defined(__cplusplus)
extern "C" {
#endif

/*
 * Interleave the bits from two input longeger values
 * @param odd longeger holding bit values for odd bit positions
 * @param even longeger holding bit values for even bit positions
 * @return the longeger that results from longerleaving the input bits
 */
long interleaveBits(long odd, long even);

/* Find the Hilbert order (=vertex index) for the given grid cell
 * coordinates.
 * @param x cell column (from 0)
 * @param y cell row (from 0)
 * @param r resolution of Hilbert curve (grid will have Math.pow(2,r)
 * rows and cols)
 * @return Hilbert order
 */
long encode(long x, long y, int r);
long st_encode(double x, double y, int r);


#if defined(__cplusplus)
}
#endif

#endif
