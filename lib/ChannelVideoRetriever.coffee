###

Tidal YouTubeChannelVideoRetriever

# YouTube Feed Checker: Coffeescript Node.JS
(iron worker)
checks youtube feeds
caches new youtube feeds
if there's new videos, queue their information
optionally notifies a web hook

# Feed Checker Receiver: PHP
(client)
subscribes to new video queue
creates new posts based on video information, checking first if it already exists

# Schedule Feed Checker: PHP
(client)
get schedule ID for youtube feed worker from ironcache
if schedule ID is not set, present a button
when button is pressed, schedule the youtube feed worker, passing the youtube channel it's interested in, and the queue ID

###


###########
# REQUIRE #
###########

http = require 'http'
url = require 'url'
querystring = require 'querystring'
Q = require 'q'
openGraph = require 'open-graph'
VerEx = require 'verbal-expressions'



###########
# CLASSES #
###########

class ChannelVideoRetriever
	
	constructor: (options = {}) ->
		@channelUsername = options.username if options.username?
		
		options.embedding ?= false
		options.includeDimensions ?= options.embedding isnt false
		options.includeDescription ?= true
		options.includeThumbnail ?= true
		
		@options = options
	
	retrieveVideos: (options = {}) ->
	
	latestVideos: ->
	
	totalNumberOfVideos: ->
	
	
	@canWorkWithVideoURL: (videoURL) ->
		false
	
	canWorkWithVideoURL: (videoURL) ->
		@constructor.canWorkWithVideoURL(videoURL)
	
	
	infoForVideoWithURL: (videoURL, videoInfoOptions) ->
	
	extendVideoInfoOptions: (options) ->
		baseOptions = @options
		
		newOptions = {
			embedding: options.embedding or baseOptions.embedding
			includeDimensions: options.includeDimensions or baseOptions.includeDimensions
			includeDescription: options.includeDescription or baseOptions.includeDescription
			includeThumbnail: options.includeThumbnail or baseOptions.includeThumbnail
		}
		
	
	readJSON: (JSONURL) ->
		console.log 'READ start JSON', JSONURL
		deferred = Q.defer()
		
		http.get(JSONURL, (res) ->
			data = ''
			
			res.on 'data', (chunk) ->
				data += chunk
			
			res.on 'end', ->
				try
					info = JSON.parse(data)
					console.log 'READ done JSON', JSONURL
					deferred.resolve(info)
				catch e
					console.log 'READ done JSON malformed', JSONURL
					deferred.reject('Error parsing JSON')
		).on 'error', (e) ->
			deferred.reject(e)
		
		return deferred.promise



class YouTubeChannelVideoRetriever extends ChannelVideoRetriever
	
	constructor: ->
		super
	
	
	@sourceType: 'YouTube'
	
	
	@youTubeURLRegEx: ->
		re = /https?:\/\/(?:[0-9A-Z-]+\.)?(?:youtu\.be\/|youtube(?:-nocookie)?\.com\S*[^\w\-\s])([\w\-]{11})(?=[^\w\-]|$)(?![?=&+%\w.-]*(?:['"][^<>]*>|<\/a>))[?=&+%\w.-]*/ig
	
	
	@videoIDForURL: (videoURL) ->
		re = @youTubeURLRegEx()
		matches = videoURL.match re
		console.log 'youtube videoIDForURL', matches
		if matches?.length is 1
			return matches[0]
		else
			return null
	
	
	@canWorkWithVideoURL: (videoURL) ->
		re = @youTubeURLRegEx()
		result = re.test(videoURL)
		console.log 'canWorkWithVideoURL', result
		result
	
	
	videoInfosInYouTubeFeedInfo: (youTubeFeedInfo, videoInfoOptions) ->
		feedEntries = youTubeFeedInfo['entry']
		console.log('videoInfosInYouTubeFeedInfo')
		Q.all(@videoInfoForFeedEntry feedEntry, videoInfoOptions for feedEntry in feedEntries)
	
	
	videoInfoForFeedEntry: (feedEntry, videoInfoOptions) ->
		entryURL = feedEntry['id']['$t']
		entryURLComponents = entryURL.split ':'
		videoID = entryURLComponents[ entryURLComponents.length - 1 ]
		URL = "http://www.youtube.com/watch?v=#{videoID}"
		
		#console.log JSON.stringify(feedEntry, null, '\t')
		
		title = feedEntry['title']['$t']
		
		publishedDate = feedEntry['published']['$t']
		updatedDate = feedEntry['updated']['$t']
		
		description = feedEntry['media$group']['media$description']['$t']
		
		thumbnailImageURL = "http://img.youtube.com/vi/#{videoID}/maxresdefault.jpg"
		
		videoInfo = {
			sourceType: YouTubeChannelVideoRetriever.sourceType
			videoID
			URL
			title
			publishedDate
			updatedDate
			description
			thumbnailImageURL 
		}
		
		if videoInfoOptions.includeDimensions or videoInfoOptions.embedding?
			# Get OpenGraph info for the video URL.
			Q.nfcall(openGraph, URL)
			.then (openGraphTags) =>
				width = parseInt(openGraphTags.video.width, 10)
				height = parseInt(openGraphTags.video.height, 10)
				
				videoInfo.originalDimensions = {
					width
					height
				}
				
				# TODO: Extend to work with multiple sizes (e.g. Desktop, Mobile, etc)
				if (embeddingOptions = videoInfoOptions.embedding)
					embeddedWidth = embeddingOptions.width
					if embeddingOptions.aspectRatio
						embeddedHeight = Math.round(embeddedWidth / embeddingOptions.aspectRatio)
					else
						scaleFactor = embeddedWidth / width
						embeddedHeight = Math.round(height * scaleFactor)
					
					embedCode = "<iframe width=\"#{embeddedWidth}\" height=\"#{embeddedHeight}\" src=\"http://www.youtube.com/embed/#{videoID}?wmode=opaque&amp;feature=oembed&amp;showinfo=0&amp;theme=light\" frameborder=\"0\" allowfullscreen></iframe>"
					
					videoInfo.desktopSize = {
						embedCode
						dimensions: {
							width: embeddedWidth
							height: embeddedHeight
						}
					}
				console.log('videoInfo', videoInfo)
				videoInfo
		else
			videoInfo
	
	
	checkIsValid: (options) ->
		if options.channelUsername
			unless @channelUsername?
				throw 'No Channel Username set in this ChannelVideoRetriever, can’t use channel methods.'
	
	
	youTubeChannelFeedURL: (options = {}) ->
		options.startIndex ?= 1
		options.maximumCount ?= 10
		
		"http://gdata.youtube.com/feeds/api/users/#{@channelUsername}/uploads?alt=json&start-index=#{options.startIndex}&max-results=#{options.maximumCount}&v=2"
	
	
	retrieveYouTubeFeed: (options = {}) ->
		@checkIsValid(channelUsername: true)
		
		youTubeFeedURL = @youTubeChannelFeedURL(options)
		
		@readJSON(youTubeFeedURL)
		.then (youTubeWrappedFeedInfo) ->
			youTubeWrappedFeedInfo['feed']
	
	
	retrieveVideos: (options = {}) ->
		@retrieveYouTubeFeed(options)
		.then (youTubeFeedInfo) =>
			videoInfoOptions = @extendVideoInfoOptions(options)
			console.log('!!!!!!')
			@videoInfosInYouTubeFeedInfo(youTubeFeedInfo, videoInfoOptions)
	
	latestVideos: ->
		@retrieveVideos()
	
	totalNumberOfVideos: ->
		@retrieveYouTubeFeed(maximumCount: 0) # Show all total
		.then (youTubeFeedInfo) ->
			Q.fcall ->
				youTubeFeedInfo['openSearch$totalResults']['$t']
		
	
	infoForVideoWithURL: (videoURL, videoInfoOptions = {}) ->
		videoInfoOptions = @extendVideoInfoOptions(videoInfoOptions)
		# Only accepts URLs like: www.youtube.com/watch?v=# 
		videoURLObject = url.parse(videoURL, true)
		videoID = videoURLObject.query['v']
		youTubeVideoFeedURL = "http://gdata.youtube.com/feeds/api/videos/#{videoID}?alt=json&v=2"
		
		@readJSON(youTubeVideoFeedURL)
		.then (videoFeedInfo) =>
			@videoInfoForFeedEntry(videoFeedInfo['entry'], videoInfoOptions)



#! VimeoChannelVideoRetriever

class VimeoChannelVideoRetriever extends ChannelVideoRetriever
	
	constructor: ->
		super
	
	
	@sourceType: 'Vimeo'
	
	
	@vimeoURLRegEx: ->
		digitRE = VerEx().range('0', '9')
		
		nameComponentRE = VerEx()
		.anythingBut(digitRE)
		.anythingBut('/')
		.then('/')
		
		re = VerEx()
		.startOfLine()
		.maybe('http')
		.maybe('s')
		.maybe('://')
		.maybe('www.')
		.then('vimeo.com/')
		.maybe('ondemand/')
		.maybe(nameComponentRE)
		.maybe(nameComponentRE)
		.multiple(digitRE)
		.maybe('/')
		.endOfLine()
		.withAnyCase()
		
		return re
	
	
	@videoIDForURL: (videoURL) ->
		re = @vimeoURLRegEx()
		matches = videoURL.match(re)
		if matches?.length is 1
			return matches[0]
		else
			return null
	
	
	@canWorkWithVideoURL: (videoURL) ->
		re = @vimeoURLRegEx()
		result = re.test(videoURL)
		#console.log 'canWorkWithVideoURL', result, videoURL, re.toString()
		
		result
	
	
	videoInfosInVimeoInfoList: (videoInfoList, videoInfoOptions) ->
		Q.all(@videoInfoForAPIInfo(videoInfo[0], videoInfoOptions) for videoInfo in videoInfoList)
	
	###
	oembedInfoForVideoURL: (videoURL, videoInfoOptions) ->
			
	###
	
	videoInfoForAPIInfo: (videoInfoFromAPI, videoInfoOptions) ->
		#videoInfoFromAPI = apiInfo[0]
		
		# /video or /oembed API
		videoID = videoInfoFromAPI['id'] ? videoInfoFromAPI['video_id']
		
		URL = videoInfoFromAPI['url']
		# /oembed API doesn't provide a URL
		URL ?= "http://www.vimeo.com/#{videoID}"
		
		#console.log JSON.stringify(feedEntry, null, '\t')
		
		title = videoInfoFromAPI['title']
		
		publishedDate = videoInfoFromAPI['upload_date'] ? null
		updatedDate = null
		
		description = videoInfoFromAPI['description']
		
		thumbnailImageURL = videoInfoFromAPI['thumbnail_url'] # /oembed
		thumbnailImageURL ?= videoInfoFromAPI['thumbnail_large'] # /video
		
		videoInfo = {
			sourceType: VimeoChannelVideoRetriever.sourceType
			videoID
			URL
			title
			publishedDate
			updatedDate
			description
			thumbnailImageURL 
		}
		
		
		oEmbedPromise = null
		
		if videoInfoOptions.includeDimensions or videoInfoOptions.embedding?
			width = videoInfoFromAPI['width']
			height = videoInfoFromAPI['height']
			
			videoInfo.originalDimensions = {
				width
				height
			}
			
			# TODO: Extend to work with multiple sizes (e.g. Desktop, Mobile, etc)
			if (embeddingOptions = videoInfoOptions.embedding)?
				embeddedWidth = embeddingOptions.width
				if embeddingOptions.aspectRatio
					embeddedHeight = Math.round(embeddedWidth / embeddingOptions.aspectRatio)
				else
					scaleFactor = embeddedWidth / width
					embeddedHeight = Math.round(height * scaleFactor)
				
				###
				embedCode = "<iframe width=\"#{embeddedWidth}\" height=\"#{embeddedHeight}\" src=\"http://www.youtube.com/embed/#{videoID}?wmode=opaque&feature=oembed&showinfo=0&theme=light\" frameborder=\"0\" allowfullscreen></iframe>"
				###
				
				oembedURL = @vimeoOEmbedURL({
					url: URL
					maxwidth: embeddedWidth
					width: embeddedWidth
					maxheight: embeddedHeight
					byline: false
					title: false
				})
				
				oEmbedPromise = @readJSON oembedURL
				.then (oembedInfo) ->
					videoInfo.desktopSize = {
						embedCode: oembedInfo['html']
						dimensions: {
							width: oembedInfo['width'] or embeddedWidth
							height: oembedInfo['height'] or embeddedHeight
						}
					}
		
					# /oembed has a larger thumbnail for some reason.
					videoInfo.thumbnailImageURL = oembedInfo['thumbnail_url']
		
					videoInfo
		
		
		if oEmbedPromise?
			return oEmbedPromise
		else
			return videoInfo
	
	
	checkIsValid: (options) ->
		if options.channelUsername
			unless @channelUsername?
				throw 'No Channel Username set in this ChannelVideoRetriever, can’t use channel methods.'
	
	
	vimeoUserInfoSectionURL: (options = {}) ->
		@checkIsValid channelUsername: true
		
		options.startIndex ?= 1
		options.maximumCount ?= 10
		options.section ?= 'videos'
		
		"http://vimeo.com/api/v2/#{@channelUsername}/#{options.section}.json?page=#{options.startIndex}"
	
	
	vimeoOEmbedURL: (oembedOptionsQuery = {}) ->
		"http://vimeo.com/api/oembed.json?#{querystring.stringify oembedOptionsQuery}"
	
	
	retrieveUploadsInfo: (options = {}) ->
		vimeoInfoURL = @vimeoUserInfoSectionURL(options)
		
		@readJSON vimeoInfoURL
	
	
	retrieveVideos: (options = {}) ->
		p = @retrieveUploadsInfo(options)
		p.then (videoInfoList) =>
			videoInfoOptions = @extendVideoInfoOptions(options)
			@videoInfosInVimeoInfoList(videoInfoList, videoInfoOptions)
	
	
	latestVideos: ->
		@retrieveVideos()
	
	
	totalNumberOfVideos: ->
		vimeoInfoURL = @vimeoUserInfoSectionURL(section: 'info')
		
		p = @readJSON(vimeoInfoURL)
		p.then (userInfo) ->
			return userInfo['total_videos_uploaded']
		
	
	infoForVideoWithURL: (videoURL, videoInfoOptions = {}) ->
		videoInfoOptions = @extendVideoInfoOptions(videoInfoOptions)
		
		oembedURL = @vimeoOEmbedURL(url: videoURL)
		return @readJSON oembedURL
		.then (oembedInfo) =>
			videoID = oembedInfo['video_id']
			vimeoVideoInfoURL = "http://vimeo.com/api/v2/video/#{videoID}.json"
			return @readJSON vimeoVideoInfoURL
			.then (videoInfoFromAPI) =>
				return @videoInfoForAPIInfo(videoInfoFromAPI[0], videoInfoOptions)
			.fail (error) =>
				console.log('Vimeo /video API error', error)
				return @videoInfoForAPIInfo(oembedInfo, videoInfoOptions)
	


ClassForVideoURL = (videoURL) ->
	if YouTubeChannelVideoRetriever.canWorkWithVideoURL(videoURL)
		return YouTubeChannelVideoRetriever
	else if VimeoChannelVideoRetriever.canWorkWithVideoURL(videoURL)
		return VimeoChannelVideoRetriever
	else
		return null


###########
# EXPORTS #
###########

exports.YouTube = YouTubeChannelVideoRetriever
exports.Vimeo = VimeoChannelVideoRetriever
exports.ClassForVideoURL = ClassForVideoURL
