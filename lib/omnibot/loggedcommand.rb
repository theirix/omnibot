# encoding: utf-8

module OmniBot
	module LoggedCommand

		def jabber_logged_command banner, command
			body = `#{command}`
			if $? != 0
				@jabber_messenger.call "#{banner} command #{command} failed with an error #{$?}:\n" + body
			end
			if body.strip != '' 
				@jabber_messenger.call "#{banner} command #{command} succeeded with:\n" + body
			end			
		end

		def set_jabber_messenger &block
			@jabber_messenger = block
		end
	end
end
