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
import java.io.InputStream;
import java.net.URL;
import java.security.SecureRandom;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import org.apache.avro.Schema;

/**
 * @author vichandrasekaran
 * 
 */

public class URLSchemaResolver {
	
	/**
	 * Default TrustManager to relax verification on server certificate.
	 */
	static class RelaxedX509TrustManager implements X509TrustManager {
		public boolean checkClientTrusted(java.security.cert.X509Certificate[] chain) {
			return true;
		}

		public boolean isServerTrusted(java.security.cert.X509Certificate[] chain) {
			return true;
		}

		public java.security.cert.X509Certificate[] getAcceptedIssuers() {
			return null;
		}

		public void checkClientTrusted(java.security.cert.X509Certificate[] chain,
				String authType) {
		}

		public void checkServerTrusted(java.security.cert.X509Certificate[] chain,
				String authType) {
		}
	}	

	private static SSLContext getDefaultSSLContext(boolean trustAll) {
		SSLContext ctx = null;
		try {
			ctx = SSLContext.getInstance("SSL"); // TLS, SSLv3, SSL
			SecureRandom random = SecureRandom.getInstance("SHA1PRNG");
			random.setSeed(System.currentTimeMillis());

			if (trustAll) {
				TrustManager[] tm = { new RelaxedX509TrustManager() };
				ctx.init(null, tm, random);
			} else {
				ctx.init(null, null, random);
			}

		} catch (Exception e) {

		}
		return ctx;
	}

	private HttpsURLConnection connect(URL url) throws IOException {
		HttpsURLConnection httpsConn = (HttpsURLConnection) url
				.openConnection();
		httpsConn.setSSLSocketFactory(getDefaultSSLContext(true)
				.getSocketFactory());

		// XXX: Temporary fix until we get a valid cert
		httpsConn.setHostnameVerifier(new HostnameVerifier() {
			public boolean verify(String hostname, SSLSession session) {
				return true;
			}
		});
		httpsConn.connect();
		return httpsConn;
	}

	public Schema resolve(URL schemaUrl) throws IOException {
		HttpsURLConnection httpsConn = connect(schemaUrl);
		InputStream is = httpsConn.getInputStream();
		Schema.Parser parser = new Schema.Parser();
		Schema s = parser.parse(is);
		//TODO: Do we need to explicitly disconnect?
		httpsConn.disconnect();
		return s;
	}
}
