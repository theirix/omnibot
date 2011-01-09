require 'amqp'
require 'mq'

exit(1) if ARGV.empty? 
message = ARGV.join(' ')
puts "Sending message #{message}"
data = Marshal.dump(message)

Signal.trap('INT') { AMQP.stop{ EM.stop } }

AMQP.start do
	mq = MQ.new
	exchange = mq.direct('omnibot-exchange')
	exchange.publish(data)
	puts 'sent'
	AMQP.stop{ EM.stop }
end
