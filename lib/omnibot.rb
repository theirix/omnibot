require 'yaml'
require 'logger'

require 'amqp'
require 'eventmachine'
require 'xmpp4r'
require 'xmpp4r/client'
require 'xmpp4r/roster'
require 'mail'
require 'socket'
require 'date'
require 'tmpdir'

module OmniBot

	%w[ helpers jabberbot amqpconsumer omnisend launcher loggedcommand periodiccommand mailchecker ].each do |file|
		require "omnibot/#{file}.rb"
	end

end
