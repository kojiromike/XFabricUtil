Batch Test Message Generator
=============

Use this ruby script to generate test messages from an AVDL file. This script does two things -
1. Generate schema files for all the topics in the AVDL file
2. Generate JSON test messages for these topics. (If the message generation fails for some reason, a message will be generated)

Running the script
-------
	./generate_test_messages <filename.avdl>
	
Important
-------
Right now, to get this script working, you need to copy all the dependent contracts (@import some.avdl) to the root folder where you are running the script. In a future release, I will include a flag to search the Contracts folder, if the script fails to find the avdl file in the home/root folder.

Output
------------

The files are stored in a directory called 'out'. The script creates a directory called out if it does not exist. You
can also create it yourself.
You can access the X.commerce message contracts from https://github.com/xcommerce/X.commerce-Contracts

Broken?
--------
if something is broken please contact the author (saranyan@x.com)




