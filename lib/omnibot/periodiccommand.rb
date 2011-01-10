module OmniBot

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

end

