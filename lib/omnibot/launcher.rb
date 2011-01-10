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

		def start args
			config_path = get_config_path args
			puts "Using config at #{config_path}"
			config = YAML.load_file(config_path)["config"]

			log_path = get_log_path config
			puts "Using log at #{log_path}"
			OmniLog::log = Logger.new(log_path) 
			OmniLog::log.level = Logger::DEBUG

			consumer = AMQPConsumer.new config
			consumer.start 

			OmniLog::log.close
		end
	end
end



