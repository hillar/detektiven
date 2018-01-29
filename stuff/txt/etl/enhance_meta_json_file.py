import os
import json
import etl

class enhance_meta_json_file(object):

	# this plugin needs some config changes:
	# config['meta_json_file'] = 'meta.sjon'
	# config['plugins'].append('enhance_meta_json_file')
	# and 
	# cp enhance_meta_json_file.py /usr/lib/python3/dist-packages/opensemanticetl/
	
	def process (self, parameters={}, data={} ):
	
		verbose = False
		if 'verbose' in parameters:
			if parameters['verbose']:	
				verbose = True
				
		if 'meta_json_file' in parameters:
			meta_json_file = parameters['meta_json_file']
		else:
			if verbose:
				print('meta_json_file not defined in config, please add config[\'meta_json_file\'] = \'meta.json\'')
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
