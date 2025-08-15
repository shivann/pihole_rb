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
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
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
        @ui.puts '1. Install Pi-hole'
        @ui.puts '2. Start container'
        @ui.puts '3. Stop container'
        @ui.puts '4. Restart container'
        @ui.puts '5. Update container'
        @ui.puts '6. Show status'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1' 
          @app.install
          @ui.wait_for_key
        when '2' 
          @app.start_container
          @ui.wait_for_key
        when '3' 
          @app.stop_container
          @ui.wait_for_key
        when '4' 
          @app.restart_container
          @ui.wait_for_key
        when '5' 
          @app.update_container
          @ui.wait_for_key
        when '6' 
          @app.show_status
          @ui.wait_for_key
        when '0', nil then break
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
      end
    end

    def domain_management_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Domain Management ====')
        @ui.puts '1. Block domain'
        @ui.puts '2. Unblock domain'
        @ui.puts '3. List blocked domains'
        @ui.puts '4. Bulk block domains (from file)'
        @ui.puts '5. Bulk unblock domains (from file)'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1'
          domain = @ui.prompt('Enter domain to block: ')
          if domain && !domain.empty?
            @app.block_domain(domain)
            @ui.wait_for_key
          end
        when '2'
          domain = @ui.prompt('Enter domain to unblock: ')
          if domain && !domain.empty?
            @app.unblock_domain(domain)
            @ui.wait_for_key
          end
        when '3' 
          @app.list_blocked_domains
          @ui.wait_for_key
        when '4'
          file_path = @ui.prompt('Enter file path: ')
          if file_path && !file_path.empty?
            @app.bulk_block(file_path)
            @ui.wait_for_key
          end
        when '5'
          file_path = @ui.prompt('Enter file path: ')
          if file_path && !file_path.empty?
            @app.bulk_unblock(file_path)
            @ui.wait_for_key
          end
        when '0', nil then break
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
      end
    end

    def configuration_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Configuration ====')
        @ui.puts '1. View current settings'
        @ui.puts '2. Change admin password'
        @ui.puts '3. Interactive password setup (pihole setpassword)'
        @ui.puts '4. Update timezone'
        @ui.puts '5. Export configuration (backup)'
        @ui.puts '6. Import configuration (restore)'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1' 
          @app.view_config
          @ui.wait_for_key
        when '2' 
          @app.change_admin_password
          @ui.wait_for_key
        when '3' 
          @app.pihole_setpassword
          @ui.wait_for_key
        when '4' 
          @app.update_timezone
          @ui.wait_for_key
        when '5'
          path = @ui.prompt('Enter destination path (dir or file): ')
          if path && !path.empty?
            @app.backup(path)
            @ui.wait_for_key
          end
        when '6'
          path = @ui.prompt('Enter archive path: ')
          if path && !path.empty?
            @app.restore(path)
            @ui.wait_for_key
          end
        when '0', nil then break
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
      end
    end

    def logs_monitoring_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Logs & Monitoring ====')
        @ui.puts '1. View container logs'
        @ui.puts '2. View Pi-hole query logs'
        @ui.puts '3. Show DNS statistics'
        @ui.puts '4. View manager logs'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1' 
          @app.show_logs
          @ui.wait_for_key
        when '2' 
          @app.show_query_logs
          @ui.wait_for_key
        when '3' 
          @app.show_stats
          @ui.wait_for_key
        when '4' 
          @app.show_manager_logs
          @ui.wait_for_key
        when '0', nil then break
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
      end
    end

    def advanced_options_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Advanced Options ====')
        @ui.puts '1. Pi-hole CLI (interactive)'
        @ui.puts '2. Container shell (bash)'
        @ui.puts '3. Open web interface'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1' 
          @app.pihole_cli
          @ui.wait_for_key
        when '2' 
          @app.container_shell
          @ui.wait_for_key
        when '3' 
          @app.open_web
          @ui.wait_for_key
        when '0', nil then break
        else 
          @ui.puts_error('Invalid choice.')
          @ui.wait_for_key
        end
      end
    end
  end
end
