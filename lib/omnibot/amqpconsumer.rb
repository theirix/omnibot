module OmniBot

	# AMQP consumer class
	class AMQPConsumer

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
			# setup amqp
			mq = AMQP::Channel.new
			exchange = mq.direct(Helpers::amqp_exchange_name)
			queue = mq.queue("omnibot-consumerqueue", :exclusive => true)
			queue.bind(exchange)

			begin
				OmniLog::info "Setup omnibot..."
				@omnibot = JabberBot.new(Jabber::JID::new(@config['omnibotuser']), @config['omnibotpass'])
				@omnibot.timer_provider = EM
				@omnibot.set_subscriber Jabber::JID::new(@config['notifyjid']), @config['notifyresource']
				@omnibot.connect

				pause = 0
				[@config['periodiccommands']].flatten.each do |command|
					OmniLog::info "Setup command #{command}..."
					periodic_command = PeriodicCommand.new command, pause
					periodic_command.timer_provider = EM
					periodic_command.set_jabber_messenger { |message| send_message message }
					periodic_command.start
					pause += 20
				end

			rescue Object => e
				OmniLog::error "Sending message error: #{e.message}\ntrace:\n#{Helpers::backtrace e}\nExiting..."
				AMQP.stop{ EM.stop }
			end

			OmniLog::info "==== AMQP is ready ===="

			queue.subscribe do |msg|
				message = Marshal.load msg
				send_message message
			end
		end

		# Main AMQP loop
		def start 
			
			# exit hook
			Signal.trap('INT') do
				OmniLog::info "It's a trap, should exit..."
				AMQP.stop{ EM.stop }
			end

			AMQP.start do
				amqp_loop
			end

			OmniLog::info "Exited"
		end

	end

end

