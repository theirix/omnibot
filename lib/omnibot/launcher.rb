# encoding: utf-8

module OmniBot

	# entry point
	class Launcher
		def get_config_path args
			return args[0] if args[0] && File.file?(args[0])
			path = File.join(ENV['HOME'],'.omnibot.yaml')
			return path if ENV['HOME'] && File.file?(path)
			raise 'No config file found, checked command line and ~/.omnibot.yaml'
		end

		def ensure_omnidir
			path = ENV['HOME']+'/.omnibot'
			FileUtils.mkdir path unless File.directory? path unless File.directory? path
			path
		end

		def get_log_path config
			return config['logpath'] unless (config['logpath'] or '').empty?
			ensure_omnidir + '/omnibot.log' 
		end

		def get_db 
			db = SQLite3::Database.new(ensure_omnidir + '/omnibot.sqlite3')
			if db.execute("select * from sqlite_master where type='table' and name='received_messages'").empty?
				db.execute <<-SQL
					create table received_messages (
						account TEXT,
						message TEXT,
						date TEXT
					);
				SQL
			end
			db
		end

		def provide_handlers config, db
			periodic_commands = [config['periodiccommands']].flatten.compact
			
			mails = [config['mails']].flatten.compact
			mail_triggers = [config['mailtriggers']].flatten.compact
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
					MailChecker.new mail, trigger, db
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

			db = get_db 
			consumer = AMQPConsumer.new config
			consumer.db = db
			consumer.handlers = provide_handlers(config, db)
			consumer.start

			OmniLog::log.close
		end
	end
end



