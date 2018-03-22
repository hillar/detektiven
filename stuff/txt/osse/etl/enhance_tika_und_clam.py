import asyncio
import enhance_file_clamav as _c
import enhance_extract_text_tika_server as _t

#
# Add clamvav and tika results
#
class enhance_file_tika_und_clamav(object):
	def process (self, parameters={}, data={} ):

		async def tika(parameters, data, took):
			start = time.time()
			t = _t.enhance_extract_text_tika_server()
			try:
				parameters, data = t.process(parameters, data)
			except Exception as e:
				print(e)
			stop = time.time()
			took['tika'] = stop - start
			return

		async def clam(parameters, data, took):
			start = time.time()
			c = _c.enhance_file_clamav()
			try:
				parameters, data = c.process(parameters, data)
			except Exception as e:
				print(e)
			stop = time.time()
			took['clam'] = stop - start
			return

		took = {}
		loopStart = time.time()
		loop = asyncio.get_event_loop()
		loop.run_until_complete(asyncio.gather(
			tika(parameters,data,took),
			clam(parameters,data,took)
		))
		loop.close()
		took['loop'] = time.time() - loopStart
		took['sum'] = took['tika'] + took['clam']
		took['gain'] = took['sum'] - took['loop']
		if 'verbose' in parameters:
			if parameters['verbose']:
				print(took)

		return parameters, data
