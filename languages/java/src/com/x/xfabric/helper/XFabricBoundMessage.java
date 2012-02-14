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

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;

import org.apache.avro.generic.IndexedRecord;

import com.x.xfabric.helper.avro.AvroContentType;
import com.x.xfabric.helper.avro.AvroEncDecoder;

/**
 * @author vichandrasekaran
 * 
 *         A message that is sent to the fabric
 */
public class XFabricBoundMessage {

	/**
	 * An application generated value used to uniquely identify messages to the
	 * fabric. The fabric uses this value to ensure that duplicate messages are
	 * not processed
	 */
	private String idempotencyId;
	/**
	 * message continuation guid. This is set to the message GUID of a
	 * previously sent message
	 */
	private String messageContinuationGuid;
	/**
	 * Destination capability's Identifier if the message is to be sent to a
	 * specific capability
	 */
	private String destinationId;
	/**
	 * raw message in bytes
	 */
	private byte[] rawMessage;
	/**
	 * Avro content-type - binary or json
	 */
	private AvroContentType contentType;
	/**
	 * Schema version of the message
	 */
	private String schemaVersion;
	/**
	 * Optional URI where schema is hosted if you are using an experimental
	 * schema
	 */
	private String schemaUri;

	/**
	 * 
	 * @param message
	 * @param contentType
	 *            the encoding to use in sending this message
	 * @throws IOException
	 */
	public XFabricBoundMessage(IndexedRecord message,
			AvroContentType contentType) throws IOException {
		this.contentType = contentType;
		this.rawMessage = AvroEncDecoder.encode(message, contentType);
	}

	public XFabricBoundMessage(String jsonMessage) throws IOException {
		this.contentType = AvroContentType.AVRO_JSON;
		this.rawMessage = jsonMessage.getBytes("utf-8");
	}

	/**
	 * @return message guid provided by XFabric
	 */
	public String getMessageContinuationGuid() {
		return messageContinuationGuid;
	}

	/**
	 * @return raw message in bytes
	 */
	public byte[] getRawMessage() {
		return rawMessage;
	}

	/**
	 * @return the destinationId
	 */
	public String getDestinationId() {
		return destinationId;
	}

	/**
	 * @param destinationId
	 *            the destinationId to set
	 */
	public void setDestinationId(String destinationId) {
		this.destinationId = destinationId;
	}

	/**
	 * @return the idempotencyId
	 */
	public String getIdempotencyId() {
		return idempotencyId;
	}

	/**
	 * @param idempotencyId
	 *            the idempotencyId to set
	 */
	public void setIdempotencyId(String idempotencyId) {
		this.idempotencyId = idempotencyId;
	}

	/**
	 * @return the schemaVersion
	 */
	public String getSchemaVersion() {
		return schemaVersion;
	}

	/**
	 * @param schemaVersion
	 *            the schemaVersion to set
	 */
	public void setSchemaVersion(String schemaVersion) {
		this.schemaVersion = schemaVersion;
	}

	/**
	 * @return the schemaUri
	 */
	public String getSchemaUri() {
		return schemaUri;
	}

	/**
	 * @param schemaUri
	 *            the schemaUri to set
	 */
	public void setSchemaUri(String schemaUri) {
		this.schemaUri = schemaUri;
	}

	/**
	 * @param messageContinuationGuid
	 *            the messageContinuationGuid to set
	 */
	public void setMessageContinuationGuid(String messageContinuationGuid) {
		this.messageContinuationGuid = messageContinuationGuid;
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
	 * 
	 * @param fabricUrl
	 * @param topic
	 * @param token
	 * @return HTTP Response Status Code
	 * @throws KeyManagementException
	 * @throws NoSuchAlgorithmException
	 * @throws IOException
	 */
	public int post(String fabricUrl, String topic, String token)
			throws KeyManagementException, NoSuchAlgorithmException,
			IOException {
		return XFabricMessageHelper.postMessage(fabricUrl + topic, token, this);
	}

}
