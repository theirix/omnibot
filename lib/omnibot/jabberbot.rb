module OmniBot

	# Jabber bot with reconnection and dnd-care logic
	class JabberBot

		def dump_presence p
			p ? "Presence status=#{p.status} type=#{p.type} show=#{p.show} from=#{p.from} to=#{p.to} xml=(#{p.to_s})" : "nil"
		end

		def on_message_handler m
			OmniLog::debug "Got jabber message from #{m.from}:\n#{m.body}\n."
		end

		def is_needed_user? jid
			jid.strip == @subscriber && @subscriber_resource.match((jid.resource or ''))
		end

		def on_presence_callback old_presence, new_presence
			OmniLog::debug "Presence changed:\n...old #{dump_presence old_presence}\n...new #{dump_presence new_presence}"
			if is_needed_user? old_presence.from
				@subscriber_online = check_presence? old_presence
				OmniLog::debug "Subscriber #{@subscriber} is #{@subscriber_online ? "ready" : "not ready"}"
				pump_messages if @subscriber_online
			end
		end

		def on_subscripton_request_callback item, pres
			OmniLog::debug "Subscription request item=#{item} pres=#{dump_presence pres}"
		end

		def on_exception_handler e, stream, sym_where
			OmniLog::error "Jabber exception happens at symbol \"#{sym_where}\": #{e}\nbacktrace\n#{Helpers::backtrace e}"
			OmniLog::debug "stream is #{stream} vs client #{@client}"
			on_generic_exception_handler e
		end

		def safe_reconnect
			begin
				reconnect
			rescue Jabber::ClientAuthenticationFailure => e
				OmniLog::error "Authentification error: #{e.class}: #{e}"
				raise 
			rescue Exception => e
				OmniLog::error "Reconnect hard error: #{e.class}: #{e}"
				on_generic_exception_handler e
			end
		end

		def on_generic_exception_handler e
			if e && (e.kind_of?(Jabber::ServerDisconnected) || e.class.to_s =~ /^Errno::.+/)
				OmniLog::error "No timer provider assigned" unless @timer_provider
				# attempt counter is set when it's needed to connect
				unless @ignore_reconnect
					@timer_provider.add_timer(@reconnect_pause) { try_reconnect }
				end
			end
		end

		def reconnect
			OmniLog::debug 'Going to reconnect'
			@client.connect
			@client.auth(@password)
			@client.send(Jabber::Presence.new.set_type(:available))
		end

		def try_reconnect
			return if @client.is_connected?

			OmniLog::debug 'Called try_reconnect'
			
			@attempt_counter = AttemptCounter.new(5) unless @attempt_counter
			@attempt_counter.increase

			if @attempt_counter.out_of_attempts?
				OmniLog::warn "Can't reconect too often, sleep for #{@reconnect_long_pause/60} minutes..."
				@attempt_counter = nil
				@ignore_reconnect = true
				@timer_provider.add_timer(@reconnect_long_pause) {
					@ignore_reconnect = false
					try_reconnect
				}
				return 
			end
				
			safe_reconnect

			if @client.is_connected?
				@attempt_counter = nil
				@roster = Jabber::Roster::Helper.new(@client)
				@roster.add_subscription_request_callback { |item, pres| on_subscripton_request_callback item, pres }
			end

			OmniLog::debug "Client #{@client.is_connected? ? 'is' : 'isn\'t'} connected"
		end

		def check_presence? presence
			raise 'No subscriber' unless @subscriber

			OmniLog::debug "Subscriber #{@subscriber} is #{presence.show ? presence.show : 'online'}" 
			presence.show == nil || presence.show == :chat
		end

		def say_when_human orig, now
			if Helpers::same_day? now, orig
				amount = now - orig
				if amount < 60
					return "just now"
				elsif amount < 60*60
					return "less than a hour ago"
				elsif amount < 60*60*6
					return amount.div(60).to_s + " hours ago"
				end
			end
			return orig.to_s
		end


		def pump_messages
			while msg = @messages.shift
				send msg
			end
		end

	public

		attr_writer :timer_provider

		def initialize jid, password
			@client = Jabber::Client::new(jid)
			@password = password
			raise 'No jid set' if jid.empty?
			raise 'No password set' unless password 

			@ignore_reconnect = false
			@reconnect_pause = 10
			@reconnect_long_pause = 60*15

			@messages = []
			@subscriber_online = false

			@client.on_exception { |e, stream, sym_where| on_exception_handler(e, stream, sym_where) }
			@client.add_message_callback { |m| on_message_handler m }
			@client.add_presence_callback { |from, to| on_presence_callback from, to }
		end

		def connect
			try_reconnect
		end

		def disconnect
			@client.close
		end

		def set_subscriber jid, resource=nil
			@subscriber = jid
			if resource == nil || resource == ''
				@subscriber_resource = /.*/
			else
				@subscriber_resource = Regexp.new(resource)
			end
		end

		def add_message message
			OmniLog::debug "Register a message, " + (@subscriber_online ? "should send immediately" : "will send later")
			@messages << message
			pump_messages if @subscriber_online
		end

		def send message
			raise 'Not connected' unless @client.is_connected?

			OmniLog::info "Sending a message..."
			orig = message[0]
			content = message[1]

			body = "Omnibot reported " + say_when_human(orig, Time.now) + ":\n" + content.to_s
			OmniLog::debug body

			msg = Jabber::Message::new(@subscriber, body)
			msg.type = :chat
			@client.send(msg)
		end
	end

end

