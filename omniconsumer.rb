require 'yaml'
require 'logger'
require 'xmpp4r'
require 'amqp'
require 'mq'
require 'xmpp4r/client'
require 'xmpp4r/roster'

include Jabber
Jabber::debug = false

class OmniLog

	def self.init_log
		logger = Logger.new('omnibot.log')
		logger.level = Logger::DEBUG
		logger
	end
		
	def self.log=(value)
		@logger = value
	end

	def self.log
		@logger
	end

	def self.debug(progname = nil, &block); @logger.debug(progname, &block); end
	def self.info(progname = nil, &block); @logger.info(progname, &block); end
	def self.warn(progname = nil, &block); @logger.warn(progname, &block); end
	def self.error(progname = nil, &block); @logger.warn(progname, &block); end
	def self.fatal(progname = nil, &block); @logger.fatal(progname, &block); end
end

# Helper class for counting reconnect attempts
class AttemptCounter
	def report
		OmniLog::debug "AttemptCounter: try #{@counter} of #{@max_attempts}"
	end
public
	def initialize max_attempts
		@counter = 0
		@max_attempts = max_attempts
		OmniLog::debug "AttemptCounter inited"
	end

	def out_of_attempts?
		@counter >= @max_attempts
	end

	def increase
		@counter += 1
		report
	end
end

def backtrace e
	e.respond_to?(:backtrace) && e.backtrace ? e.backtrace.join("\n\t") : ""
end


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
		OmniLog::error "Jabber exception happens at symbol \"#{sym_where}\": #{e}\nbacktrace\n#{backtrace e}"
		OmniLog::debug "stream is #{stream} vs client #{@client}"
		on_generic_exception_handler e
	end

	def safe_reconnect
		begin
			reconnect
		rescue ClientAuthenticationFailure => e
			OmniLog::error "Authentification error: #{e.class}: #{e}"
			raise 
		rescue Exception => e
			OmniLog::error "Reconnect hard error: #{e.class}: #{e}"
			on_generic_exception_handler e
		end
	end

	def on_generic_exception_handler e
		if e && (e.kind_of?(ServerDisconnected) || e.class.to_s =~ /^Errno::.+/)
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
		@client.send(Presence.new.set_type(:available))
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
			@roster = Roster::Helper.new(@client)
			@roster.add_subscription_request_callback { |item, pres| on_subscripton_request_callback item, pres }
		end

		OmniLog::debug "Client #{@client.is_connected? ? 'is' : 'isn\'t'} connected"
	end

	def check_presence? presence
		raise 'No subscriber' unless @subscriber

		OmniLog::debug "Subscriber #{@subscriber} is #{presence.show ? presence.show : 'online'}" 
		presence.show == nil || presence.show == :chat
	end

	def same_day? t1, t2
		t1.year == t2.year && t1.month == t2.month && t1.day == t2.day
	end

	def say_when_human orig, now
		if same_day? now, orig
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
		msg = Message::new(@subscriber, body)
		msg.type = :chat
		@client.send(msg)
	end
end


# Send to jabber user result of a daily command
class PeriodicCommand

	def on_first_timer
		OmniLog::debug "Okay, it's near of midnight"
		on_periodic_timer
		@timer_provider.add_periodic_timer(24*3600) { on_periodic_timer }
	end

	def on_periodic_timer
		OmniLog::info "Reporting command #{@command}"
		body = `#{@command}`
		raise 'Error launching command ' if $? != 0
		message_body = "Results of daily executed command #{@command}:\n" + body
		@jabber_messenger.call message_body
	end

public
	attr_writer :timer_provider

	def initialize command, pause
		@command = command
		@pause = pause

		raise 'Wrong command' if (command == nil or command == '')
	end

	def start
		`command -v #{@command}`
		if $? != 0
			OmniLog::warn "Command #{@command} is not available"
		else
			now = Time.now
			next_report_time = Time.local(now.year, now.month, now.day+1, 1, 0, 0)
			next_report_time = next_report_time + @pause
			@timer_provider.add_timer(next_report_time - now) { on_first_timer }
		end
	end

	def set_jabber_messenger &block
		@jabber_messenger = block
	end
end

# AMQP consumer class

class AMQPConsumer

	def send_message message
		begin
			@omnibot.add_message [Time.now, message]
		rescue Object => e
			OmniLog::error "Sending message error: #{e.message}\ntrace:\n#{backtrace e}\nIgnoring..."
		end
	end

	def initialize config
		@config = config
	end

	def amqp_loop
		# setup amqp
		mq = MQ.new
		exchange = mq.direct('omnibot-exchange')
		queue = mq.queue("omnibot-consumerqueue", :exclusive => true)
		queue.bind(exchange)

		begin
			OmniLog::info "Setup omnibot..."
			@omnibot = JabberBot.new(JID::new(@config['omnibotuser']), @config['omnibotpass'])
			@omnibot.timer_provider = EM
			@omnibot.set_subscriber JID::new(@config['notifyjid']), @config['notifyresource']
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

		rescue
			OmniLog::error "Services setup error: #{$!}"
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

# entry point
config_file = (ARGV[0] or 'config.yaml')
config = YAML.load_file(config_file)["config"]

log_file = (config['logpath'] or 'omnibot.log')
OmniLog::log = Logger.new(log_file) 
OmniLog::log.level = Logger::DEBUG

consumer = AMQPConsumer.new config
consumer.start 

OmniLog::log.close

