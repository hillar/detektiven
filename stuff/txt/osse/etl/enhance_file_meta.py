import os
import json
import etl

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
			try:
				meta = json.loads(open(metafile).read())
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
