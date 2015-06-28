// Generated on 2013-11-13 using generator-nodejs 0.0.7
module.exports = function(grunt) {
	grunt.initConfig({
		pkg: grunt.file.readJSON('package.json'),
		coffee: {
			compile: {
				files: {
					'index.js': 'lib/TidalHQ.coffee',
					'test/index.js': 'test/index.coffee'
				}
			}
		},
		complexity: {
			generic: {
				src: ['lib/**/*.js'],
				options: {
					errorsOnly: false,
					cyclometric: 6, // default is 3
					halstead: 16, // default is 8
					maintainability: 100 // default is 100
				}
			}
		},
		jshint: {
			all: [
				'Gruntfile.js',
				'lib/**/*.js',
				'test/**/*.js'
			],
			options: {
				jshintrc: '.jshintrc'
			}
		},
		mochacli: {
			all: ['test/**/*.js'],
			options: {
				reporter: 'spec',
				ui: 'tdd'
			}
		},
		watch: {
			js: {
				files: ['**/*.coffee', '**/*.js', '!node_modules/**/*.js'],
				tasks: ['default'],
				options: {
					nospawn: true
				}
			}
		}
	});

	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.loadNpmTasks('grunt-complexity');
	grunt.loadNpmTasks('grunt-contrib-jshint');
	grunt.loadNpmTasks('grunt-contrib-watch');
	grunt.loadNpmTasks('grunt-mocha-cli');
	grunt.loadNpmTasks('grunt-bump');

	grunt.registerTask('test', ['coffee', 'complexity', 'mochacli', 'watch']);
	grunt.registerTask('ci', ['coffee', 'complexity', 'jshint', 'mochacli']);
	grunt.registerTask('default', ['test']);
};
