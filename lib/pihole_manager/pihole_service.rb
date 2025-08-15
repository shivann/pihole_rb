# frozen_string_literal: true

module PiHoleManager
  # Single Responsibility: Pi-hole specific operations and CLI access
  class PiHoleService
    def initialize(container, config, logger, ui)
      @container = container
      @config = config
      @logger = logger
      @ui = ui
    end

    def setpassword
      @logger.log 'Running pihole setpassword interactively'
      @ui.puts 'Running interactive password setup inside Pi-hole container...'
      @ui.puts_warning('Note: You will be prompted to enter the password twice for confirmation.')
      @ui.puts

      result = @container.execute_command('pihole setpassword', interactive: true)

      if result
        @ui.puts
        @ui.puts_success('Password updated successfully!')
        @ui.puts 'You may want to save this password to the manager config:'
        
        if @ui.confirm('Update manager config with new password?')
          new_pw = @ui.prompt_password('Enter the password you just set: ')
          unless new_pw.empty?
            @config['web_password'] = new_pw
            @config.save_config
            @ui.puts_success('Manager config updated.')
          end
        end
      else
        @ui.puts
        @ui.puts_error('Failed to update password. Check container status.')
      end
    end

    def cli(*args)
      if args.empty?
        @ui.puts 'Entering interactive Pi-hole CLI...'
        @ui.puts_warning('Type "exit" or press Ctrl+D to return to manager.')
        @ui.puts 'Available commands: help, version, status, chronometer, query, etc.'
        @ui.puts
        @logger.log 'Starting interactive pihole CLI session'
        @container.execute_command('pihole', interactive: true)
      else
        pihole_cmd = args.join(' ')
        @logger.log "Running pihole CLI command: #{pihole_cmd}"
        @container.execute_command("pihole #{pihole_cmd}", interactive: true)
      end
    end

    def get_stats
      @container.execute_command('/usr/local/bin/pihole -c -e')
    end

    def get_query_logs
      @container.execute_command('tail -n 200 /var/log/pihole/pihole.log')
    end

    def change_admin_password
      new_pw = @ui.prompt_password('Enter new admin password: ')
      
      if new_pw.nil? || new_pw.empty?
        @ui.puts_error('Password cannot be empty.')
        return
      end

      @config['web_password'] = new_pw
      @config.save_config
      
      # Update running container env by executing pihole command
      escaped_pw = shell_escape(new_pw)
      @container.execute_command("/usr/local/bin/pihole -a -p #{escaped_pw} #{escaped_pw}")
      @ui.puts_success('Admin password updated.')
    end

    def update_timezone
      tz = @ui.prompt('Enter timezone (e.g., America/New_York): ')
      
      if tz.nil? || tz.empty?
        @ui.puts 'Timezone not changed.'
        return
      end

      @config['timezone'] = tz
      @config.save_config
      @ui.puts_success('Timezone saved. Restart container to apply.')
    end

    def open_web_interface
      url = if @config['host_ip'] && !@config['host_ip'].empty?
              "http://#{@config['host_ip']}:#{@config['web_port']}/admin"
            else
              "http://localhost:#{@config['web_port']}/admin"
            end

      @ui.puts "Opening Pi-hole web interface: #{url}"
      system('open', url)
    end

    private

    def shell_escape(str)
      "'#{str.to_s.gsub("'", "'\\''")}'"
    end
  end
end
