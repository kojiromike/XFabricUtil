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

import java.io.File;
import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import org.apache.avro.Protocol;
import org.apache.avro.Schema;

import com.x.xfabric.helper.avro.URLSchemaResolver;

/**
 * @author vichandrasekaran
 * 
 * Container for caching avro schema definitions. 
 * Provides utility methods for 
 *    loading the cache from avpr files/schema URL and 
 *    for retrieving schema objects from the local cache
 */
public class SchemaCache {

	static class SchemaDescriptor {

		private String topic;
		private String version;

		public SchemaDescriptor(String topic, String version) {
			this.topic = topic;
			this.version = version;
		}

		@Override
		public boolean equals(Object object) {
			if (!(object instanceof SchemaDescriptor))
				return false;
			SchemaDescriptor desc = (SchemaDescriptor) object;
			return desc != null && this.topic.equals(desc.topic)
					&& this.version.equals(desc.version);
		}

		@Override
		public int hashCode() {
			final int multiplier = 23;
			int code = 133;
			code = multiplier * code + topic.hashCode();
			code = multiplier * code + version.hashCode();
			return code;
		}

		@Override
		public String toString() {
			return new StringBuilder().append(topic).append("/")
					.append(version).toString();
		}
	}

	private static Map<SchemaDescriptor, Schema> cache = new HashMap<SchemaDescriptor, Schema>();

	/**
	 * Add schema definitions from the passed in avpr files
	 * to the local cache
	 * 
	 * @param avprFiles
	 * @throws IOException
	 * @throws URISyntaxException
	 */
	public static void loadSchema(List<String> avprFiles) throws IOException,
			URISyntaxException {
		Iterator<String> iter = avprFiles.iterator();
		while (iter.hasNext()) {
			String avprLocation = iter.next();
			loadSchema(avprLocation);
		}
	}

	/**
	 * Add schema definitions from the passed in avpr file
	 * to the local cache 
	 * 
	 * @param avprLocation
	 * @throws IOException
	 * @throws URISyntaxException
	 */
	public static void loadSchema(String avprLocation) throws IOException,
			URISyntaxException {
		Protocol protocol = Protocol.parse(new File(avprLocation));
		Iterator<Schema> schemaIterator = protocol.getTypes().iterator();
		while (schemaIterator.hasNext()) {
			Schema s = schemaIterator.next();
			if (s.getProp("topic") != null && s.getProp("version") != null) {
				SchemaCache.SchemaDescriptor desc = new SchemaCache.SchemaDescriptor(
						s.getProp("topic"), s.getProp("version"));
				cache.put(desc, s);
			}
		}
	}

	/**
	 * Retrieve schema definition for the give topic and version
	 * If a local definition is not available, fetches schema
	 * from the schemaUrl and adds it to the local cache.
	 * 
	 * @param topic
	 * @param version
	 * @param schemaUrl
	 * @return schema object for the given topic/version
	 * @throws IOException
	 */
	public static Schema getSchema(String topic, String version, URL schemaUrl)
			throws IOException {
		SchemaDescriptor desc = new SchemaDescriptor(topic, version);
		if (cache.containsKey(desc)) {
			return cache.get(desc);
		} else if (schemaUrl != null) {
			URLSchemaResolver resolver = new URLSchemaResolver();
			Schema s = resolver.resolve(schemaUrl);
			if (s != null) {
				cache.put(desc, s);
				return s;
			}
		}
		return null;
	}

	public static Schema getSchema(String topic, String version) throws IOException {
		return getSchema(topic, version, null);
	}
}
