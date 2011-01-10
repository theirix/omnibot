module OmniBot

	class OmniSend

		def start args
			return 1 if args.empty? 
			message = args.join(' ')
			puts "Sending message #{message}"
			data = Marshal.dump(message)

			Signal.trap('INT') { AMQP.stop{ EM.stop } }

			AMQP.start do
				mq = MQ.new
				exchange = mq.direct(Helpers::amqp_exchange_name)
				exchange.publish(data)
				puts 'sent'
				AMQP.stop{ EM.stop }
			end
		end
	end
end

