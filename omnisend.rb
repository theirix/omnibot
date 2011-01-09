require 'amqp'
require 'mq'

exit(1) unless ARGV.size == 1
data = Marshal.dump(ARGV[0])

Signal.trap('INT') { AMQP.stop{ EM.stop } }

AMQP.start do
	mq = MQ.new
	exchange = mq.direct('omnibot-exchange')
	exchange.publish(data)
	puts 'sent'
	AMQP.stop{ EM.stop }
end
