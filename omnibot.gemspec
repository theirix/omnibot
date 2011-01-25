Gem::Specification.new do |s| 
  s.name         = "omnibot"
  s.summary      = "Simple XMPP bot for server monitoring"
  s.description  = "Works with AMQP for sending messages at server side."+
    "Sends notifications to an user via XMPP."+
    "Can monitor system by performing daily commands."
  s.requirements = 
      [ 'AMQP-compatible server (for example, RabbitMQ)' ]

	require "lib/#{s.name}/version.rb"
  s.version     = OmniBot::VERSION
  s.author      = "theirix"
  s.email       = "theirix@gmail.com"
  s.homepage    = "http://github.com/theirix/omnibot"
  s.platform    = Gem::Platform::RUBY
	s.files 			= Dir.glob("{examples,lib}/**/*") + ['Rakefile', 'README.md']
  s.executables = Dir.glob('bin/*').map { |executable| File.basename executable } 
  s.test_files  = []
  s.has_rdoc    = false
  s.required_ruby_version = '>=1.8'
	s.rubyforge_project = 'nowarning'

	%w[ xmpp4r eventmachine amqp ].each do |dep|
		s.add_dependency(dep)
	end
end