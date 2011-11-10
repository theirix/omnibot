module OmniBot

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
		def self.error(progname = nil, &block); @logger.error(progname, &block); end
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

	class Helpers
		def self.backtrace e
			e.respond_to?(:backtrace) && e.backtrace ? e.backtrace.join("\n\t") : ""
		end
		
		def self.same_day? t1, t2
			t1.year == t2.year && t1.month == t2.month && t1.day == t2.day
		end

		def self.amqp_exchange_name
			'omnibot-exchange'
		end
		
		def self.amqp_routing_key
			'omnibot-routing'
		end

	end

end


