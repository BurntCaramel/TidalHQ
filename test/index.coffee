require 'coffee-script/register'
expect = require 'expect.js'
TidalHQ = require '..'
ChannelVideoRetriever = TidalHQ.ChannelVideoRetriever


describe 'TidalHQ', ->
	checkerApp = null
	oceanRaftingChecker  = null
	youTubeVideoRetriever = null
	vimeoVideoRetriever = null
	
	embeddingOptions =
		width: 1000
	
	describe 'gnarcal Video checker', ->
		it 'creating video checker for channel gnarcal', (done) ->
			oceanRaftingChecker = new TidalHQ.ChannelVideoChecker
				identifier: 'Hombre_McSteez'
				YouTubeUsername: 'gnarcal'
				embedding:
					width: 876
					aspectRatio: 16 / 9
				webHooks: []
		
			done()
	
	
	describe 'YouTube video retriever', ->
		@timeout 10 * 1000
		
		it 'creating YouTube video retriever', (done) ->
			youTubeVideoRetriever = new ChannelVideoRetriever.YouTube
				embedding: embeddingOptions
			
			done()
		
		it 'infoForVideoWithURL', (done) ->
			videoURL = 'http://youtube.com/watch?v=98BIu9dpwHU'
			p = youTubeVideoRetriever.infoForVideoWithURL videoURL
			p.then (videoInfo) ->
				expect(videoInfo).to.have.property 'sourceType'
				expect(videoInfo).to.have.property 'videoID'
				expect(videoInfo).to.have.property 'title'
				expect(videoInfo).to.have.property 'originalDimensions'
				console.log 'Info for YouTube URL:', videoURL, '\n', videoInfo
				done()
			return
	
	
	describe 'Vimeo video retriever', ->
		@timeout 10 * 1000
		
		it 'creating Vimeo video checker', (done) ->
			vimeoVideoRetriever = new ChannelVideoRetriever.Vimeo
				embedding: embeddingOptions
			
			done()
		
		it 'infoForVideoWithURL', (done) ->
			videoURL = 'http://vimeo.com/42381325'
			p = vimeoVideoRetriever.infoForVideoWithURL videoURL
			p.then (videoInfo) ->
				expect(videoInfo).to.have.property 'sourceType'
				expect(videoInfo).to.have.property 'videoID'
				expect(videoInfo).to.have.property 'title'
				expect(videoInfo).to.have.property 'originalDimensions'
				console.log 'Info for Vimeo URL:', videoURL, '\n', videoInfo
				done()
			return
	
	
	youTubeTestVideoURL = 'http://youtube.com/watch?v=98BIu9dpwHU'
	vimeoTestVideoURL = 'http://vimeo.com/42381325'
	invalidYouTubeTestURL = 'http://youtube5.com/watch?v=98BIu9dpwHU'
	invalidVimeoTestURL = 'http://vimeo5.com/42381325'
	
	describe 'Work out retriever class for URL', ->
		it "Find class for #{youTubeTestVideoURL}", (done) ->
			Class = ChannelVideoRetriever.ClassForVideoURL youTubeTestVideoURL
			console.log Class.name
			done()
		
		it "Find class for #{vimeoTestVideoURL}", (done) ->
			Class = ChannelVideoRetriever.ClassForVideoURL vimeoTestVideoURL
			console.log Class.name
			done()
	
	
	describe 'Check YouTube class and instance respond to correct URLs', ->
		it "Check YouTube class can work with YouTube URL", (done) ->
			canWorkWith = ChannelVideoRetriever.YouTube.canWorkWithVideoURL youTubeTestVideoURL
			expect(canWorkWith).to.be true
			done()
		
		it "Check YouTube class rejects invalid YouTube URLs", (done) ->
			canWorkWith = ChannelVideoRetriever.YouTube.canWorkWithVideoURL invalidYouTubeTestURL
			expect(canWorkWith).to.be false
			canWorkWith = ChannelVideoRetriever.YouTube.canWorkWithVideoURL vimeoTestVideoURL
			expect(canWorkWith).to.be false
			done()
		
		it "Check YouTube instance can work with YouTube URL", (done) ->
			canWorkWith = youTubeVideoRetriever.canWorkWithVideoURL youTubeTestVideoURL
			expect(canWorkWith).to.be true
			done()
		
		it "Check YouTube instance rejects invalid YouTube URLs", (done) ->
			canWorkWith = youTubeVideoRetriever.canWorkWithVideoURL invalidYouTubeTestURL
			expect(canWorkWith).to.be false
			canWorkWith = youTubeVideoRetriever.canWorkWithVideoURL vimeoTestVideoURL
			expect(canWorkWith).to.be false
			done()
	
	
	describe 'Check Vimeo class and instance respond to correct URLs', ->
		it "Check Vimeo class can work with Vimeo URL", (done) ->
			canWorkWith = ChannelVideoRetriever.Vimeo.canWorkWithVideoURL vimeoTestVideoURL
			expect(canWorkWith).to.be true
			done()
		
		it "Check Vimeo class rejects invalid Vimeo URL", (done) ->
			canWorkWith = ChannelVideoRetriever.Vimeo.canWorkWithVideoURL invalidVimeoTestURL
			expect(canWorkWith).to.be false
			done()
		
		it "Check Vimeo instance can work with Vimeo URL", (done) ->
			canWorkWith = vimeoVideoRetriever.canWorkWithVideoURL vimeoTestVideoURL
			expect(canWorkWith).to.be true
			done()
		
		it "Check Vimeo instance rejects invalid Vimeo URL", (done) ->
			canWorkWith = ChannelVideoRetriever.Vimeo.canWorkWithVideoURL invalidVimeoTestURL
			expect(canWorkWith).to.be false
			done()
		
	
	describe 'ChannelVideoCheckerApp', ->
		it 'creating checkerApp', (done) ->
			checkerApp = new TidalHQ.ChannelVideoCheckerApp()
			expect(checkerApp).to.have.property 'addChannelChecker'
			done()
		
		it 'adding channel checker', (done) ->
			checkerApp.addChannelChecker oceanRaftingChecker
			done()
		
		it 'go', (done) ->
			appOptions = {port: 5001}
			console.log('appOptions', appOptions)
			checkerApp.go(appOptions)
			
			setTimeout ->
				checkerApp.close()
				
				# Wait to close
				setTimeout ->
					done()
				, 500
			, 500 # half a second
