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

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

import org.apache.avro.Schema;
import org.apache.avro.generic.IndexedRecord;
import org.apache.avro.io.Decoder;
import org.apache.avro.io.DecoderFactory;
import org.apache.avro.io.Encoder;
import org.apache.avro.io.EncoderFactory;
import org.apache.avro.specific.SpecificDatumReader;
import org.apache.avro.specific.SpecificDatumWriter;

public class AvroEncDecoder {
	/**
	 * 
	 */
	private static final int BUFFER_SIZE = 4096;

	/**
	 * Encode message using specified content type. Note that the binary form
	 * contains schema info, while the json form does not.
	 * 
	 * @param <T>
	 *            The data type of the object, which must extend
	 *            {@link IndexedRecord}
	 * @param object
	 *            The object to encode
	 * @param type
	 *            The content type
	 * @return The encoded object as a byte array
	 * @throws IOException
	 *             If there is an encoding error
	 */
	public static <T extends IndexedRecord> byte[] encode(T object,
			AvroContentType type) throws IOException {
		Schema schema = object.getSchema();
		if (type == AvroContentType.AVRO_JSON) {
			return encodeJSON(object, schema);
		} else {
			return encodeBinary(object, schema);
		}
	}

	/**
	 * Decode the message using the specified content type.Note that the binary
	 * form contains schema info, while the json form does not.
	 * 
	 * @param <T>
	 *            The data type of the object, which must extend
	 *            {@link IndexedRecord}
	 * @param data
	 *            The object to decode
	 * @param writerSchema
	 *            The schema that was used to write the message
	 * @param readerSchema
	 *            The expected schema for the message This may or may not be the
	 *            same as the writerSchema
	 * @param type
	 *            The content type
	 * @return The decoded object
	 * @throws IOException
	 *             If there is a decoding error
	 */
	public static <T extends IndexedRecord> T decode(byte[] data,
			Schema writerSchema, Schema readerSchema, AvroContentType type)
			throws IOException {
		if (type == AvroContentType.AVRO_JSON) {
			return AvroEncDecoder.<T> decodeJSON(data, writerSchema,
					readerSchema);
		} else {
			return AvroEncDecoder.<T> decodeBinary(data, writerSchema,
					readerSchema);
		}
	}

	private static <T extends IndexedRecord> T decodeJSON(byte[] data,
			Schema writerSchema, Schema readerSchema) throws IOException {
		ByteArrayInputStream bais = new ByteArrayInputStream(data);
		SpecificDatumReader<T> reader = new SpecificDatumReader<T>(
				writerSchema, readerSchema);
		Decoder decoder = DecoderFactory.get().jsonDecoder(readerSchema, bais);
		T result = reader.read(null, decoder);
		bais.close();
		return result;
	}

	private static <T extends IndexedRecord> byte[] encodeJSON(T object,
			Schema schema) throws IOException {
		ByteArrayOutputStream baos = new ByteArrayOutputStream(BUFFER_SIZE);
		SpecificDatumWriter<T> writer = new SpecificDatumWriter<T>(
				object.getSchema());
		Encoder encoder = EncoderFactory.get().jsonEncoder(schema, baos);
		writer.write(object, encoder);
		encoder.flush();
		baos.close();
		return baos.toByteArray();
	}

	private static <T extends IndexedRecord> byte[] encodeBinary(T object,
			Schema schema) throws IOException {
		ByteArrayOutputStream baos = new ByteArrayOutputStream(BUFFER_SIZE);
		SpecificDatumWriter<T> writer = new SpecificDatumWriter<T>(
				object.getSchema());
		Encoder encoder = EncoderFactory.get().binaryEncoder(baos, null);
		writer.write(object, encoder);
		encoder.flush();
		baos.close();
		return baos.toByteArray();
	}

	private static <T extends IndexedRecord> T decodeBinary(byte[] data,
			Schema writerSchema, Schema readerSchema) throws IOException {
		ByteArrayInputStream bais = new ByteArrayInputStream(data);
		SpecificDatumReader<T> reader = new SpecificDatumReader<T>(
				writerSchema, readerSchema);
		Decoder decoder = DecoderFactory.get().binaryDecoder(bais, null);
		T result = reader.read(null, decoder);
		bais.close();
		return result;

	}
}
