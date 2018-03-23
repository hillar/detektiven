import asyncio
import concurrent.futures
import time
import enhance_file_clamav as _c
import enhance_extract_text_tika_server as _t

#
# Add clamvav and tika results
#
class enhance_file_tika_und_clamav(object):
	def process (self, parameters={}, data={} ):

		def tika(parameters, data, took):
			start = time.time()
			t = _t.enhance_extract_text_tika_server()
			try:
				parameters, data = t.process(parameters, data)
			except Exception as e:
				print(e)
			stop = time.time()
			took['tika'] = {}
			took['tika']['start'] = start
			took['tika']['stop'] = stop
			took['tika']['took'] = stop - start
			return

		def clam(parameters, data, took):
			start = time.time()
			c = _c.enhance_file_clamav()
			try:
				parameters, data = c.process(parameters, data)
			except Exception as e:
				print(e)
			stop = time.time()
			took['clam'] = {}
			took['clam']['start'] = start
			took['clam']['stop'] = stop
			took['clam']['took'] = stop - start
			return

		took = {}
		took['loop'] = {}
		took['loop']['start'] = time.time()
		executor = concurrent.futures.ThreadPoolExecutor()
		loop = asyncio.get_event_loop()
		#loop.run_until_complete(asyncio.gather(tika(parameters,data,took),clam(parameters,data,took)))
		reqs = [loop.run_in_executor(executor,tika,parameters,data,took),loop.run_in_executor(executor,clam,parameters,data,took)]
		loop.run_until_complete(asyncio.wait(reqs))
		loop.close()
		took['loop']['stop'] = time.time()
		took['loop']['took'] = took['loop']['stop'] - took['loop']['start']
		took['sum'] = took['tika']['took'] + took['clam']['took']
		took['gain'] = took['sum'] - took['loop']['took']
		#print(took)
		#print('loop',took['loop']['start'],took['loop']['stop'])
		if took['tika']['start'] < took['clam']['start']:
			took['loop']['pre'] = took['tika']['start'] - took['loop']['start']
			#print('tika',took['tika']['start'],took['tika']['stop'])
			#print('clam',took['clam']['start'],took['clam']['stop'])
			#print(took['clam']['start'] - took['tika']['stop'])

		else:
			took['loop']['pre'] = took['clam']['start'] - took['loop']['start']
			#print('clam',took['clam']['start'],took['clam']['stop'])
			#print('tika',took['tika']['start'],took['tika']['stop'])
			#print(took['tika']['start'] - took['clam']['stop'])
		if took['tika']['stop'] < took['clam']['stop']:
			took['loop']['post'] = took['loop']['stop']-took['clam']['stop']
		else:
			took['loop']['post'] = took['loop']['stop']-took['tika']['stop']
		took['loop']['self'] = took['loop']['pre'] + took['loop']['post']
		took['waste'] = (took['loop']['self'] / took['sum'])*100
		took['speed'] = (took['gain'] / took['loop']['took'])*100
		print('gain:',took['gain'],' speed:',took['speed'],'% waste:',took['waste'],'%')

		if 'verbose' in parameters:
			if parameters['verbose']:
				print('took', took)


		return parameters, data
