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
        when '5' then schedule_management_menu
        when '6' then advanced_options_menu
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
      @ui.puts '5. Schedule Management'
      @ui.puts '6. Advanced Options'
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

    def schedule_management_menu
      loop do
        @ui.clear_screen
        @ui.puts_info('==== Schedule Management ====')
        @ui.puts '1. Create new schedule'
        @ui.puts '2. List all schedules'
        @ui.puts '3. Show schedule status'
        @ui.puts '4. Enable schedule'
        @ui.puts '5. Disable schedule'
        @ui.puts '6. Test schedule'
        @ui.puts '7. Delete schedule'
        @ui.puts '0. Back'
        
        choice = @ui.prompt('\nEnter your choice: ')&.strip
        
        case choice
        when '1' 
          create_schedule_interactive
          @ui.wait_for_key
        when '2' 
          @app.list_schedules
          @ui.wait_for_key
        when '3' 
          @app.show_schedule_status
          @ui.wait_for_key
        when '4'
          name = @ui.prompt('Enter schedule name to enable: ')
          if name && !name.empty?
            @app.enable_schedule(name)
            @ui.wait_for_key
          end
        when '5'
          name = @ui.prompt('Enter schedule name to disable: ')
          if name && !name.empty?
            @app.disable_schedule(name)
            @ui.wait_for_key
          end
        when '6'
          test_schedule_interactive
          @ui.wait_for_key
        when '7'
          name = @ui.prompt('Enter schedule name to delete: ')
          if name && !name.empty?
            @app.delete_schedule(name)
            @ui.wait_for_key
          end
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

    def create_schedule_interactive
      @ui.puts_info('=== Create New Schedule ===')
      @ui.puts
      
      # Get schedule name
      name = @ui.prompt('Schedule name (letters, numbers, underscore, dash only): ')
      return unless name && !name.empty?
      
      # Get start time
      @ui.puts
      @ui.puts 'Enter start time (24-hour format, e.g., 22:00):'
      start_time = @ui.prompt('Start time: ')
      return unless start_time && !start_time.empty?
      
      # Get end time
      @ui.puts
      @ui.puts 'Enter end time (24-hour format, e.g., 07:00):'
      end_time = @ui.prompt('End time: ')
      return unless end_time && !end_time.empty?
      
      # Get days
      @ui.puts
      @ui.puts 'Select days for this schedule:'
      @ui.puts '1. Every day'
      @ui.puts '2. Weekdays (Monday-Friday)'
      @ui.puts '3. Weekends (Saturday-Sunday)'
      @ui.puts '4. Custom selection'
      
      days_choice = @ui.prompt('Days choice [1-4]: ')
      
      days = case days_choice
             when '1' then (1..7).to_a
             when '2' then (1..5).to_a
             when '3' then [6, 7]
             when '4' then get_custom_days
             else
               @ui.puts_error('Invalid choice, using every day')
               (1..7).to_a
             end
      
      # Get device scope
      @ui.puts
      @ui.puts 'Device scope:'
      @ui.puts '1. All devices (network-wide blocking)'
      @ui.puts '2. Specific devices (enter IP addresses)'
      
      scope_choice = @ui.prompt('Scope choice [1-2]: ')
      
      devices = []
      if scope_choice == '2'
        @ui.puts
        @ui.puts 'Enter device IP addresses (one per line, empty line to finish):'
        loop do
          device = @ui.prompt('Device IP: ')
          break if device.nil? || device.empty?
          devices << device.strip
        end
      end
      
      # Create the schedule
      begin
        @app.create_schedule(
          name: name,
          start_time: start_time,
          end_time: end_time,
          devices: devices,
          days: days,
          enabled: true
        )
      rescue => e
        @ui.puts_error("Failed to create schedule: #{e.message}")
      end
    end

    def get_custom_days
      @ui.puts
      @ui.puts 'Select days (enter numbers separated by spaces):'
      @ui.puts '1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday'
      
      days_input = @ui.prompt('Days (e.g., "1 2 3 4 5" for weekdays): ')
      return (1..7).to_a unless days_input && !days_input.empty?
      
      selected_days = days_input.split.map(&:to_i).select { |d| d.between?(1, 7) }
      selected_days.empty? ? (1..7).to_a : selected_days.sort.uniq
    end

    def test_schedule_interactive
      @ui.puts_info('=== Test Schedule ===')
      @ui.puts
      
      name = @ui.prompt('Enter schedule name to test: ')
      return unless name && !name.empty?
      
      @ui.puts
      @ui.puts '1. Test enable (activate blocking)'
      @ui.puts '2. Test disable (deactivate blocking)'
      
      action_choice = @ui.prompt('Test action [1-2]: ')
      
      action = case action_choice
               when '1' then 'enable'
               when '2' then 'disable'
               else
                 @ui.puts_error('Invalid choice')
                 return
               end
      
      @app.test_schedule(name, action)
    end
  end
end
