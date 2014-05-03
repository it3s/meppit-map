module.exports = function(grunt) {
  'use strict';

  grunt.initConfig({

    pkg: grunt.file.readJSON('package.json'),
    banner: '/*!\n' +
      '* <%= pkg.name %>\n' +
      '* v<%= pkg.version %> - ' +
      '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
      '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
      '* (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
      ' <%= _.pluck(pkg.licenses, "type").join(", ") %> License\n' +
      '*/\n\n',

    concat: {
      options: {
        separator: "\n",
      },
      full_js: {
        src: [
          'dist/<%= pkg.name.replace(".js", "") %>.js',
          'lib/leaflet.js',
          'lib/leaflet.draw.js',
          'lib/TileLayer.GeoJSON.js'
        ],
        dest: 'dist/<%= pkg.name.replace(".js", "") %>.full.js'
      },
      full_css: {
        src: [
          'lib/leaflet.css',
          'lib/leaflet.draw.css'
        ],
        dest: 'dist/<%= pkg.name.replace(".js", "") %>.full.css'
      }
    },

    uglify: {
      options: {
        sourceMap: true,
        sourceMapIncludeSources: true,
        sourceMapIn: 'dist/<%= pkg.name.replace(".js", "") %>.js.map'
      },
      dist: {
        files: {
          'dist/<%= pkg.name.replace(".js", "") %>.min.js':
            [ 'dist/<%= pkg.name.replace(".js", "") %>.js']
        }
      },
      full: {
        files: {
          'dist/<%= pkg.name.replace(".js", "") %>.full.min.js':
            ['<%= concat.full_js.dest %>']
        }
      }
    },

    jshint: {
      all: {
        options: {
          globals: {
            console: true,
            module: true,
            document: true
          },
          jshintrc: '.jshintrc'
        },
        files: {
          src: [
            'Gruntfile.js',
            'src/**/*.js',
            'spec/**/*.js'
          ]
        }
      }
    },

    blanket_mocha: {
      spec: {
        options: {
          threshold : 90,
          globalThreshold : 95,
          log : true,
          logErrors: true,
          moduleThreshold : 95,
          modulePattern : ".*/(.*?)"
        },
        src: ['spec/test.html']
      }
    },

    coffee: {
      dist: {
        options: {
          sourceMap: true
        },
        files: {
          'dist/<%= pkg.name.replace(".js", "") %>.js':
            ['src/main.coffee', 'src/**/*.coffee']
        }
      },
      spec: {
        options: {
          bare: true,
        },
        expand: true,
        flatten: true,
        cwd: 'spec',
        src: ['**/*.coffee'],
        dest: 'spec',
        ext: '.js'
      }
    },

    watch: {
      files: [
        'Gruntfile.js',
        'src/**/*.coffee',
        'spec/**/*.coffee'
      ],
      tasks: ['spec']
    }

  });

  grunt.registerTask('replace-version',
        'replace the version placeholder in backbone.leaflet.js', function() {
    var pkg = grunt.config.get('pkg'),
        filename = 'dist/' + pkg.name + '.js',
        content = grunt.file.read(filename),
        rendered = grunt.template.process(content, { pkg : pkg });
    grunt.file.write(filename, rendered);
  });

  // On watch events, if the changed file is a test file then configure
  // mochaTest to only run the tests from that file. Otherwise run all
  // the tests
  var defaultTestSrc = grunt.config('mochaTest.test.src');
  grunt.event.on('watch', function(action, filepath) {
    grunt.config('mochaTest.test.src', defaultTestSrc);
    if (filepath.match('test/')) {
      grunt.config('mochaTest.test.src', filepath);
    }
  });

  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-blanket-mocha');

  grunt.registerTask('compile', ['coffee', 'replace-version']);
  grunt.registerTask('build', ['compile', 'concat', 'uglify']);
  grunt.registerTask('spec', ['compile', 'blanket_mocha']);
  grunt.registerTask('test', ['spec']);
  grunt.registerTask('default', ['spec', 'watch']);

};
