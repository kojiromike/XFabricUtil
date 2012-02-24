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

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;


public class XFabricMessageHelper {

	private static int HTTP_CONNECTION_TIMEOUT = 3000;
	private static int HTTP_READ_TIMEOUT = 7000;
	private static boolean DISABLE_SSL_CERT_CHECK = true;
	
	/**
	 * Constant for the Authorization header name
	 */
	private static String AUTHORIZATION_HDR = "Authorization";
	/**
	 * Name of the content type header 
	 */
	private static String CONTENTTYPE_HDR = "Content-Type";
	/**
	 * Name of the optional destination header to limit the message 
	 * recipient to a specific capability.
	 */
	private static String DESTINATION_HDR = "X-XC-DESTINATION-ID";
	/**
	 * Name of the optional Message GUID continuation header sent 
	 * to relate this message with a previously sent one
	 */
	private static String MESSAGEGUID_CONTINUATION_HDR = "X-XC-MESSAGE-GUID-CONTINUATION";
	/**
	 * Name of the optional idempotency header sent to the fabric to instruct
	 * it to not process the message if this id has already been processed successfully 
	 */
	private static String MESSAGE_IDEMPOTENCY_HDR = "X-XC-IDEMPOTENCY-ID";	
	/**
	 * Name of the schema version header to be sent to the fabric
	 */
	private static String SCHEMAVERSION_HDR = "X-XC-SCHEMA-VERSION";
	/**
	 * Name of the schema URI header that can be sent to
	 * or received from the fabric
	 */
	private static String SCHEMAURI_HDR = "X-XC-SCHEMA-URI";	
	
	/**
	 * Name of the correlation id that can be sent to or received from the fabric
	 */
	private static String CORRELATIONID_HDR = "X-XC-RESULT-CORRELATION-ID";
	
	public static int postMessage(String topicUrl, String token, XFabricBoundMessage msg)
	throws IOException, NoSuchAlgorithmException, KeyManagementException{
		String responseString = "";
		try {
			if(DISABLE_SSL_CERT_CHECK){
				// Create a trust manager that does not validate certificate chains 
				TrustManager[] trustAllCerts = new TrustManager[] { 
						new X509TrustManager() { 
							public java.security.cert.X509Certificate[] getAcceptedIssuers() { return null; } 
							public void checkClientTrusted( java.security.cert.X509Certificate[] certs, String authType) { } 
							public void checkServerTrusted( java.security.cert.X509Certificate[] certs, String authType) { } 
						} };
				// Install the all-trusting trust manager 
				SSLContext sc = SSLContext.getInstance("TLS");

				sc.init(null, trustAllCerts, new java.security.SecureRandom()); 
				HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory()); 
				HttpsURLConnection.setDefaultHostnameVerifier( new HostnameVerifier(){
					public boolean verify(String string,SSLSession ssls) {
						return true;
					}
				});
			}
			URL url = new URL(topicUrl);
			HttpsURLConnection connection = (HttpsURLConnection ) url.openConnection();
			connection.setDoOutput(true);
			// set timeouts
			connection.setConnectTimeout(HTTP_CONNECTION_TIMEOUT);
			connection.setReadTimeout(HTTP_READ_TIMEOUT);
			// method is always POST
			connection.setRequestMethod("POST");
			// set HTTP headers
			connection.setRequestProperty(AUTHORIZATION_HDR, token);
			// set content type
			connection.setRequestProperty(CONTENTTYPE_HDR, msg.getContentType());
			
			// set other optional headers
			if(msg.getMessageContinuationGuid() != null) {
				connection.setRequestProperty(MESSAGEGUID_CONTINUATION_HDR, msg.getMessageContinuationGuid());				
			}
			if(msg.getDestinationId() != null) {
				connection.setRequestProperty(DESTINATION_HDR, msg.getDestinationId());
			}
			if(msg.getSchemaVersion() != null) {
				connection.setRequestProperty(SCHEMAVERSION_HDR, msg.getSchemaVersion());
			}
			if(msg.getSchemaUri() != null) {
				connection.setRequestProperty(SCHEMAURI_HDR, msg.getSchemaUri());
			}
			if(msg.getIdempotencyId() != null) {
				connection.setRequestProperty(MESSAGE_IDEMPOTENCY_HDR, msg.getIdempotencyId());
			}
			if(msg.getCorrelationId() != null) {
				connection.setRequestProperty(CORRELATIONID_HDR, msg.getCorrelationId());
			}
			
			// write the binary data
			connection.getOutputStream().write(msg.getRawMessage());			

			if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
				String inputLine;
				BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
				while ((inputLine = reader.readLine()) != null) {
					responseString += inputLine;
				}
				reader.close();
			} 
			return connection.getResponseCode();
		} catch (MalformedURLException e) {
			// ...
			throw e;
		} catch (IOException e) {
			// ...
			throw e;
		} catch (NoSuchAlgorithmException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			throw e;
		} 

	}
}	