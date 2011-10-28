module OmniBot

	# entry point
	class Launcher
		def get_config_path args
			return args[0] if args[0] && File.file?(args[0])
			path = File.join(ENV['HOME'],'.omnibot.yaml')
			return path if ENV['HOME'] && File.file?(path)
			raise 'No config file found, checked command line and ~/.omnibot.yaml'
		end

		def get_log_path config
			return config['logpath'] unless (config['logpath'] or '').empty?
			return '/var/log/omnibot.log' if File.directory? '/var/log/'
			return 'omnibot.log'
		end

		def get_store config
			store_path = config['storepath']
			unless File.directory? store_path
				store_path = ENV['HOME']+'/.omnibot'
				FileUtils.mkdir store_path unless File.directory? store_path
			end
			store_path + '/omnibot.store'
		end

		def provide_handlers config
			periodic_commands = ([config['periodiccommands']].flatten or [])
			
			mails = ([config['mails']].flatten or [])
			mail_triggers = ([config['mailtriggers']].flatten or [])
			mail_triggers.each do |mt|
				raise 'No mail found for a trigger' unless mails.find { |m| m['user'] == mt['for'] }
				raise 'Not supported action' unless mt['action'] == 'unpack'
			end
			used_mails = mails.select { |m| mail_triggers.find { |mt| m['user'] == mt['for'] } }
			raise 'Sorry but multiple mail addresses is not supported yet' if used_mails.size > 1

			[] + 
				periodic_commands.map do |command|
					PeriodicCommand.new command
				end +
				mail_triggers.map do |trigger|
					mail = mails.find { |m| m['user'] == trigger['for'] }
					MailChecker.new mail, trigger
				end
		end

		def start args
			config_path = get_config_path args
			puts "Using config at #{config_path}"
			config = YAML.load_file(config_path)["config"]

			log_path = get_log_path config
			puts "Using log at #{log_path}"
			OmniLog::log = Logger.new(log_path) 
			OmniLog::log.level = Logger::DEBUG

			consumer = AMQPConsumer.new config
			consumer.handlers = provide_handlers(config)
			consumer.start 

			OmniLog::log.close
		end
	end
end



