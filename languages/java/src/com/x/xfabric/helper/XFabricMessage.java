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
package com.x.xfabric.helper;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Enumeration;
import java.util.HashMap;

import javax.servlet.http.HttpServletRequest;

import org.apache.avro.Schema;
import org.apache.avro.generic.IndexedRecord;

import com.x.xfabric.helper.avro.AvroContentType;
import com.x.xfabric.helper.avro.AvroEncDecoder;

/**
 * @author palavilli
 * 
 *         A message sent by the fabric
 */
public class XFabricMessage {

	/**
	 * Constant for the Authorization header name
	 */
	private static String AUTHORIZATION_HDR = "Authorization";
	/**
	 * Name of the content type header
	 */
	private static String CONTENTTYPE_HDR = "Content-Type";
	/**
	 * Name of the Tenant ID header sent by the fabric
	 */
	private static String TENANTID_HDR = "X-XC-TENANT-ID";
	/**
	 * Name of the Publisher header sent by the fabric
	 */
	private static String PUBLISHER_HDR = "X-XC-PUBLISHER-ID";
	/**
	 * Name of the deprecated Publisher header sent by the fabric
	 */
	private static String PUBLISHER_DEP_HDR = "X-XC-PUBLISHER-DESTINATION-ID ";
	/**
	 * Name of the Publisher header sent by the fabric
	 */
	private static String PUBLISHER_PSEUDONYM_HDR = "X-XC-PUBLISHER-PSEUDONYM";
	/**
	 * Name of the deprecated Publisher header sent by the fabric
	 */
	private static String PUBLISHER_PSEUDONYM_DEP_HDR = "X-XC-PUBLISHER";
	/**
	 * Name of the Message GUID header sent by the fabric
	 */
	private static String MESSAGEGUID_HDR = "X-XC-MESSAGE-GUID";
	/**
	 * Name of the schema URI header sent by the fabric
	 */
	private static String SCHEMAURI_HDR = "X-XC-SCHEMA-URI";
	/**
	 * Name of the schema version header sent by the fabric
	 */
	private static String SCHEMAVERSION_HDR = "X-XC-SCHEMA-VERSION";
	/**
	 * Name of the correlation id sent by the fabric
	 */
	private static String CORRELATIONID_HDR = "X-XC-RESULT-CORRELATION-ID";

	/**
	 * Bearer Token of the message publisher
	 */
	private String bearerToken;
	/**
	 * HTTP Headers sent by the fabric, Header names stored in lower case.
	 */
	private HashMap<String, String> headers;
	/**
	 * Name of the topic
	 */
	private String topicName;
	/**
	 * Tenant ID provided by the message publisher
	 */
	private String tenantId;
	/**
	 * Destination id of the publisher that is used for routing messages to the
	 * publisher. This value is set only for topics that are configured to
	 * reveal the publisher's identity.
	 */
	private String publisher;
	/**
	 * Publisher pseudonym used for routing error messages back to the
	 * publisher. This header is set for messages on all topics.
	 */
	private String publisherPseudonym;
	/**
	 * message guid
	 */
	private String messageGuid;
	/**
	 * Correlation identifier to relate messages as a group
	 */
	private String correlationId;
	/**
	 * raw message in bytes
	 */
	private byte[] rawMessage;
	/**
	 * Avro content-type - binary or json
	 */
	private AvroContentType contentType;
	/**
	 * indicated if the message is an system message from the Fabric. These
	 * include the following topics: /message/failed
	 * /xfabric/capability/endpoint/results /xfabric/tenant/updated
	 * /xfabric/topic/define/results /xfabric/topic/registration/results
	 */
	private boolean isFabricSystemMessage = false;
	/**
	 * Schema version of the incoming message
	 */
	private String schemaVersion;
	/**
	 * URI where the schema corresponding to the incoming payload can be read
	 */
	private String schemaURI;

	/**
	 * Constructor to process an incoming Avro message from XFabric
	 * 
	 * @param request
	 * @throws IOException
	 * @throws URISyntaxException
	 */
	public XFabricMessage(HttpServletRequest request) throws IOException {
		this.bearerToken = request.getHeader("Authorization");
		this.headers = new HashMap<String, String>();
		this.topicName = request.getPathInfo();

		Enumeration<?> keys = request.getHeaderNames();
		while (keys.hasMoreElements()) {
			String headerName = ((String) keys.nextElement()).toLowerCase();
			Enumeration<?> values = request.getHeaders(headerName);
			StringBuilder headerValue = new StringBuilder();
			boolean isFirst = true;
			while (values.hasMoreElements()) {
				if (!isFirst)
					headerValue.append(", ");
				headerValue.append((String) values.nextElement());
				isFirst = false;
			}
			this.headers.put(headerName, headerValue.toString());
		}

		rawMessage = getMessageBody(request);
		this.contentType = AvroContentType.getAvroContentType(this
				.getHeader(CONTENTTYPE_HDR));
		contentType = AvroContentType.AVRO_BINARY;
		this.bearerToken = this.getHeader(AUTHORIZATION_HDR);
		this.tenantId = this.getHeader(TENANTID_HDR);
		this.publisher = (this.getHeader(PUBLISHER_HDR) != null) ? 
				this.getHeader(PUBLISHER_HDR) : this.getHeader(PUBLISHER_DEP_HDR);
		this.publisherPseudonym = (this.getHeader(PUBLISHER_PSEUDONYM_HDR) != null) ? 
				this.getHeader(PUBLISHER_PSEUDONYM_HDR) : this.getHeader(PUBLISHER_PSEUDONYM_DEP_HDR);
		this.messageGuid = this.getHeader(MESSAGEGUID_HDR);
		this.schemaVersion = this.getHeader(SCHEMAVERSION_HDR);
		this.schemaURI = this.getHeader(SCHEMAURI_HDR);
		this.correlationId = this.getHeader(CORRELATIONID_HDR);

		if ("/message/failed".equals(this.topicName)
				|| "/xfabric/capability/endpoint/results"
						.equals(this.topicName)
				|| "/xfabric/tenant/updated".equals(this.topicName)
				|| "/xfabric/topic/define/results".equals(this.topicName)
				|| "/xfabric/topic/registration/results".equals(this.topicName)
				|| "/system/capability/endpoint/updateFailed".equals(this.topicName)
				|| "/system/capability/endpoint/updated".equals(this.topicName)
				|| "/system/tenant/relationship/created".equals(this.topicName)
			) {
			this.isFabricSystemMessage = true;
		}

	}

	/**
	 * extracts the avro message from the http request
	 * 
	 * @param request
	 *            HttpServletRequest
	 * @return byte[]
	 * @throws IOException
	 */
	private static byte[] getMessageBody(HttpServletRequest request)
			throws IOException {
		// Attempt to pre-allocate a sufficient buffer
		int length = request.getContentLength();
		if (length < 0) {
			length = 4096;
		}
		ByteArrayOutputStream baos = new ByteArrayOutputStream(length);
		byte[] buffer = new byte[4096];
		int n;
		InputStream in = request.getInputStream();
		while ((n = in.read(buffer)) > 0) {
			baos.write(buffer, 0, n);
		}
		return baos.toByteArray();
	}

	/**
	 * @return bearerToken Bearer Token to authenticate the publisher/tenent
	 */
	public String getBearerToken() {
		return bearerToken;
	}

	/**
	 * @return headers Http Headers from XFabric request with key names in lower
	 *         case.
	 */
	public HashMap<String, String> getHeaders() {
		return headers;
	}

	/**
	 * @param name
	 *            Http Header Name (case-insensitive)
	 * @return header value
	 */
	public String getHeader(String name) {
		if (name != null) {
			return headers.get(name.toLowerCase());
		} else {
			return null;
		}
	}

	/**
	 * @return topic name
	 */
	public String getTopicName() {
		return topicName;
	}

	/**
	 * @return tenant Id
	 */
	public String getTenantId() {
		return tenantId;
	}

	/**
	 * @return publisher id
	 */
	public String getPublisher() {
		return publisher;
	}

	/**
	 * @return publisher pseudonym
	 */
	public String getPublisherPseudonym() {
		return publisherPseudonym;
	}

	/**
	 * @return message guid provided by the fabric
	 */
	public String getMessageGuid() {
		return messageGuid;
	}

	/**
	 * @return the schemaURI
	 */
	public String getSchemaURI() {
		return schemaURI;
	}

	/**
	 * @return the schemaVersion
	 */
	public String getSchemaVersion() {
		return schemaVersion;
	}

	/**
	 * @return the correlationId
	 */
	public String getCorrelationId() {
		return correlationId;
	}

	/**
	 * @return raw message in bytes
	 */
	public byte[] getRawMessage() {
		return rawMessage;
	}

	/**
	 * @return message record based on the given schema
	 * @throws IOException
	 */
	public IndexedRecord getMessage(Schema readerSchema) throws IOException {
		Schema writerSchema = null;
		// If the incoming message is on the same version as what
		// the reader is expecting to see, use same schema for reader
		// and writer
		if (this.getSchemaVersion().equals(readerSchema.getProp("version"))) {
			writerSchema = readerSchema;
		} else {
			writerSchema = SchemaCache.getSchema(topicName, schemaVersion,
					new URL(schemaURI));
		}

		if (this.contentType == AvroContentType.AVRO_BINARY) {
			return AvroEncDecoder.decode(this.rawMessage, writerSchema,
					readerSchema, AvroContentType.AVRO_BINARY);
		} else if (this.contentType == AvroContentType.AVRO_JSON) {
			return AvroEncDecoder.decode(this.rawMessage, writerSchema,
					readerSchema, AvroContentType.AVRO_JSON);
		} else {
			System.out.println("Unknown content-type:"
					+ this.contentType.getContentType());
			return null;
		}
	}

	/**
	 * @return message in Json String based on the given schema
	 * @throws IOException
	 */
	public String getMessageAsJsonString(Schema readerSchema)
			throws IOException {
		Schema writerSchema = null;
		// If the incoming message is on the same version as what
		// the reader is expecting to see, use same schema for reader
		// and writer
		if (this.getSchemaVersion().equals(readerSchema.getProp("version"))) {
			writerSchema = readerSchema;
		} else {
			writerSchema = SchemaCache.getSchema(topicName, schemaVersion,
					new URL(schemaURI));
		}
		if (this.contentType == AvroContentType.AVRO_BINARY) {
			IndexedRecord record = AvroEncDecoder.decode(this.rawMessage,
					writerSchema, readerSchema, AvroContentType.AVRO_BINARY);
			return new String(AvroEncDecoder.encode(record,
					AvroContentType.AVRO_JSON));
		} else if (this.contentType == AvroContentType.AVRO_JSON) {
			IndexedRecord record = AvroEncDecoder.decode(this.rawMessage,
					writerSchema, readerSchema, AvroContentType.AVRO_JSON);
			return new String(AvroEncDecoder.encode(record,
					AvroContentType.AVRO_JSON));
		} else {
			System.out.println("Unknown content-type:"
					+ this.contentType.getContentType());
			return null;
		}
	}

	/**
	 * @return message in Json String without conforming to any reader scheme
	 *         (uses writer schema)
	 * @throws IOException
	 */
	public String getMessageAsJsonString() throws IOException {

		if (this.contentType == AvroContentType.AVRO_BINARY) {
			Schema writerSchema = SchemaCache.getSchema(topicName,
					schemaVersion, new URL(schemaURI));
			IndexedRecord record = AvroEncDecoder.decode(this.rawMessage,
					writerSchema, writerSchema, AvroContentType.AVRO_BINARY);
			return new String(AvroEncDecoder.encode(record,
					AvroContentType.AVRO_JSON));
		} else {
			return new String(this.rawMessage, "UTF-8");
		}
	}

	/**
	 * @return content-type of the Avro message received
	 */
	public String getContentType() {
		if (this.contentType != null) {
			return contentType.getContentType();
		} else {
			return "unknown";
		}
	}

	/**
	 * @return true if the topic represents an internal Fabric message, false if
	 *         it's related to capabilities
	 */
	public boolean isFabricSystemMessage() {
		return isFabricSystemMessage;
	}

	/**
	 * @param tenantBearerToken
	 * @return true if the tenantBearerToken matches the token sent in the
	 *         Authorization Header
	 */
	public boolean isAuthorized(String tenantBearerToken) {

		if (this.bearerToken.equals(tenantBearerToken.trim())) {
			return true;
		}
		return false;
	}

}
