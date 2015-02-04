# encoding: utf-8

require 'yaml'
require 'logger'
require 'base64'

require 'amqp'
require 'eventmachine'
require 'xmpp4r'
require 'xmpp4r/client'
require 'xmpp4r/roster'
require 'mail'
require 'sqlite3'
require 'socket'
require 'date'
require 'tmpdir'

require "xray/thread_dump_signal_handler"

# patch from https://github.com/ln/xmpp4r/issues/3

if RUBY_VERSION < "1.9"
# ...
else
    # Encoding patch
    require 'socket'
    class TCPSocket
        def external_encoding
            Encoding::BINARY
        end
    end

    require 'rexml/source'
    class REXML::IOSource
        alias_method :encoding_assign, :encoding=
        def encoding=(value)
            encoding_assign(value) if value
        end
    end

    begin
        # OpenSSL is optional and can be missing
        require 'openssl'
        class OpenSSL::SSL::SSLSocket
            def external_encoding
                Encoding::BINARY
            end
        end
    rescue
    end
end

# -----------------

module OmniBot

	%w[ helpers jabberbot amqpconsumer omnisend launcher loggedcommand periodiccommand mailchecker ].each do |file|
		require "omnibot/#{file}.rb"
	end

end
