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

			AMQP.start do |connection|
				mq = AMQP::Channel.new(connection)
				exchange = mq.direct(Helpers::amqp_exchange_name)
				exchange.publish(data, :routing_key => Helpers::amqp_routing_key)
				EM.add_timer(2.0) { connection.close { puts 'sent' ; EM.stop } }
			end
		end
	end
end

