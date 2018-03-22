import asyncio
import enhance_file_clamav as _c
import enhance_extract_text_tika_server as _t

#
# Add clamvav and tika results
#
class enhance_file_tika_und_clamav(object):
	def process (self, parameters={}, data={} ):

		async def tika(parameters, data):
			t = _t.enhance_extract_text_tika_server()
			try:
				parameters, data = t.process(parameters, data)
			except Exception as e:
				print(e)
			return

		async def clam(parameters, data):
			c = _c.enhance_file_clamav()
			try:
				parameters, data = c.process(parameters, data)
			except Exception as e:
				print(e)
			return

		loop = asyncio.get_event_loop()
		loop.run_until_complete(asyncio.gather(
			tika(parameters,data),
			clam(parameters,data)
		))
		loop.close()

		return parameters, data
