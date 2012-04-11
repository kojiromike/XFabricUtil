

## XFabricUtil - v0.11.0 ##


	XFabricUtil.jar contains helper classes for sending and receiving messages from the X.commerce fabric.
	
	
### Usage ###


#### Sending a message ####


try {
	// Create a XFabricBoundMessage
	Products productList = new Products(); // Data that you wish to send to fabric		
	XFabricBoundMessage message = new XFabricBoundMessage(productList);
	
	// Set optional properties
	message.setSchemaUri(schemaUri);
	message.setSchemaVersion(schemaVersion);	
	
	// Send the message
	String messageGuid = message.post(fabricUrl, topic, token);	
	
} catch (XFabricHttpException e) {			
  int httpReturnCode = e.getHttpResponseCode(); 
} catch (IOException e) {
  .....
} catch (Exception e) {
  .....
}


#### Receiving a message ####

// In your servlet handler

XFabricMessage message = new XFabricMessage(request);
String topic = message.getTopicName();
String incomingSchemaVersion = message.getSchemaVersion();
URL incomingSchemaUrl = new URL(message.getSchemaURI());

// Retrieve writer schema
Schema writerSchema = SchemaCache.getSchema(topic, incomingSchemaVersion, incomingSchemaUrl);
Products productList = (Products) message.getMessage(writerSchema);

