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

		#get md5 for file
		m = hashlib.md5();
        m.update(open(filename,'rb').read());
        md5 = m.hexdigest()
        data['file_md5'] = md5

		if verbose:
			print ("File md5: {}".format( md5 ))

		return parameters, data
