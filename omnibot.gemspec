require 'bundler'

Gem::Specification.new do |s|
	s.specification_version = 3
	s.name = "omnibot"
	s.summary = "Simple XMPP bot for server monitoring"
	s.description = "Works with AMQP for sending messages at server side."+
	"Sends notifications to an user via XMPP."+
	"Can monitor system by performing daily commands."
	s.requirements  =
	[ 'AMQP-compatible server (for example, RabbitMQ)' ]

	require File.join(File.dirname(__FILE__),"lib/#{s.name}/version.rb")
	s.version = OmniBot::VERSION
	s.author = "theirix"
	s.email = "theirix@gmail.com"
	s.homepage = "http://github.com/theirix/omnibot"
	s.platform = Gem::Platform::RUBY
	s.files = Dir.glob("{examples,lib}/**/*") + ['Rakefile', 'README.md', 'LICENSE']
	s.executables = Dir.glob('bin/*').map { |executable| File.basename executable }
	s.test_files = []
	s.has_rdoc = false
	s.required_ruby_version = '>=1.9'
	s.rubyforge_project = 'nowarning'
	s.license = "BSD"

	s.add_runtime_dependency('amqp', '~> 1.5.1' )
	s.add_runtime_dependency('xmpp4r', '~> 0.5.0')
	s.add_runtime_dependency('eventmachine', '~> 1.0.3')
	s.add_runtime_dependency('mail', '~> 2.5.4')
	s.add_runtime_dependency('sqlite3', '~> 1.3.7')
	s.add_runtime_dependency('retryable')
	s.add_runtime_dependency('rake', '>= 0')
end
