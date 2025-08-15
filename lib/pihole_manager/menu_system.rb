# frozen_string_literal: true

module PiHoleManager
  # Single Responsibility: Menu system and navigation
  class MenuSystem
    def initialize(application, ui)
      @app = application
      @ui = ui
    end

    def show_main_menu
      loop do
        @ui.clear_screen
        display_main_menu_header
        display_main_menu_options
        
        choice = @ui.prompt('\nEnter your choice: ')
        
        case choice&.strip
        when '1' then container_management_menu
        when '2' then domain_management_menu
        when '3' then configuration_menu
        when '4' then logs_monitoring_menu
        when '5' then advanced_options_menu
        when '0', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == '0'
      end
    end

    private

    def display_main_menu_header
      header_status = @app.container_status
      @ui.puts @ui.color(:bold, '==== Pi-hole Container Manager ====')
      @ui.puts "Status: #{header_status}"
      @ui.puts
    end

    def display_main_menu_options
      @ui.puts '1. Container Management'
      @ui.puts '2. Domain Management'
      @ui.puts '3. Configuration'
      @ui.puts '4. Logs & Monitoring'
      @ui.puts '5. Advanced Options'
      @ui.puts '0. Exit'
    end

    def container_management_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Container Management ====')
        @ui.puts 'a. Install Pi-hole'
        @ui.puts 'b. Start container'
        @ui.puts 'c. Stop container'
        @ui.puts 'd. Restart container'
        @ui.puts 'e. Update container'
        @ui.puts 'f. Show status'
        @ui.puts 'x. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip&.downcase
        
        case choice
        when 'a' then @app.install
        when 'b' then @app.start_container
        when 'c' then @app.stop_container
        when 'd' then @app.restart_container
        when 'e' then @app.update_container
        when 'f' then @app.show_status
        when 'x', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == 'x'
      end
    end

    def domain_management_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Domain Management ====')
        @ui.puts 'a. Block domain'
        @ui.puts 'b. Unblock domain'
        @ui.puts 'c. List blocked domains'
        @ui.puts 'd. Bulk block domains (from file)'
        @ui.puts 'e. Bulk unblock domains (from file)'
        @ui.puts 'x. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip&.downcase
        
        case choice
        when 'a'
          domain = @ui.prompt('Enter domain to block: ')
          @app.block_domain(domain) if domain && !domain.empty?
        when 'b'
          domain = @ui.prompt('Enter domain to unblock: ')
          @app.unblock_domain(domain) if domain && !domain.empty?
        when 'c' then @app.list_blocked_domains
        when 'd'
          file_path = @ui.prompt('Enter file path: ')
          @app.bulk_block(file_path) if file_path && !file_path.empty?
        when 'e'
          file_path = @ui.prompt('Enter file path: ')
          @app.bulk_unblock(file_path) if file_path && !file_path.empty?
        when 'x', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == 'x'
      end
    end

    def configuration_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Configuration ====')
        @ui.puts 'a. View current settings'
        @ui.puts 'b. Change admin password'
        @ui.puts 'c. Interactive password setup (pihole setpassword)'
        @ui.puts 'd. Update timezone'
        @ui.puts 'e. Export configuration (backup)'
        @ui.puts 'f. Import configuration (restore)'
        @ui.puts 'x. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip&.downcase
        
        case choice
        when 'a' then @app.view_config
        when 'b' then @app.change_admin_password
        when 'c' then @app.pihole_setpassword
        when 'd' then @app.update_timezone
        when 'e'
          path = @ui.prompt('Enter destination path (dir or file): ')
          @app.backup(path) if path && !path.empty?
        when 'f'
          path = @ui.prompt('Enter archive path: ')
          @app.restore(path) if path && !path.empty?
        when 'x', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == 'x'
      end
    end

    def logs_monitoring_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Logs & Monitoring ====')
        @ui.puts 'a. View container logs'
        @ui.puts 'b. View Pi-hole query logs'
        @ui.puts 'c. Show DNS statistics'
        @ui.puts 'd. View manager logs'
        @ui.puts 'x. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip&.downcase
        
        case choice
        when 'a' then @app.show_logs
        when 'b' then @app.show_query_logs
        when 'c' then @app.show_stats
        when 'd' then @app.show_manager_logs
        when 'x', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == 'x'
      end
    end

    def advanced_options_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Advanced Options ====')
        @ui.puts 'a. Pi-hole CLI (interactive)'
        @ui.puts 'b. Container shell (bash)'
        @ui.puts 'c. Open web interface'
        @ui.puts 'x. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip&.downcase
        
        case choice
        when 'a' then @app.pihole_cli
        when 'b' then @app.container_shell
        when 'c' then @app.open_web
        when 'x', nil then break
        else @ui.puts_error('Invalid choice.')
        end
        
        @ui.wait_for_key unless choice == 'x'
      end
    end
  end
end
