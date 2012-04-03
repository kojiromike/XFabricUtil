Batch Test Message Generator
=============

Use this ruby script to generate test messages from an AVDL file. This script does two things -
1. Generate schema files for all the topics in the AVDL file
2. Generate JSON test messages for these topics. (If the message generation fails for some reason, a message will be generated)

Important
-------
Right now, to get this script working, you need to copy all the dependent contracts (@import some.avdl) to the root folder where you are running the script. In a future release, I will include a flag to search the Contracts folder, if the script fails to find the avdl file in the home/root folder.

Running the script
-------
	./generate_test_messages <filename.avdl>

Check the sample_avdls folder. I have copied some OCL contracts. You can generate a test message by -

	./generate_test_messages.rb sample_avdls/ProductInformationManagementCapability.avdl
	
This will generate the following output -

	Compiling sample_avdls/ProductInformationManagementCapability.avdl
	Processing ProductInformationManagementCapability.avpr
	attempting to generate message for CreateProduct

	{"products":[{"id":"string","productTypeId":"string","name":[{"locale":{"language":"string","country":"string","variant":"string"},"stringValue":"string"}],"shortDescription":[{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"}],"description":[{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"}],"GTIN":"string","brand":[{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"}],"manufacturer":[{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"}],"MPN":"string","MSRP":{"amount":"string","code":"string"},"MAP":{"amount":"string", "code":"string"},"images":[{"url":"string","height":0,"width":0,"label":{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"},"altText":{"locale":{"language":"string","country":"string","variant":"string"}, "stringValue":"string"}}],"attributes":[{"attributeId":"string","attributeValue":{"value":{"localizedMeasurementValue":[{"locale":{"language":"string", "country":"string", "variant":"string"},"name":"string","unit":"string","value":"string"}]}}}],"variationFactors":["string"],"skuList":[{"sku":"string","productId":"string","MSRP":{"amount":"string", "code":"string"},"MAP":{"amount":"string", "code":"string"},"variationAttributeValues":[{"attributeId":"string", "attributeValue":{"value":{"localizedMeasurementValue":[{"locale":{"language":"string","country":"string","variant":"string"},"name":"string","unit":"string","value":"string"}]}}}],"images":[{"url":"string", "height":0, "width":0, "label":{"locale":{"language":"string","country":"string","variant":"string"},"stringValue":"string"}, "altText":{"locale":{"language":"string","country":"string","variant":"string"},"stringValue":"string"}}]}]}]}


	successfully generated a test message for CreateProduct
	attempting to verify the schema against the contract
	Successfully validated the message against the schema
	
This script does the following things -
	
	1. Compile the AVDL using the included avro tools compiler from the lib directory
	2. Create schemas for all the topics in the AVDL file and write them to out directory
	3. Create JSON messages for all the topics in the AVDL file and write them to the out directory.
	

Output
------------

The files are stored in a directory called 'out'. The script creates a directory called out if it does not exist. You
can also create it yourself.
You can access the X.commerce message contracts from https://github.com/xcommerce/X.commerce-Contracts

Broken?
--------
if something is broken please contact (saranyan@x.com)




