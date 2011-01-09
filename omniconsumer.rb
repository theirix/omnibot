require 'xmpp4r'
require 'amqp'
require 'mq'
require 'xmpp4r/client'

include Jabber
Jabber::debug = false

class Settings
	def omnibot_user; 'quark.notify@jabber.omniverse.ru'; end
	def omnibot_pass; 'YWCA7Tyron'; end
	def notify_jid; 'theirix@gmail.com'; end
end

class AttemptCounter
	def report
		puts "AttemptCounter: try #{@counter} of #{@max_attempts}"
	end
public
	def initialize max_attempts
		@counter = 0
		@max_attempts = max_attempts
		puts "AttemptCounter inited"
	end

	def out_of_attempts?
		@counter >= @max_attempts
	end

	def increase
		@counter += 1
		report
	end
end

class JabberBot

	def on_message_handler m
		puts "Got jabber message from #{m.from}:\n#{m.body}\n."
	end

	def on_exception_handler e, stream, sym_where
		puts "Jabber exception happens at symbol \"#{sym_where}\": #{e}"
		puts "stream is #{stream} vs client #{@client}"
		on_generic_exception_handler e
	end

	def safe_reconnect
		begin
			reconnect
		rescue Exception => e
			puts "Reconnect hard error: #{e.class}: #{e}"
			on_generic_exception_handler e
		end
	end

	def on_generic_exception_handler e
		if e && (e.kind_of?(ServerDisconnected) || e.class.to_s =~ /^Errno::.+/)
			puts "No timer provider assigned" unless @timer_provider
			# attempt counter is set when it's needed to connect
			unless @ignore_reconnect
				@timer_provider.add_timer(@reconnect_pause) { try_reconnect }
			end
		end
	end

	def reconnect
		puts 'Going to reconnect'
		@client.connect
		@client.auth(@password)
		@client.send(Presence.new.set_type(:available))
	end

	def try_reconnect
		return if @client.is_connected?

		puts 'Called try_reconnect'
		
		@attempt_counter = AttemptCounter.new(5) unless @attempt_counter
		@attempt_counter.increase

		if @attempt_counter.out_of_attempts?
			puts "Can't reconect too often, sleep for #{@reconnect_long_pause/60} minutes..."
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
		end

		puts "Client #{@client.is_connected? ? 'is' : 'isn\'t'} connected"
	end

public

	attr_writer :timer_provider

	def initialize jid, password
		@client = Client::new(jid)
		@password = password
		raise 'No jid set' if jid.empty?
		raise 'No password set' unless password 

		@ignore_reconnect = false
		@reconnect_pause = 10
		@reconnect_long_pause = 60*15
		@client.on_exception { |e, stream, sym_where| on_exception_handler(e, stream, sym_where) }
		@client.add_message_callback { |m| on_message_handler m }
	end

	def connect
		try_reconnect
	end

	def disconnect
		@client.close
	end

	def send_message to, body
		msg = Message::new(to, body)
		msg.type = :chat
		@client.send(msg)
	end
end

Signal.trap('INT') { AMQP.stop{ EM.stop } }

settings = Settings.new

AMQP.start do
	# setup amqp
	mq = MQ.new
	exchange = mq.direct('omnibot-exchange')
	queue = mq.queue("omnibot-consumerqueue", :exclusive => true)
	queue.bind(exchange)

	puts "Setup jabber"
	omnibot = JabberBot.new(JID::new(settings.omnibot_user), settings.omnibot_pass)
	omnibot.timer_provider = EM
	omnibot.connect

	puts "==== AMQP is ready"

	queue.subscribe do |message|
		text = Marshal.load(message)
		puts "#{Time.now}: #{text}"
		message_text = 'omnibot reports: ' + text
		omnibot.send_message(settings.notify_jid, message_text)
	end
end

