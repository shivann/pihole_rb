# frozen_string_literal: true

require 'json'
require 'time'

module PiHoleManager
  # Single Responsibility: Time-based blocking schedule management
  class ScheduleService
    def initialize(container, config, logger, ui)
      @container = container
      @config = config
      @logger = logger
      @ui = ui
      @schedules_file = File.join(@config['data_dir'], 'schedules.json')
      ensure_schedules_file_exists
    end

    def create_schedule(name:, start_time:, end_time:, devices: [], days: nil, enabled: true)
      validate_schedule_params!(name, start_time, end_time)
      
      schedule = {
        name: name,
        start_time: start_time,
        end_time: end_time,
        devices: devices || [],
        days: days || (1..7).to_a, # Default: all days (1=Monday, 7=Sunday)
        enabled: enabled,
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601
      }

      schedules = load_schedules
      
      if schedules.any? { |s| s['name'] == name }
        raise "Schedule '#{name}' already exists"
      end

      schedules << schedule
      save_schedules(schedules)
      
      setup_pihole_group(name, devices)
      update_cron_jobs
      
      @logger.log "Created schedule: #{name} (#{start_time}-#{end_time})"
      @ui.puts_success "Schedule '#{name}' created successfully"
      
      schedule
    end

    def list_schedules
      schedules = load_schedules
      
      if schedules.empty?
        @ui.puts_warning "No schedules configured"
        return []
      end

      @ui.puts @ui.color(:cyan, "=== Configured Schedules ===")
      @ui.puts
      
      schedules.each_with_index do |schedule, index|
        status = schedule['enabled'] ? @ui.color(:green, "ENABLED") : @ui.color(:red, "DISABLED")
        devices_info = schedule['devices'].empty? ? "All devices" : "#{schedule['devices'].size} device(s)"
        days_info = format_days(schedule['days'])
        
        @ui.puts "#{index + 1}. #{@ui.color(:bold, schedule['name'])} [#{status}]"
        @ui.puts "   Time: #{schedule['start_time']} - #{schedule['end_time']}"
        @ui.puts "   Days: #{days_info}"
        @ui.puts "   Scope: #{devices_info}"
        @ui.puts "   Created: #{Time.parse(schedule['created_at']).strftime('%Y-%m-%d %H:%M')}"
        @ui.puts
      end
      
      schedules
    end

    def enable_schedule(name)
      schedules = load_schedules
      schedule = schedules.find { |s| s['name'] == name }
      
      unless schedule
        @ui.puts_error "Schedule '#{name}' not found"
        return false
      end

      if schedule['enabled']
        @ui.puts_warning "Schedule '#{name}' is already enabled"
        return true
      end

      schedule['enabled'] = true
      schedule['updated_at'] = Time.now.iso8601
      save_schedules(schedules)
      update_cron_jobs
      
      @logger.log "Enabled schedule: #{name}"
      @ui.puts_success "Schedule '#{name}' enabled"
      true
    end

    def disable_schedule(name)
      schedules = load_schedules
      schedule = schedules.find { |s| s['name'] == name }
      
      unless schedule
        @ui.puts_error "Schedule '#{name}' not found"
        return false
      end

      unless schedule['enabled']
        @ui.puts_warning "Schedule '#{name}' is already disabled"
        return true
      end

      # Ensure the group is disabled when disabling schedule
      disable_pihole_group(name)
      
      schedule['enabled'] = false
      schedule['updated_at'] = Time.now.iso8601
      save_schedules(schedules)
      update_cron_jobs
      
      @logger.log "Disabled schedule: #{name}"
      @ui.puts_success "Schedule '#{name}' disabled"
      true
    end

    def delete_schedule(name)
      schedules = load_schedules
      schedule_index = schedules.find_index { |s| s['name'] == name }
      
      unless schedule_index
        @ui.puts_error "Schedule '#{name}' not found"
        return false
      end

      if @ui.confirm("Are you sure you want to delete schedule '#{name}'?")
        schedules.delete_at(schedule_index)
        save_schedules(schedules)
        
        # Clean up Pi-hole group
        cleanup_pihole_group(name)
        update_cron_jobs
        
        @logger.log "Deleted schedule: #{name}"
        @ui.puts_success "Schedule '#{name}' deleted"
        true
      else
        @ui.puts "Deletion cancelled"
        false
      end
    end

    def show_schedule_status
      schedules = load_schedules
      
      if schedules.empty?
        @ui.puts_warning "No schedules configured"
        return
      end

      @ui.puts @ui.color(:cyan, "=== Schedule Status ===")
      @ui.puts
      
      current_time = Time.now
      active_schedules = []
      
      schedules.each do |schedule|
        next unless schedule['enabled']
        
        is_active = schedule_active_now?(schedule, current_time)
        next_change = calculate_next_change(schedule, current_time)
        
        status_color = is_active ? :red : :green
        status_text = is_active ? "BLOCKING" : "INACTIVE"
        
        @ui.puts "#{@ui.color(:bold, schedule['name'])}: #{@ui.color(status_color, status_text)}"
        @ui.puts "  Next change: #{next_change}"
        @ui.puts
        
        active_schedules << schedule['name'] if is_active
      end
      
      if active_schedules.any?
        @ui.puts @ui.color(:red, "⚠️  Currently blocking: #{active_schedules.join(', ')}")
      else
        @ui.puts @ui.color(:green, "✅ No schedules currently blocking")
      end
    end

    def test_schedule(name, action)
      unless %w[enable disable].include?(action)
        @ui.puts_error "Invalid action. Use 'enable' or 'disable'"
        return false
      end

      schedules = load_schedules
      schedule = schedules.find { |s| s['name'] == name }
      
      unless schedule
        @ui.puts_error "Schedule '#{name}' not found"
        return false
      end

      @ui.puts_warning "Testing schedule '#{name}' - #{action} blocking"
      
      if action == 'enable'
        enable_pihole_group(name)
        @ui.puts_success "✅ Blocking enabled for '#{name}'"
        @ui.puts "Visit a website to test blocking, then run disable test to restore normal operation"
      else
        disable_pihole_group(name)
        @ui.puts_success "✅ Blocking disabled for '#{name}'"
        @ui.puts "Normal internet access restored"
      end
      
      true
    end

    private

    def ensure_schedules_file_exists
      return if File.exist?(@schedules_file)
      
      Dir.mkdir(@config['data_dir']) unless Dir.exist?(@config['data_dir'])
      File.write(@schedules_file, '[]')
    end

    def load_schedules
      JSON.parse(File.read(@schedules_file))
    rescue JSON::ParserError, Errno::ENOENT
      []
    end

    def save_schedules(schedules)
      File.write(@schedules_file, JSON.pretty_generate(schedules))
    end

    def validate_schedule_params!(name, start_time, end_time)
      raise "Name cannot be empty" if name.nil? || name.strip.empty?
      raise "Invalid name format" unless name.match?(/\A[a-zA-Z0-9_-]+\z/)
      
      validate_time_format!(start_time, "Start time")
      validate_time_format!(end_time, "End time")
    end

    def validate_time_format!(time_str, field_name)
      unless time_str.match?(/\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/)
        raise "#{field_name} must be in HH:MM format (e.g., 14:30)"
      end
    end

    def setup_pihole_group(name, devices)
      group_name = "Schedule_#{name}"
      
      @logger.log "Setting up Pi-hole group: #{group_name}"
      
      # Create the group in Pi-hole database
      create_group_cmd = "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO 'group' (name, enabled, description) VALUES ('#{group_name}', 0, 'Schedule: #{name}');\""
      @container.execute_command(create_group_cmd)
      
      # Add regex filter to block all domains
      regex_cmd = "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO domainlist (type, domain, enabled, comment) VALUES (3, '.*', 1, 'Block all for #{name}');\""
      @container.execute_command(regex_cmd)
      
      # Link regex to group
      link_cmd = "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO domainlist_by_group (domainlist_id, group_id) SELECT d.id, g.id FROM domainlist d, 'group' g WHERE d.domain='.*' AND d.type=3 AND d.comment='Block all for #{name}' AND g.name='#{group_name}';\""
      @container.execute_command(link_cmd)
      
      # Add devices to group if specified
      if devices.any?
        devices.each do |device|
          add_device_to_group(device, group_name)
        end
      end
      
      @ui.puts "Pi-hole group '#{group_name}' configured"
    end

    def add_device_to_group(device, group_name)
      # Add client if not exists
      client_cmd = "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO client (ip, comment) VALUES ('#{device}', 'Schedule managed device');\""
      @container.execute_command(client_cmd)
      
      # Link client to group
      link_client_cmd = "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO client_by_group (client_id, group_id) SELECT c.id, g.id FROM client c, 'group' g WHERE c.ip='#{device}' AND g.name='#{group_name}';\""
      @container.execute_command(link_client_cmd)
    end

    def enable_pihole_group(schedule_name)
      group_name = "Schedule_#{schedule_name}"
      enable_cmd = "sqlite3 /etc/pihole/gravity.db \"UPDATE 'group' SET enabled = 1 WHERE name = '#{group_name}';\""
      @container.execute_command(enable_cmd)
      @container.execute_command("pihole restartdns reload-lists")
      @logger.log "Enabled Pi-hole group: #{group_name}"
    end

    def disable_pihole_group(schedule_name)
      group_name = "Schedule_#{schedule_name}"
      disable_cmd = "sqlite3 /etc/pihole/gravity.db \"UPDATE 'group' SET enabled = 0 WHERE name = '#{group_name}';\""
      @container.execute_command(disable_cmd)
      @container.execute_command("pihole restartdns reload-lists")
      @logger.log "Disabled Pi-hole group: #{group_name}"
    end

    def cleanup_pihole_group(schedule_name)
      group_name = "Schedule_#{schedule_name}"
      
      # Get group ID
      get_id_cmd = "sqlite3 /etc/pihole/gravity.db \"SELECT id FROM 'group' WHERE name='#{group_name}';\""
      group_id = @container.execute_command(get_id_cmd)&.strip
      
      return unless group_id && !group_id.empty?
      
      # Remove group associations
      @container.execute_command("sqlite3 /etc/pihole/gravity.db \"DELETE FROM domainlist_by_group WHERE group_id=#{group_id};\"")
      @container.execute_command("sqlite3 /etc/pihole/gravity.db \"DELETE FROM client_by_group WHERE group_id=#{group_id};\"")
      @container.execute_command("sqlite3 /etc/pihole/gravity.db \"DELETE FROM 'group' WHERE id=#{group_id};\"")
      
      # Clean up domain list entry
      @container.execute_command("sqlite3 /etc/pihole/gravity.db \"DELETE FROM domainlist WHERE comment='Block all for #{schedule_name}';\"")
      
      @container.execute_command("pihole restartdns reload-lists")
      @logger.log "Cleaned up Pi-hole group: #{group_name}"
    end

    def update_cron_jobs
      schedules = load_schedules.select { |s| s['enabled'] }
      cron_entries = generate_cron_entries(schedules)
      
      # Create temporary cron file
      temp_cron_file = "/tmp/pihole_schedule_cron"
      File.write(temp_cron_file, cron_entries.join("\n") + "\n")
      
      # Get current crontab, remove old pihole schedule entries, add new ones
      current_cron = `crontab -l 2>/dev/null`.lines.reject { |line| line.include?("# PiHole Schedule:") }
      
      # Combine current cron with new schedule entries
      all_cron_lines = current_cron + cron_entries.map { |entry| "#{entry}\n" }
      
      # Write to temp file and install
      File.write(temp_cron_file, all_cron_lines.join)
      system("crontab #{temp_cron_file}")
      File.delete(temp_cron_file)
      
      @logger.log "Updated cron jobs for #{schedules.size} enabled schedule(s)"
      @ui.puts "Cron jobs updated for active schedules"
    end

    def generate_cron_entries(schedules)
      entries = []
      container_name = @config['container_name']
      
      schedules.each do |schedule|
        name = schedule['name']
        start_time = schedule['start_time']
        end_time = schedule['end_time']
        days = schedule['days']
        
        start_hour, start_min = start_time.split(':').map(&:to_i)
        end_hour, end_min = end_time.split(':').map(&:to_i)
        
        # Convert days array to cron format (0=Sunday, 1=Monday, etc.)
        cron_days = days.map { |d| d == 7 ? 0 : d }.join(',')
        
        # Enable blocking command
        enable_cmd = "docker exec #{container_name} sqlite3 /etc/pihole/gravity.db \"UPDATE 'group' SET enabled = 1 WHERE name = 'Schedule_#{name}'\" && docker exec #{container_name} pihole restartdns reload-lists"
        entries << "#{start_min} #{start_hour} * * #{cron_days} #{enable_cmd} # PiHole Schedule: #{name} start"
        
        # Disable blocking command
        disable_cmd = "docker exec #{container_name} sqlite3 /etc/pihole/gravity.db \"UPDATE 'group' SET enabled = 0 WHERE name = 'Schedule_#{name}'\" && docker exec #{container_name} pihole restartdns reload-lists"
        entries << "#{end_min} #{end_hour} * * #{cron_days} #{disable_cmd} # PiHole Schedule: #{name} end"
      end
      
      entries
    end

    def format_days(days_array)
      day_names = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
      
      if days_array.sort == (1..7).to_a
        "Every day"
      elsif days_array.sort == (1..5).to_a
        "Weekdays (Mon-Fri)"
      elsif days_array.sort == [6, 7] || days_array.sort == [0, 6]
        "Weekends (Sat-Sun)"
      else
        days_array.map { |d| day_names[d - 1] }.join(', ')
      end
    end

    def schedule_active_now?(schedule, current_time)
      current_day = current_time.wday == 0 ? 7 : current_time.wday # Convert Sunday from 0 to 7
      return false unless schedule['days'].include?(current_day)
      
      current_minutes = current_time.hour * 60 + current_time.min
      start_minutes = time_to_minutes(schedule['start_time'])
      end_minutes = time_to_minutes(schedule['end_time'])
      
      if start_minutes <= end_minutes
        # Same day schedule (e.g., 09:00 - 17:00)
        current_minutes >= start_minutes && current_minutes < end_minutes
      else
        # Overnight schedule (e.g., 22:00 - 06:00)
        current_minutes >= start_minutes || current_minutes < end_minutes
      end
    end

    def time_to_minutes(time_str)
      hour, min = time_str.split(':').map(&:to_i)
      hour * 60 + min
    end

    def calculate_next_change(schedule, current_time)
      start_minutes = time_to_minutes(schedule['start_time'])
      end_minutes = time_to_minutes(schedule['end_time'])
      current_minutes = current_time.hour * 60 + current_time.min
      current_day = current_time.wday == 0 ? 7 : current_time.wday
      
      if schedule_active_now?(schedule, current_time)
        # Currently blocking, find next end time
        if start_minutes <= end_minutes
          # Same day schedule
          end_time = Time.new(current_time.year, current_time.month, current_time.day, end_minutes / 60, end_minutes % 60)
        else
          # Overnight schedule - end is tomorrow if we're past midnight
          if current_minutes < end_minutes
            end_time = Time.new(current_time.year, current_time.month, current_time.day, end_minutes / 60, end_minutes % 60)
          else
            end_time = Time.new(current_time.year, current_time.month, current_time.day + 1, end_minutes / 60, end_minutes % 60)
          end
        end
        "Ends at #{end_time.strftime('%H:%M today')}"
      else
        # Not currently blocking, find next start time
        next_start = find_next_schedule_start(schedule, current_time)
        if next_start.to_date == current_time.to_date
          "Starts at #{next_start.strftime('%H:%M today')}"
        else
          "Starts #{next_start.strftime('%A at %H:%M')}"
        end
      end
    end

    def find_next_schedule_start(schedule, current_time)
      start_minutes = time_to_minutes(schedule['start_time'])
      current_minutes = current_time.hour * 60 + current_time.min
      current_day = current_time.wday == 0 ? 7 : current_time.wday
      
      # Check if start time is later today
      if schedule['days'].include?(current_day) && current_minutes < start_minutes
        return Time.new(current_time.year, current_time.month, current_time.day, start_minutes / 60, start_minutes % 60)
      end
      
      # Find next day with this schedule
      (1..7).each do |days_ahead|
        check_date = current_time + (days_ahead * 24 * 60 * 60)
        check_day = check_date.wday == 0 ? 7 : check_date.wday
        
        if schedule['days'].include?(check_day)
          return Time.new(check_date.year, check_date.month, check_date.day, start_minutes / 60, start_minutes % 60)
        end
      end
      
      # Fallback (shouldn't reach here)
      current_time + (24 * 60 * 60)
    end
  end
end
