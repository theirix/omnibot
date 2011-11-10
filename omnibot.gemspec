require 'bundler'

Gem::Specification.new do |s| 
  s.name         = "omnibot"
  s.summary      = "Simple XMPP bot for server monitoring"
  s.description  = "Works with AMQP for sending messages at server side."+
    "Sends notifications to an user via XMPP."+
    "Can monitor system by performing daily commands."
  s.requirements = 
      [ 'AMQP-compatible server (for example, RabbitMQ)' ]

	require File.join(File.dirname(__FILE__),"lib/#{s.name}/version.rb")
  s.version     = OmniBot::VERSION
  s.author      = "theirix"
  s.email       = "theirix@gmail.com"
  s.homepage    = "http://github.com/theirix/omnibot"
  s.platform    = Gem::Platform::RUBY
	s.files 			= Dir.glob("{examples,lib}/**/*") + ['Rakefile', 'README.md']
  s.executables = Dir.glob('bin/*').map { |executable| File.basename executable } 
  s.test_files  = []
  s.has_rdoc    = false
  s.required_ruby_version = '>=1.9'
	s.rubyforge_project = 'nowarning'

	%w[ xmpp4r eventmachine mail sqlite3 ].each do |dep|
		s.add_dependency(dep)
	end
	s.add_dependency('amqp', '>= 0.8.0')
end
