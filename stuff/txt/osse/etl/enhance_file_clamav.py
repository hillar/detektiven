#!/usr/bin/python
# -*- coding: utf-8 -*-

import pyclamd

#
# Add clamvav results
#
class enhance_file_clamav(object):
	def process (self, parameters={}, data={} ):

		verbose = False
		if 'verbose' in parameters:
			if parameters['verbose']:
				verbose = True

		filename = parameters['filename']

		if 'clamd_host' in parameters:
			host = parameters['clamd_host']
		else:
			host = '127.0.0.1'
		if 'clamd_port' in parameters:
			port = parameters['clamd_port']
		else:
			port = 3310
		if 'clamd_timeout' in parameters:
			timeout = parameters['clamd_timeout']
		else:
			timeout = None

		#get clamd result
		try:
			cd = pyclamd.ClamdNetworkSocket(host, port, timeout)
		except pyclamd.ConnectionError as e:
			print('Exception connecting to ' + host+':' + str(port)+ ' error' + str(e))
			return parameters, data
		if verbose:
			print(host+':' + str(port) +' '+cd.version().split()[0])

		try:
			r = cd.scan_stream(open(filename,'rb',buffering=0))
		except Exception as e:
			print('Exception CLAMAV scanning ' + host+':' + str(port)+' file '+ filename + ' error' + str(e))
			return parameters, data
		if r != None:
			# see https://bitbucket.org/xael/pyclamd/src/2089daa540e1343cf414c4728f1322c96a615898/pyclamd/pyclamd.py?at=default&fileviewer=file-view-default#pyclamd.py-593
			status, reason = r['stream']
			if status == 'FOUND':
				data['clam_s'] = reason
			else:
				print('ERROR CLAMAV scanning ' + host+':' + str(port)+' file '+ filename + ' status ' + status + ' reason ' + reason)

			if verbose:
				print ("ClamAV: {}".format( data['clam_s'] ))

		return parameters, data
