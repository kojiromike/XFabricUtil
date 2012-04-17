#!/usr/bin/env python
# encoding: utf-8
"""
generate_test_messages.py

Created by Michael Smith on 2012-03-29.
Copyright (c) 2012 True Action Network. All rights reserved.
"""
from __future__ import with_statement
from avro import protocol
from glob import glob
from json import dumps, loads
from os import makedirs
from os.path import isdir, isfile, join

primitive_type_map = {
	'null': None,
	'boolean': False,
	'int': 0,
	'long': 0,
	'float': 0.0,
	'double': 0.0,
	'bytes': '\u00FF',
	'string': 'string',
}

class RecursiveSchemaError(Exception):
	"""Cannot interpret recursive schema '%s'"""
	def __init__(self, val):
		self.val = val
	def __str__(self):
		return self.__doc__ % self.val

def generate_json_test_message(sch, parent_name=''):
	if hasattr(sch, 'name') and sch.name == parent_name:
		raise RecursiveSchemaError(parent_name)
	if sch.type in primitive_type_map:
		return primitive_type_map[sch.type]
	elif ('enum' == sch.type):
		return sch.symbols[0]
	elif ('array' == sch.type):
		return [generate_json_test_message(sch.items, parent_name)]
	elif ('map' == sch.type):
		raise NotImplementedError('Cannot interpret map schema yet.')
	elif ('union' == sch.type):
		return generate_json_test_message(sch.schemas[-1])
	elif ('fixed' == sch.type):
		return 'n' * sch.size
	elif ('record' == sch.type):
		msg_hash = {}
		for field in sch.fields:
			msg_hash[field.name] = generate_json_test_message(field.type, sch.name)
		return msg_hash

def get_name_to_topic_map(avpr_string):
	"""Walk through the types in an avpr json file and create a map between names and topics"""
	res = {}
	for t in loads(avpr_string)['types']:
		if 'topic' in t and 'name' in t:
			res[t['name']] = t['topic']
	return res

def process(a_file, output_dir='out'):
	avpr_str = open(a_file, 'rb').read()
	name_topic_map = get_name_to_topic_map(avpr_str)
	x_proto = protocol.parse(avpr_str)
	for the_type in x_proto.types:
		if the_type.name in name_topic_map:
			topic = name_topic_map[the_type.name]
			try:
				msg = generate_json_test_message(the_type)
				if msg:
					print "Successfully generated a test message for %s." % topic
					target = join(output_dir, topic.strip('/'))
					try:
						makedirs(target)
					except OSError:
						pass
					filename = join(target, 'index.json')
					open(filename, 'w').write(dumps(msg))
				else:
					raise NotImplementedError
			except Exception, e:
				print "Could not generate a test message for %s. (%s)" % (topic, e.message)

def main(argv):
	if len(argv) >= 1:
		for arg in argv[1:]:
			if isfile(arg) and arg.endswith('.avpr'):
				process(arg)
			elif isdir(arg):
				main(glob(arg + '/*.avpr'))
	else:
		raise Exception("Please list an avpr file or directory of files with topics.")

if '__main__' == __name__:
	from sys import argv
	main(argv)
