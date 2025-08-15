# frozen_string_literal: true

require_relative 'config'
require_relative 'logger'
require_relative 'ui'
require_relative 'docker_container'
require_relative 'domain_service'
require_relative 'installation_service'
require_relative 'pihole_service'
require_relative 'backup_service'
require_relative 'schedule_service'
require_relative 'menu_system'

module PiHoleManager
  # Dependency Inversion: Main application class that coordinates all services
  # Single Responsibility: Application flow control and service coordination
  class Application
    SCRIPT_VERSION = '1.0.0'

    def initialize(config_path: nil, verbose: false)
      # Dependency Injection
      @config = Config.new(config_path: config_path, verbose: verbose)
      @ui = UI.new
      @logger = Logger.new(@config.data)
      @container = DockerContainer.new(@config.data, @logger, @ui)
      
      # Service composition
      @domain_service = DomainService.new(@container, @logger, @ui)
      @installation_service = InstallationService.new(@container, @config, @logger, @ui)
      @pihole_service = PiHoleService.new(@container, @config, @logger, @ui)
      @backup_service = BackupService.new(@config, @logger, @ui)
      @schedule_service = ScheduleService.new(@container, @config, @logger, @ui)
      @menu_system = MenuSystem.new(self, @ui)
    end

    # Container management methods
    def install
      @installation_service.install
    end

    def start_container
      @container.start_container
    end

    def stop_container
      @container.stop_container
    end

    def restart_container
      @container.restart_container
    end

    def update_container
      @installation_service.update_container
    end

    def show_status
      status = container_status
      @ui.puts "Container: #{@config['container_name']} | Status: #{status}"
    end

    def container_status
      if @container.container_running?
        'Running'
      elsif @container.container_exists?
        'Stopped'
      else
        'Not Installed'
      end
    end

    # Domain management methods
    def block_domain(domain)
      @domain_service.block_domain(domain)
    end

    def unblock_domain(domain)
      @domain_service.unblock_domain(domain)
    end

    def list_blocked_domains
      @domain_service.list_blocked_domains
    end

    def bulk_block(file_path)
      @domain_service.bulk_block(file_path)
    end

    def bulk_unblock(file_path)
      @domain_service.bulk_unblock(file_path)
    end

    # Pi-hole service methods
    def pihole_setpassword
      @pihole_service.setpassword
    end

    def pihole_cli(*args)
      @pihole_service.cli(*args)
    end

    def change_admin_password
      @pihole_service.change_admin_password
    end

    def update_timezone
      @pihole_service.update_timezone
    end

    def open_web
      @pihole_service.open_web_interface
    end

    # Monitoring and logs
    def show_logs
      @container.get_logs
    end

    def show_query_logs
      @pihole_service.get_query_logs
    end

    def show_stats
      @pihole_service.get_stats
    end

    def show_manager_logs
      if File.exist?(@config['log_file'])
        system('tail', '-n', '50', @config['log_file'])
      else
        @ui.puts_warning('No manager log file found.')
      end
    end

    # Configuration and backup
    def view_config
      @config.load_config # refresh
      @ui.puts JSON.pretty_generate(@config.data)
    end

    def backup(destination_path)
      @backup_service.backup(destination_path)
    end

    def restore(archive_path)
      @backup_service.restore(archive_path)
    end

    # Schedule management methods
    def create_schedule(name:, start_time:, end_time:, devices: [], days: nil, enabled: true)
      @schedule_service.create_schedule(
        name: name,
        start_time: start_time,
        end_time: end_time,
        devices: devices,
        days: days,
        enabled: enabled
      )
    end

    def list_schedules
      @schedule_service.list_schedules
    end

    def enable_schedule(name)
      @schedule_service.enable_schedule(name)
    end

    def disable_schedule(name)
      @schedule_service.disable_schedule(name)
    end

    def delete_schedule(name)
      @schedule_service.delete_schedule(name)
    end

    def show_schedule_status
      @schedule_service.show_schedule_status
    end

    def test_schedule(name, action)
      @schedule_service.test_schedule(name, action)
    end

    # Advanced operations
    def container_shell
      @ui.puts 'Opening container shell...'
      system("docker", "exec", "-it", @config['container_name'], "/bin/bash")
    end

    # Menu system
    def run_menu
      @menu_system.show_main_menu
    end

    # CLI helpers
    def print_help
      @ui.puts <<~USAGE
        Usage: ruby pihole_manager.rb [command] [options]

        Commands:
          install                      Install and configure Pi-hole
          start                        Start Pi-hole container
          stop                         Stop Pi-hole container
          restart                      Restart Pi-hole container
          status                       Show container status
          update                       Update Pi-hole container

          block <domain>               Block a domain
          unblock <domain>             Unblock a domain
          list-blocked                 List blocked domains

          bulk-block <file>            Block domains from file
          bulk-unblock <file>          Unblock domains from file

          schedule create              Create time-based blocking schedule
          schedule list                List all schedules
          schedule status              Show schedule status
          schedule enable <name>       Enable a schedule
          schedule disable <name>      Disable a schedule
          schedule delete <name>       Delete a schedule
          schedule test <name> <action> Test schedule (enable/disable)

          backup <path>                Backup configuration to path (dir or .tar.gz)
          restore <archive>            Restore configuration from archive

          logs                         View container logs
          query-logs                   View Pi-hole query logs
          stats                        Show DNS statistics
          web                          Open web interface
          setpassword                  Interactive password setup (pihole setpassword)
          cli [command]                Access Pi-hole CLI directly (e.g., cli help, cli status)

          menu                         Launch interactive menu

        Schedule Create Options:
          --name <name>                Schedule name (required)
          --start <time>               Start time in HH:MM format (required)
          --end <time>                 End time in HH:MM format (required)
          --days <days>                Days: all, weekdays, weekends, or custom (e.g., mon,tue,wed)
          --devices <ips>              Comma-separated device IPs (optional, default: all devices)

        Examples:
          # Network-wide blocking 10 PM to 6 AM every day
          ruby pihole_manager.rb schedule create --name Night_Block --start 22:00 --end 06:00

          # Block specific devices on weekdays 9 AM to 5 PM
          ruby pihole_manager.rb schedule create --name Work_Hours --start 09:00 --end 17:00 \\
            --days weekdays --devices 192.168.1.50,192.168.1.51

          # Weekend evening blocking
          ruby pihole_manager.rb schedule create --name Weekend_Block --start 20:00 --end 23:59 \\
            --days weekends

        Options:
          --config <file>              Use custom config file
          --verbose                    Enable verbose output
          --version                    Show script version
          --help                       Show this help
      USAGE
    end

    def print_version
      @ui.puts SCRIPT_VERSION
    end
  end
end
