/*
Copyright (c) 2011, X.Commerce

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the 
following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following
disclaimer.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with the distribution.  Neither the name of
the nor the names of its contributors may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
package com.x.xfabric.helper.avro;

import java.io.IOException;
import org.apache.avro.file.SeekableInput;

class SeekableByteArray implements SeekableInput {
	private final byte[] data;
	private int pos = 0;

	public SeekableByteArray(byte[] data) {
		this.data = data;
	}

	@Override
	public long length() throws IOException {
		return this.data.length;
	}

	@Override
	public void seek(long p) throws IOException {
		this.pos = (int) p;
	}

	@Override
	public long tell() throws IOException {
		return this.pos;
	}

	@Override
	public int read(byte[] b, int off, int len) throws IOException {
		if ( b == null ) {
			throw new NullPointerException();
		}
		if ( off < 0 ) {
			throw new IndexOutOfBoundsException(
			        "Offset cannot be less than zero" );
		}
		if ( len < 0 ) {
			throw new IndexOutOfBoundsException(
			        "Length cannot be less than zero" );
		}
		if ( len > ( b.length - off ) ) {
			throw new IndexOutOfBoundsException(
			        "Cannot read past end of provided buffer" );
		}
		if ( this.pos >= this.data.length ) {
			return -1;
		}
		int lenToRead = len;
		if ( ( this.pos + lenToRead ) > this.data.length ) {
			lenToRead = this.data.length - this.pos;
		}
		if ( lenToRead <= 0 ) {
			return 0;
		}
		System.arraycopy( this.data, this.pos, b, off, lenToRead );
		this.pos += lenToRead;
		return lenToRead;
	}

	@Override
	public void close() throws IOException {
		// Nothing to do
	}
}
