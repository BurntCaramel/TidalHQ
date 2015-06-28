Q = require 'q'
http = require 'http'
path = require 'path'
ChannelVideoRetriever = require './ChannelVideoRetriever'
EventEmitter = require('events').EventEmitter


Class = class ChannelVideoChecker extends EventEmitter
	
	checkIntervalTime: 5 * 60 * 1000 # 5 minutes
	
	constructor: (options) ->
		@identifier = options.identifier if options.identifier?
		
		videoRetrieverOptions =
			embedding: options.embedding
		
		if options.YouTubeUsername
			videoRetrieverOptions.username = options.YouTubeUsername
			@videoRetriever = new ChannelVideoRetriever.YouTube videoRetrieverOptions
		else if options.VimeoUsername
			videoRetrieverOptions.username = options.VimeoUsername
			@videoRetriever = new ChannelVideoRetriever.Vimeo videoRetrieverOptions
		
		@foundVideosCallback = options.foundVideosCallback if options.foundVideosCallback?
		@webHooks = options.webHooks if options.webHooks?
		@stateOptions = options.stateOptions if options.stateOptions?
		@checkIntervalTime = options.checkIntervalTime if options.checkIntervalTime?
	
	
	@checkActions = {
		updateEverything: 'update-everything'
		onlyCreateAbsent: 'only-create-absent'
		#delete: 'delete'
	}
	
	
	whiteListCheckAction: (inputCheckAction) ->
		switch inputCheckAction
			when Class.checkActions.updateEverything
				return actionModifier
			else
				return Class.checkActions.onlyCreateAbsent
	
	
	infoForVideoWithURL: (url) ->
		@videoRetriever.infoForVideoWithURL videoURL
	
	
	checkLatestVideos: (action = Class.checkActions.onlyCreateAbsent) ->
		console.log 'Checking for latest videos'
		@lastCheckedDate = new Date()
		
		returningPromise = @videoRetriever.latestVideos()
		
		returningPromise.then (foundVideos) =>
			@sendMessageWithFoundVideos foundVideos, action
		
		returningPromise
	
	
	checkAllVideosInChannel: (action = Class.checkActions.onlyCreateAbsent) ->
		@videoRetriever.totalNumberOfVideos()
		.then (totalNumberOfVideos) =>
			#totalNumberOfVideos = 50
			maximumCount = 10
			remainingCount = totalNumberOfVideos
				
			retrieveVideos = (videosProcessedSoFar) =>
				@videoRetriever.retrieveVideos({
					startIndex: videosProcessedSoFar.length + 1
					maximumCount
				})
				.then (foundVideos) =>
					console.log("RETRIEVE #{foundVideos.length} videos")
					@sendMessageWithFoundVideos foundVideos, action
					Q(videosProcessedSoFar.concat foundVideos)
			
			foundVideosPromise = Q []
			while remainingCount > 0
				console.log "REMAINING #{remainingCount}"
				foundVideosPromise = foundVideosPromise.then retrieveVideos
				remainingCount -= maximumCount
			
			foundVideosPromise
	
	
	sendMessageWithFoundVideos: (foundVideoInfos, action = null, sourceInfo = null) ->
		console.log 'original sendMessageWithFoundVideos'
		@foundVideosCallback? foundVideoInfos, action, sourceInfo
		
		
		message = {
			videoInfos: foundVideoInfos
		}
		
		message.action = action if action?
		message.sourceInfo = sourceInfo if sourceInfo?
		
		console.log 'Notifying web hooks', @webHooks
		for webHook in @webHooks
			@sendPOSTMessageToWebHook message, webHook
	
	
	sendPOSTMessageToWebHook: (message, options) ->
		# In the future: sign with https://github.com/cloudify/node-authhmac
		# Also add the time stamp.
		messageJSONed = JSON.stringify message
		
		#options.hostname = 'www.burntcaramel.com'
		#options.path = '/oceanrafting/wp-mail.php'
		
		console.log 'Send request to web hook', options
		
		request = new http.ClientRequest
			method: 'POST'
			hostname: options.hostname
			port: 80
			path: options.path
			headers:
				'Content-Type': 'application/json'
				'Content-Length': Buffer.byteLength messageJSONed
		
		request.end messageJSONed
		
		#console.log 'Send request to web hook', request
		
		request.on 'response', (response) ->
			console.log 'Web hook sent'
			console.log response.statusCode
			
			data = ''
			
			response.on 'data', (chunk) ->
				data += chunk
		
			response.on 'end', ->
				console.log 'Request returned', data
			
		request.error
	
	
	stateFilePath: (options = {})->
		options.createDirectory ?= false
		
		stateFilePath = null
		
		if @stateOptions
			directoryPath = @stateOptions.folderPath
			fileName = "channel-checker-(#{@identifier}).json"
			stateFilePath = path.join directoryPath, fileName
			
			if options.createDirectory
				fs.mkdirSync directoryPath
		
		stateFilePath
	
	
	readState: ->
		if @stateOptions
			stateFilePath = @stateFilePath()
			
			fs.mkdir folderPath, =>
				fs.readFile stateFilePath, (err, data) =>
					state = JSON.parse data
	
	
	writeState: ->
		if @stateOptions
			state = {}
			state.isAutomaticallyChecking = @isAutomaticallyChecking()
			
			stateFilePath = @stateFilePath createDirectory: true
			
			fs.mkdir folderPath, =>
				fs.writeFile stateFilePath, JSON.stringify state
	
	
	finished: ->
		@writeState()
	
	
	startAutomaticChecking: ->
		return false if @automaticCheckingInterval
		
		@emit 'startCheckingForNewVideos'
		
		@automaticCheckingInterval = setInterval =>
			@checkLatestVideos()
			return
		, @checkIntervalTime
		
		true
	
	
	cancelAutomaticChecking: ->
		return false unless @automaticCheckingInterval
		
		@emit 'cancelCheckingForNewVideos'
		
		clearInterval @automaticCheckingInterval
		@automaticCheckingInterval = null
		
		true
	
	
	isAutomaticallyChecking: ->
		@automaticCheckingInterval?
		


module.exports = ChannelVideoChecker
