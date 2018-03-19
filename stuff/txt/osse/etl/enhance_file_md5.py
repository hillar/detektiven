#!/usr/bin/python
# -*- coding: utf-8 -*-

import hashlib

#
# Add file md5
#
class enhance_file_md5(object):
	def process (self, parameters={}, data={} ):

		verbose = False
		if 'verbose' in parameters:
			if parameters['verbose']:
				verbose = True

		filename = parameters['filename']
		if 'md5_field_name' in parameters:
			md5_field_name = parameters['md5_field_name']
		else:
			md5_field_name = 'file_md5_s'

		#get md5 for file
		m = hashlib.md5();
		m.update(open(filename,'rb').read());
		md5 = m.hexdigest()
		data[md5_field_name] = md5

		if verbose:
			print ("File md5: {}".format( md5 ))

		return parameters, data
