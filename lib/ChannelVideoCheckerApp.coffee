express = require 'express'
moment = require 'moment'
http = require 'http'
EventEmitter = require('events').EventEmitter
_ = require 'underscore'
ChannelVideoRetriever = require './ChannelVideoRetriever'
ChannelVideoChecker = require './ChannelVideoChecker'


class ChannelVideoCheckerApp extends EventEmitter
	
	_port: 5000
	
	constructor: (options) ->
		@dateLaunched = new Date()
		
		@port(process.env.PORT)
		
		@youTubeVideoRetriever = new ChannelVideoRetriever.YouTube
		@vimeoVideoRetriever = new ChannelVideoRetriever.Vimeo
			
	
	addChannelChecker: (channelChecker, id = null) ->
		@idToChannelCheckers ?= {}
		
		unless id? then id = channelChecker.identifier
		@idToChannelCheckers[id] = channelChecker
		return
	
	
	channelCheckerWithID: (checkerID) ->
		return @idToChannelCheckers[checkerID]

		
	checkerActionForRequest: (req) ->
		return req.query['action']
	
	
	startAutomaticChecking: ->
		for own checkerID, channelChecker of @idToChannelCheckers
			channelChecker.startAutomaticChecking()
		return
	
	
	cancelAutomaticChecking: ->
		for own checkerID, channelChecker of @idToChannelCheckers
			channelChecker.cancelAutomaticChecking()
		return
	
	
	channelCheckerWithIDIsChecking: (id, change = null) ->
		@idToChannelCheckersThatAreChecking ?= {}
		if change?
			@idToChannelCheckersThatAreChecking[id] = change
			return
		else
			return @idToChannelCheckersThatAreChecking[id]
	
	
	port: (inputPort) ->
		port = parseInt(inputPort ? 0)
		@_port = port unless port is 0 or isNaN(port)
		
		return @_port
	
	
	runExpressApp: (options = {}) ->
		if options.port?
			@port(options.port)
		
		port = @_port
		console.log "LOG Using for express, port number #{port}"
		
		@expressApp = express()
		@setUpExpressAppRoutes()
		
		@emit('setUpExpress', @expressApp)
		
		@expressApp.on 'close', =>
			for own checkerID, channelChecker of @idToChannelCheckers
				channelChecker.finished()
			return
		
		@startAutomaticChecking() if options.startAutomaticChecking
		
		@server = @expressApp.listen(port)
		
		return
	
	
	setUpExpressAppRoutes: ->
		expressApp = @expressApp
		
		# /info/video-url/:videoURL
		expressApp.get '/info/video-url/:videoURL', (req, res) =>			
			videoURL = req.params['videoURL']
			
			videoInfoOptions = {}
			
			embeddingOptions = {}
			embeddingMaxWidth = req.query['max-width']
			embeddingOptions.width = parseInt(embeddingMaxWidth, 10) if embeddingMaxWidth?
			unless _.isEmpty embeddingOptions
				videoInfoOptions.embedding = embeddingOptions
			
			
			if @vimeoVideoRetriever.canWorkWithVideoURL(videoURL)
				videoRetriever = @vimeoVideoRetriever
			else if @youTubeVideoRetriever.canWorkWithVideoURL(videoURL)
				videoRetriever = @youTubeVideoRetriever
			else
				res.send 501, {
					URL: videoURL
					error: 'URL is unknown: no video retrievers can work with it.'
				}
				return
			
			videoRetriever.infoForVideoWithURL(videoURL, videoInfoOptions)
			.then (videoInfo) ->
				res.send videoInfo
			.catch (error) ->
				res.send 404, {
					URL: videoURL
					error
				}
			
			return
		
		
		expressApp.get '/thumbnail-image/:originalImageURL', (req, res, next) =>
			originalImageURL = req.params['originalImageURL']
			
			console.log("REQUESTING #{originalImageURL}")
			
			http.get originalImageURL, (sourceResponse) =>
				copiedHeaders = _.pick(sourceResponse.headers, 'content-length', 'content-type', 'expires', 'cache-control')
				res.writeHeader(sourceResponse.statusCode, copiedHeaders)
				
				sourceResponse.pipe(res)
				
			return
				
		
		
		expressApp.param 'checkerID', (req, res, next, checkerID) =>
			channelChecker = @channelCheckerWithID(checkerID)
			if channelChecker?
				req.channelChecker = channelChecker
				next()
			else
				next(new Error('No channel checker found with requested id.'))
				
			return
		
		
		# /:checkerID/list/latest-videos
		expressApp.get '/:checkerID/list/latest-videos', (req, res) =>
			checker = req.channelChecker
			
			p = checker.latestVideos()
			p.then (videoInfos) ->
				res.send videoInfos
			.catch (error) ->
				res.send 500, {error}
		
		
		# /:checkerID/check/latest-videos
		expressApp.get '/:checkerID/check/latest-videos', (req, res) =>
			checker = req.channelChecker
			action = @checkerActionForRequest req
			
			p = checker.checkLatestVideos action
			p.then (processedVideos) ->
				res.json processedVideos
			.catch (error) ->
				res.send 500, {error}
		
		
		# /:checkerID/check/all-videos
		expressApp.get '/:checkerID/check/all-videos', (req, res) =>
			checker = req.channelChecker
			action = @checkerActionForRequest req
			
			p = checker.checkAllVideosInChannel action
			p.then (processedVideos) ->
				res.json "Found #{processedVideos.length} videos."
				res.json processedVideos
			.catch (error) ->
				res.send 500, {error}
		
		
		# /:checkerID/check/video-url/:videoURL
		expressApp.get '/:checkerID/check/video-url/:videoURL', (req, res) =>
			checker = req.channelChecker
			
			videoURL = req.params['videoURL']
			sourceInfo = req.query['sourceInfo']
			
			p = checker.infoForVideoWithURL videoURL
			p.then (videoInfo) ->
				@sendMessageWithFoundVideos videoInfo, sourceInfo
			.catch (error) ->
				res.send 500, {error}
		
		
		# /:checkerID/automatic-check/start
		expressApp.get '/:checkerID/automatic-checking/start', (req, res) =>
			checker = req.channelChecker
			
			# @channelCheckerWithIDIsChecking
			
			started = checker.startAutomaticChecking()
			if started
				res.send "Started checking #{checkerID} for new videos."
			else
				res.send "Already checking #{checkerID} for new videos."
		
		
		# /:checkerID/automatic-check/cancel
		expressApp.get '/:checkerID/automatic-checking/cancel', (req, res) =>
			checker = req.channelChecker
			
			canceled = checker.cancelAutomaticChecking()
			if canceled
				res.send "Cancelled checking #{checkerID} for new videos."
			else
				res.send "Already stopped checking #{checkerID} for new videos."
		
		
		# /:checkerID/automatic-check
		expressApp.get '/:checkerID/automatic-checking', (req, res) =>
			checker = req.channelChecker
			
			isCheckingForNewVideos = checker.isAutomaticallyChecking()
			
			lastCheckedMoment = moment checker.lastCheckedDate
			launchedMoment = moment @dateLaunched
			
			res.send """
				Is #{checkerID} automatically checking? #{if isCheckingForNewVideos then 'y' else 'n'}
				Last checked #{lastCheckedMoment.fromNow()}, on #{lastCheckedMoment.format()}
				App started at #{launchedMoment.fromNow()}, on #{launchedMoment.format()}
				"""
		
		expressApp.use (req, res, next) =>
			@responseSendCallback?(req, res)
			next()
		
	
	
	go: (options = {}) ->
		process.on 'uncaughtException', (error, p) ->
			console.error error
			console.error error.stack
			throw error
		
		console.log('Go with options', options)
		
		if options.responseSendCallback?
			@responseSendCallback = options.responseSendCallback
		
		
		console.log('PROCESSSSSSSS')
		console.log(process.argv)
		
		if process.argv?[2] is 'check-all-and-update'
			console.log('CHECKING ALL')
			checkerID = process.argv[3]
			checker = @channelCheckerWithID(checkerID)
			p = checker.checkAllVideosInChannel('update-everything')
		else
			@runExpressApp(options)
		
		return
	
	
	close: ->
		unless @server? then return
		
		@server.close()
		@server = null
		
		return


module.exports = ChannelVideoCheckerApp
