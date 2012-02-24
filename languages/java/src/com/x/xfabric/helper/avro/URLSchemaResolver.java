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
import java.net.HttpURLConnection;


import org.apache.avro.Schema;

/**
 * @author vichandrasekaran
 * 
 */

public class URLSchemaResolver {
	
	public static int HTTP_CONNECTION_TIMEOUT = 3000;
	public static int HTTP_READ_TIMEOUT = 7000;
	
	public Schema resolve(URL schemaUrl) throws IOException{
            try {
                    HttpURLConnection connection = 
						(HttpURLConnection) schemaUrl.openConnection();
                    connection.setDoOutput(true);
                    // set timeouts
                    connection.setConnectTimeout(HTTP_CONNECTION_TIMEOUT);
                    connection.setReadTimeout(HTTP_READ_TIMEOUT);
                    connection.connect();
                    InputStream is = connection.getInputStream();
            		Schema.Parser parser = new Schema.Parser();
            		Schema s = parser.parse(is);
            		//TODO: Do we need to explicitly disconnect?
            		connection.disconnect();
            		return s;
            }catch (Exception ex){
            	ex.printStackTrace();
            }
            return null;
    }

}
