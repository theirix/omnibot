require 'yaml'
require 'xmpp4r'
require 'amqp'
require 'mq'
require 'xmpp4r/client'
require 'xmpp4r/roster'

include Jabber
Jabber::debug = false

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

	def dump_presence p
		p ? "Presence status=#{p.status} type=#{p.type} show=#{p.show} from=#{p.from} to=#{p.to} xml=(#{p.to_s})" : "nil"
	end

	def on_message_handler m
		puts "Got jabber message from #{m.from}:\n#{m.body}\n."
	end

	def is_needed_user? jid
		jid.strip == @subscriber && @subscriber_resource.match((jid.resource or ''))
	end

	def on_presence_callback old_presence, new_presence
		puts "Presence changed:\n...old #{dump_presence old_presence}\n...new #{dump_presence new_presence}"
		if is_needed_user? old_presence.from
			@subscriber_online = check_presence? old_presence
			puts "Subscriber #{@subscriber} is #{@subscriber_online ? "ready" : "not ready"}"
			pump_messages if @subscriber_online
		end
	end

	def on_subscripton_request_callback item, pres
		puts "Subscription request item=#{item} pres=#{dump_presence pres}"
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
			@roster = Roster::Helper.new(@client)
			@roster.add_subscription_request_callback { |item, pres| on_subscripton_request_callback item, pres }
		end

		puts "Client #{@client.is_connected? ? 'is' : 'isn\'t'} connected"
	end

	def check_presence? presence
		raise 'No subscriber' unless @subscriber

		puts "Subscriber #{@subscriber} is #{presence.show ? presence.show : 'online'}" 
		presence.show == nil || presence.show == :chat
	end

	def same_day? t1, t2
		t1.year == t2.year && t1.month == t2.month && t1.day == t2.day
	end

	def say_when_human orig, now
		if same_day? now, orig
			amount = now - orig
			if amount < 60*5
				return "just now"
			elsif amount < 60*60
				return "a hour ago"
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
		@client = Client::new(jid)
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
		puts "Register a message, " + (@subscriber_online ? "should send immediately" : "will send later")
		@messages << message
		pump_messages if @subscriber_online
	end

	def send message
		raise 'Not connected' unless @client.is_connected?

		puts "Sending a message..."
		orig = message[0]
		content = message[1]

		body = "Omnibot reported " + say_when_human(orig, Time.now) + ":\n" + content.to_s
		msg = Message::new(@subscriber, body)
		msg.type = :chat
		@client.send(msg)
	end
end

def amqp_loop config
	AMQP.start do
		# setup amqp
		mq = MQ.new
		exchange = mq.direct('omnibot-exchange')
		queue = mq.queue("omnibot-consumerqueue", :exclusive => true)
		queue.bind(exchange)

		begin
			puts "Setup jabber"
			omnibot = JabberBot.new(JID::new(config['omnibotuser']), config['omnibotpass'])
			omnibot.timer_provider = EM
			omnibot.set_subscriber JID::new(config['notifyjid']), config['notifyresource']
			omnibot.connect
		rescue
			puts "Jabber setup error: #{$!}"
			AMQP.stop{ EM.stop }
		end

		puts "==== AMQP is ready"

		queue.subscribe do |message|
			begin
				omnibot.add_message [Time.now, Marshal.load(message)]
			rescue Object => e
				puts "Sending message error: #{e.message}"
				puts "Trace:\n\t" + (e.backtrace ? e.backtrace.join("\n\t") : "")
				puts "Ignoring..."
			end
		end
	end
end

config_file = (ARGV[0] or 'config.yaml')
config = YAML.load_file(config_file)["config"]

Signal.trap('INT') do
	puts "It's a trap, should go..."
	AMQP.stop{ EM.stop }
end

amqp_loop config

puts "Exited"
