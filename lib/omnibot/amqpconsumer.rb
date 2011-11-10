module OmniBot

	# AMQP consumer class
	class AMQPConsumer

		attr_accessor :handlers
		attr_accessor :db

		def send_message message
			begin
				@omnibot.add_message [Time.now, message]
			rescue Object => e
				OmniLog::error "Sending message error: #{e.message}\ntrace:\n#{Helpers::backtrace e}\nIgnoring..."
			end
		end

		def initialize config
			@config = config
		end

		def amqp_loop
			AMQP.start do |connection|
				OmniLog::info "Setup amqp gem #{AMQP::VERSION}, AMQP protocol #{AMQP::Protocol::VERSION}..."
				mq = AMQP::Channel.new(connection)
				exchange = mq.direct(Helpers::amqp_exchange_name)
				queue = mq.queue('', :exclusive => true).bind(exchange, :routing_key => Helpers::amqp_routing_key)

				OmniLog::info "Setup omnibot..."
				@omnibot = JabberBot.new(Jabber::JID::new(@config['omnibotuser']), @config['omnibotpass'])
				@omnibot.timer_provider = EM
				@omnibot.set_subscriber Jabber::JID::new(@config['notifyjid']), @config['notifyresource']
				@omnibot.connect

				@handlers.each_with_index do |handler, index|
					OmniLog::info "Setup handler #{handler.to_s}..."
					handler.timer_provider = EM
					handler.set_jabber_messenger { |message| send_message message }
					handler.startup_pause = index*10
					handler.start
				end
			
				OmniLog::info "==== AMQP is ready ===="

				queue.subscribe do |msg|
					message = Marshal.load msg
					send_message message
				end

			end

		# it is a function rescue block, don't be afraid
		rescue => e
			OmniLog::error "AMQP/Jabber setup error: #{e.message}\ntrace:\n#{Helpers::backtrace e}\nExiting..."
			AMQP.stop{ EM.stop }
		end

		# Main AMQP loop
		def start 
			
			# exit hook
			Signal.trap('INT') do
				OmniLog::info "It's a trap, should exit..."
				AMQP.stop{ EM.stop }
			end

			amqp_loop
			
			OmniLog::info "Exited"
		end

	end

end

