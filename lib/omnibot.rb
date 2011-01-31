require 'yaml'
require 'logger'

require 'amqp'
require 'mq'
require 'eventmachine'
require 'xmpp4r'
require 'xmpp4r/client'
require 'xmpp4r/roster'
require 'socket'
require 'date'

%w[ helpers jabberbot amqpconsumer omnisend launcher periodiccommand ].each do |file|
  require "omnibot/#{file}.rb"
end
