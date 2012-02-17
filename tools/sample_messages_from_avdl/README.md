Batch Test Message Generator
=============

Use this ruby script to generate test messages from an AVDL file. This script does two things -
1. Generate schema files for all the topics in the AVDL file
2. Generate JSON test messages for these topics. (If the message generation fails for some reason, a message will be generated)

Running the script
-------
	./generate_test_messages <filename.avdl>

Output
------------

The files are stored in a directory called 'out'
You can access the X.commerce message contracts from https://github.com/xcommerce/X.commerce-Contracts

Contributing
------------

1. Fork it.
2. Commit your changes (`git commit -am "Added Snarkdown"`)
4. Submit pull request




