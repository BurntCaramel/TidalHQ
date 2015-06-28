require 'coffee-script/register'
path = require 'path'


class TidalHQ
	
	@requireClass: (className) ->
		require path.join __dirname, 'lib', className
	
	ChannelVideoCheckerApp: TidalHQ.requireClass 'ChannelVideoCheckerApp'
	
	ChannelVideoChecker: TidalHQ.requireClass 'ChannelVideoChecker'
	
	ChannelVideoRetriever: TidalHQ.requireClass 'ChannelVideoRetriever'


module.exports = new TidalHQ