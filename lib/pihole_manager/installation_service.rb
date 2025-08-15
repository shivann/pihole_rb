# frozen_string_literal: true

module PiHoleManager
  # Single Responsibility: Pi-hole installation and setup
  class InstallationService
    def initialize(container, config, logger, ui)
      @container = container
      @config = config
      @logger = logger
      @ui = ui
    end

    def install
      @logger.log 'Starting installation'
      @container.require_cli!
      check_ports_available_or_warn
      prompt_for_initial_config

      if @container.container_exists?
        @ui.puts_warning("Container '#{@config['container_name']}' already exists.")
        if @ui.confirm('Overwrite existing container? This will stop and remove it')
          @container.stop_container(silent: true)
          @container.remove_container(silent: true)
        else
          @ui.puts 'Installation aborted.'
          return
        end
      end

      @container.create_container
      post_install_message
    end

    def update_container
      @logger.log 'Updating container to latest image'

      if @container.container_running?
        @container.stop_container(silent: true)
      end

      @container.remove_container(silent: true)
      # Re-run with same configuration; image latest will be pulled if needed
      @container.create_container
      @ui.puts_success('Container updated successfully.')
    end

    private

    def check_ports_available_or_warn
      ports = [@config['dns_port'], @config['web_port']]
      used = []
      
      ports.each do |p|
        cmd = %(sudo lsof -nP -i :#{p} -sTCP:LISTEN 2>/dev/null | wc -l)
        out, _ = @container.send(:run_capture, cmd)
        used << p if out.to_i > 0
      end

      if used.any?
        @ui.puts_warning("Warning: These ports are in use: #{used.join(', ')}")
        @ui.puts "You may need to stop conflicting services or change port configuration."
      end
    end

    def prompt_for_initial_config
      @ui.puts_info('=== Pi-hole Initial Configuration ===')
      
      # Timezone
      tz = @ui.prompt('Enter timezone (e.g., America/New_York) [press Enter for UTC]: ')
      @config['timezone'] = tz unless tz.nil? || tz.empty?

      # Admin password
      pw = @ui.prompt_password('Admin password (leave blank to auto-generate): ')
      if pw.nil? || pw.empty?
        pw = generate_password(16)
        @ui.puts "Generated password: #{pw}"
      end
      @config['web_password'] = pw

      # Host IP
      ip = @ui.prompt('Static IP address for this Mac mini (for DNS server setup) [press Enter to skip]: ')
      @config['host_ip'] = ip unless ip.nil? || ip.empty?

      @config.save_config
    end

    def post_install_message
      @ui.puts
      @ui.puts_success('✓ Pi-hole installation completed successfully!')
      @ui.puts
      @ui.puts 'Next steps:'
      @ui.puts "1. Web Interface: http://#{@config['host_ip'] || 'localhost'}:#{@config['web_port']}"
      @ui.puts "2. Set your router's DNS to: #{@config['host_ip'] || 'this-machine-ip'}"
      @ui.puts "3. Or configure individual devices to use this DNS server"
      @ui.puts
      @ui.puts 'You can now:'
      @ui.puts '• Use the interactive menu: ruby pihole_manager.rb'
      @ui.puts '• Block domains: ruby pihole_manager.rb block example.com'
      @ui.puts '• View status: ruby pihole_manager.rb status'
      @ui.puts
      @ui.puts "Admin password: #{@config['web_password'] || '(not set)'}"
      @ui.puts "Log file: #{@config['log_file']}"
      @ui.puts
    end

    def generate_password(length)
      chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(length) { chars.sample }.join
    end
  end
end
