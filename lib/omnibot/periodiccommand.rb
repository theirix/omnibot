module OmniBot

	# Send to jabber user result of a daily command
	class PeriodicCommand

		include OmniBot::LoggedCommand

		def on_first_timer
			OmniLog::debug "Okay, it's near of midnight"
			on_periodic_timer
			@timer_provider.add_periodic_timer(24*3600) { on_periodic_timer }
		end

		def on_periodic_timer
			OmniLog::info "Reporting command #{@command}"
			jabber_logged_command 'Periodic command', @command
		end

	public
		attr_writer :timer_provider
		attr_writer :startup_pause

		def initialize command 
			@command = command
			@startup_pause = 0

			raise 'Wrong command' if (@command or '') == ''
		end

		def to_s
			"Periodic command '#{@command}'"
		end

		def start
			now = Time.now
			tomorrow = DateTime.now+1
			next_report_time = Time.local(tomorrow.year, tomorrow.month, tomorrow.day, 1, 0, 0)
			next_report_time = next_report_time + @startup_pause
			@timer_provider.add_timer(next_report_time - now) { on_first_timer }
		end
	end

end

