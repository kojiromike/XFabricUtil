#!/usr/bin/env python
# encoding: utf-8
"""
generate_test_messages.py

Created by Michael Smith on 2012-03-29.
Copyright (c) 2012 True Action Network. All rights reserved.
"""
from __future__ import with_statement
from avro import protocol, schema
from StringIO import StringIO
from json import dumps
from os import mkdir
from os.path import isdir
from glob import glob
from shutil import move

def generate_json_test_message(schema_str):
	contents = schema_str
	try:
		sch = schema.parse(contents)
	except schema.SchemaParseException:
		import pdb; pdb.set_trace()

	if ('null' == sch.type):
		return None
	elif ('boolean' == sch.type):
		return False
	elif (sch.type in ('int', 'long',)):
		return 0
	elif (sch.type in ('float', 'double',)):
		return 0.0
	elif ('bytes' == sch.type):
		return '\u00FF'
	elif ('string' == sch.type):
		return 'string'
	elif ('record' == sch.type):
		msg_hash = {}
		for field in sch.fields:
			msg_hash[field.name] = generate_json_test_message(str(field.type))
		return msg_hash
	elif ('enum' == sch.type):
		return sch.symbols[0]
	elif ('array' == sch.type):
		return [generate_json_test_message(str(sch.items))]
	elif ('map' == sch.type):
		raise Exception('not implemented')
	elif ('union' == sch.type):
		return generate_json_test_message(str(sch.schemas[-1]))
	elif ('fixed' == sch.type):
		return 'n' * sch.size

def write_type(buf, sch, delim, written, namespace=None):
	if delim: buf.write(delim)
	if 'union' == sch.type:
		buf.write('[')
		delim = ''
		nullable = False
		for subschema in sch.schemas:
			nullable = nullable or ('null' == subschema.type)
			write_type(buf, subschema, delim, written)
			delim = ','
		buf.write(']')
		if nullable:
			buf.write(',"default":null')
	elif 'record' == sch.type:
		if sch.name not in written:
			written.add(sch.name)
			buf.write('''{"type":"record","name":"%s"''' % sch.name)
			if 'version' in sch.props: buf.write(''',"version":"%s"''' % sch.props['version'])
			if sch.namespace: namespace = sch.namespace
			if namespace: buf.write(''',"namespace":"%s"''' % namespace)
			buf.write(''',"fields":[''')
			delim = ''
			for field in sch.fields:
				buf.write(delim)
				buf.write('''{"name":"%s","type":''' % field.name)
				write_type(buf, field.type, '', written)
				buf.write('}')
				delim = ','
			buf.write("]}")
		else:
			buf.write('''"''')
			if sch.namespace: buf.write(sch.namespace + '.')
			buf.write('''%s"''' % sch.name)
	elif 'array' == sch.type:
		buf.write('''{"type":"array","items":''')
		write_type(buf, sch.items, '', written)
		buf.write("}")
	else:
		json = str(sch)
		buf.write(json)

def main():
	x_proto = protocol.parse(open('Order.avpr', 'r').read())
	for the_type in x_proto.types:
		if 'record' == the_type.type:
			buf = StringIO()
			written = set([])
			namespace = the_type.namespace or x_proto.namespace
			file_name = namespace + '.' + the_type.name + '.avsc'
			write_type(buf, the_type, '', written, namespace)
			buf.seek(0)
			assert namespace + '.' + the_type.name + '.avsc' == file_name
			with open(file_name, 'w') as out:
				out.write(buf.read())
			with open(file_name, 'rb') as out:
				with open(namespace + '.' + the_type.name + '.json', 'w') as msg_file:
					msg = generate_json_test_message(out.read())
					msg_file.write(dumps(msg))
					if msg:
						print "Successfully generated a test message for %s." % the_type.name
					else:
						print "Could not generate a test message for %s." % the_type.name
	if not isdir('out'): mkdir('out')
	for filename in glob('*.avsc') + glob('*.json'):
		print filename
		move(filename, 'out/')

if '__main__' == __name__:
	main()
