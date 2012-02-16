==Sample Message Generator

This Ruby script helps to generate sample JSON messages for a given hosted avro schema.

==Why?

Even though the Avro schemas for X.commerce message contracts are written in json format and easy to read, it might still require considerable amount of time to understand the schema and build a sample json message that can be used to construct avro message using the avro libraries. The purpose of this script is to help generating sample messages that help developers understand the data they need to send.

==How?
* Download the files. 
* ./generate_message.rb <schema_url>
	* ./generate_message.rb https://ocl.xcommercecloud.com/inventory/stockItem/updateQuantityFailed/1.0.0

==About the code
This code was written by extending the avro parser written for X.commerce.
Please submit a  pull request if you have any enhancements/improvements/bug fixes.

