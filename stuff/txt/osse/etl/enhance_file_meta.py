#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
import json
import etl
import zipfile
import lzma

class enhance_file_meta(object):

	# this plugin needs some config changes:
	# config['enhance_file_meta_filename'] = 'meta.sjon'
	# config['plugins'].append('enhance_file_meta')
	# and
	# cp enhance_meta_json_file.py /usr/lib/python3/dist-packages/opensemanticetl/

	def process (self, parameters={}, data={} ):

		verbose = False
		if 'verbose' in parameters:
			if parameters['verbose']:
				verbose = True

		if 'enhance_file_meta_filename' in parameters:
			meta_json_file = parameters['enhance_file_meta_filename']
		else:
			if verbose:
				print('enhance_file_meta_filename not defined in config, please add config[\'enhance_file_meta_filename\'] = \'meta.json\'')
			return parameters, data

		id = parameters['id']
		if 'container' in parameters:
			id = parameters['container']
		id = id.replace('file://', '', 1)
		directory = os.path.dirname(id)
		metafile = directory + '/' + meta_json_file
		meta = {}

		if os.path.isfile(metafile):
			if zipfile.is_zipfile(metafile):
				if verbose:
					print('is zipfile:' + metafile)
				with ZipFile(metafile) as myzip:
					fn = myzip.namelist()
					with myzip.open(fn[0]) as myfile:
						tmp = myfile.read()
			else:
				if metafile.endswith('.xz'):
					if verbose:
						print('is XZ file:' + metafile)
					tmp = lzma.open(metafile, mode='rt', encoding='utf-8').read()
				else:
					if verbose:
						print('not zip nor xz:' + metafile)
					tmp = open(metafile).read()
			try:
				meta = json.loads(tmp)
			except Exception as e:
				print('Exception loading ' + metafile + ' error' + e)
			else:
				#data.update(meta)
				for k in meta:
					etl.append(data, k, meta[k])
				if verbose:
					print('meta file:' + metafile)
					print('meta:' + json.dumps(meta))
		else:
			if verbose:
				print('file does not exist ' + metafile)

		return parameters, data
