# encoding: utf-8

module OmniBot
  class MailChecker
    include LoggedCommand

    def on_first_timer
      on_periodic_timer
      @timer_provider.add_periodic_timer(3600) { on_periodic_timer }
    end

    def match_condition(m, condition_name, mail_name = condition_name)
      values = m.send(mail_name)
      [values].flatten.any? do |value|
        @conditions[condition_name] && Regexp.new(@conditions[condition_name]).match(value.to_s)
      end
    end

    def match_conditions(m)
      @conditions.empty? || %w( subject from to cc date).any? { |condition| match_condition m, condition }
    end

    def on_periodic_timer
      OmniLog::info "Checking mail #{@address}"
      is_new_mail = false
      Mail.all.each do |m|
        rows = @db.execute 'select message from received_messages where account=? and message=?', @address, m.message_id

        next unless rows.empty?
        is_new_mail = true
        OmniLog::info "New message from #{m.from} about #{m.subject}; id #{m.message_id}"
        handle_message(m) if match_conditions(m)
        @db.execute 'insert into received_messages values(?, ?, ?)', @address, m.message_id, m.date.to_s
      end
      OmniLog::info 'No new mail' unless is_new_mail
    rescue => e
      OmniLog::error "MailChecker error: #{e.message}\ntrace:\n#{Helpers::backtrace e}"
    end

    def handle_message(m)
      OmniLog::info 'Matched ' + m.inspect.to_s
      attached = m.attachments.find { |a| a.mime_type =~ %r{application/(zip|x-zip|rar|x-rar).*} }
      if attached
        Dir.mktmpdir('omniatt') do |tmpdir|
          filename = tmpdir + '/' + attached.filename
          OmniLog::info "Writing attachment to #{filename}"
          File.open(filename, 'w') { |f| f.write attached.read }
          Dir.chdir(@unpack_to) do
            if filename =~ /\.zip$/
              system("unzip -oq '#{filename}'")
            elsif filename =~ /\.rar$/
              system("unrar x -y '#{filename}'")
            else
              raise 'Wrong filetype'
            end
            raise "Error extracting file #{filename} to #{@unpack_to}" if $? != 0
          end

          message_body = "Received an email '#{m.subject}' from '#{m.from.join(',')}' with "\
            "an attachment #{attached.filename}. Successfully extracted an attachment to #{@unpack_to}."
          @jabber_messenger.call message_body

          jabber_logged_command 'Mail post-receive ', "#{@command_post} #{filename} #{@unpack_to}"
        end
      else
        OmniLog::info 'No attachment found'
      end
    end

    def yaml_to_mailhash(yaml_config)
      { address: yaml_config['host'],
        port: yaml_config['port'],
        user_name: yaml_config['user'],
        password: yaml_config['password'],
        enable_ssl: yaml_config['ssl']
       }
    end

    public

    attr_writer :timer_provider
    attr_writer :startup_pause

    def initialize(mail_config, trigger_config, db)
      @startup_pause = 0
      @mail_config = mail_config
      @db = db
      @conditions = (trigger_config['if'] || {})
      @unpack_to = trigger_config['unpack_to']
      @command_post = trigger_config['command_post']
      @address = trigger_config['for']

      mailhash = yaml_to_mailhash(mail_config)
      Mail.defaults do
        retriever_method :pop3, mailhash
      end

      raise 'Wrong command' if (@command_post || '') == ''
      raise 'No dir to extract to' unless File.directory? @unpack_to
    end

    def to_s
      "Mail checker for #{@address}"
    end

    def start
      @timer_provider.add_timer(@startup_pause) { on_first_timer }
    end
  end
end
