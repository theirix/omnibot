module OmniBot

	class MailChecker

		include LoggedCommand

		def on_first_timer
			OmniLog::debug "Okay, it's near of midnight"
			on_periodic_timer
			@timer_provider.add_periodic_timer(3600) { on_periodic_timer }
		end

		def match_condition m, condition_name, mail_name = condition_name
			values = m.send(mail_name)
			[values].flatten.any? do |value| 
				@conditions[condition_name] && Regexp.new(@conditions[condition_name]).match(value.to_s)
			end
		end

		def match_conditions m
			%w{ subject from to cc date}.any? { |condition| match_condition m, condition }
		end

		def on_periodic_timer
			OmniLog::info "Checking mail #{@mail_config['address']}"
			Mail.all.each do |m|
				OmniLog::info "   look at message from #{m.from} about #{m.subject}"
				handle_message(m) if match_conditions m
			end
		end

		def handle_message m
			OmniLog::info "Matched " + m.inspect.to_s
			attached = m.attachments.find { |a| a.mime_type =~ /application\/x-zip.*/ }
			if attached
				Dir.mktmpdir('omniatt') do |tmpdir|
					filename = tmpdir + '/' + attached.filename
					OmniLog::info "Writing attachment to #{filename}"
					File.open(filename,'w') { |f| f.write attached.read }
					Dir.chdir(@unpack_to) do
						system("unzip -oq '#{filename}'")
						raise "Error extracting file #{filename} to #{@unpack_to}" if $? != 0
					end
					  
					message_body = "Received an email '#{m.subject}' from '#{m.from.join(',')}' with "+
							"an attachment #{attached.filename}. Successfully extracted an attachment to #{@unpack_to}."
					@jabber_messenger.call message_body

					jabber_logged_command 'Mail post-receive ', "#{@command_post} #{filename} #{@unpack_to}"
				end
			else
				OmniLog::info "No attachment found" 
			end
		end
		
		def yaml_to_mailhash yaml_config
		 { :address => yaml_config['host'],
		 	 :port => yaml_config['port'],
		 	 :user_name => yaml_config['user'],
		 	 :password => yaml_config['password'],
		 	 :enable_ssl => yaml_config['ssl']
			}
		end

	public
		attr_writer :timer_provider
		attr_writer :startup_pause

		def initialize mail_config, trigger_config 
			@startup_pause = 0
			@mail_config = mail_config
			@conditions = trigger_config['if']
			@unpack_to = trigger_config['unpack_to']
			@command_post = trigger_config['command_post']
			@send_to = trigger_config['send_to']

			mailhash = yaml_to_mailhash(mail_config)
			Mail.defaults do
				retriever_method :pop3, mailhash
			end

			raise 'Wrong command' if (@command_post or '') == ''
			raise 'No dir to extract to' unless File.directory? @unpack_to
		end
		
		def to_s
			"Mail checker for #{@send_to}"
		end

		def start
			@timer_provider.add_timer(@startup_pause) { on_first_timer }
		end
	end

end

