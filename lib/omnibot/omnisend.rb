module OmniBot

	class OmniSend

		def start args
			if args.empty? 
				message = STDIN.readlines.join
			else
				message = args.join(' ')
			end
			puts "Sending message #{message}"
			data = Marshal.dump(message)

			Signal.trap('INT') { AMQP.stop{ EM.stop } }

			AMQP.start do
				mq = AMQP::Channel.new
				exchange = mq.direct(Helpers::amqp_exchange_name)
				exchange.publish(data)
				puts 'sent'
				AMQP.stop{ EM.stop }
			end
		end
	end
end

