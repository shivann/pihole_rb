#!/usr/bin/env ruby
# frozen_string_literal: true

# Pi-hole Container Manager for macOS using Docker
# Refactored version following SOLID design principles
# - Single Responsibility: Each class has one reason to change
# - Open/Closed: Extensible through interfaces, closed for modification
# - Liskov Substitution: Container implementations are interchangeable
# - Interface Segregation: Focused interfaces for specific concerns
# - Dependency Inversion: High-level modules don't depend on low-level modules

require 'json'

# Load all modules
require_relative 'lib/pihole_manager/application'

# Command line argument parsing
def parse_arguments(args)
  command = args.shift
  options = {}
  
  # Parse all options, including those that come after subcommands
  i = 0
  while i < args.length
    case args[i]
    when '--config'
      options[:config_path] = args[i + 1]
      args.slice!(i, 2)
    when '--verbose'
      options[:verbose] = true
      args.slice!(i, 1)
    when '--version'
      return { command: 'version' }
    when '--help'
      return { command: 'help' }
    when '--name'
      options[:name] = args[i + 1]
      args.slice!(i, 2)
    when '--start', '--start-time'
      options[:start] = args[i + 1]
      args.slice!(i, 2)
    when '--end', '--end-time'
      options[:end] = args[i + 1]
      args.slice!(i, 2)
    when '--days'
      options[:days] = args[i + 1]
      args.slice!(i, 2)
    when '--devices'
      options[:devices] = args[i + 1]
      args.slice!(i, 2)
    else
      i += 1
    end
  end
  
  { command: command, options: options, args: args }
end

# Schedule command handler
def handle_schedule_command(app, args, options)
  if args.empty?
    warn "Error: schedule subcommand required"
    app.print_help
    exit 1
  end

  subcommand = args[0]
  remaining_args = args[1..]

  case subcommand
  when 'create'
    handle_schedule_create(app, remaining_args, options)
  when 'list', 'ls'
    app.list_schedules
  when 'status'
    app.show_schedule_status
  when 'enable'
    if remaining_args.empty?
      warn "Error: schedule name required for enable command"
      exit 1
    end
    app.enable_schedule(remaining_args[0])
  when 'disable'
    if remaining_args.empty?
      warn "Error: schedule name required for disable command"
      exit 1
    end
    app.disable_schedule(remaining_args[0])
  when 'delete', 'rm'
    if remaining_args.empty?
      warn "Error: schedule name required for delete command"
      exit 1
    end
    app.delete_schedule(remaining_args[0])
  when 'test'
    handle_schedule_test(app, remaining_args)
  else
    warn "Unknown schedule subcommand: #{subcommand}"
    app.print_help
    exit 1
  end
end

def handle_schedule_create(app, args, options)
  # Parse create command arguments
  name = options[:name]
  start_time = options[:start] || options[:start_time]
  end_time = options[:end] || options[:end_time]
  devices = options[:devices] || []
  days = options[:days]
  
  # Validate required arguments
  unless name && start_time && end_time
    warn "Error: --name, --start, and --end are required for schedule create"
    puts "\nExample: ruby pihole_manager.rb schedule create --name 'Night_Block' --start 22:00 --end 07:00"
    exit 1
  end
  
  # Parse days if provided
  parsed_days = nil
  if days
    case days.downcase
    when 'all', 'daily'
      parsed_days = (1..7).to_a
    when 'weekdays'
      parsed_days = (1..5).to_a
    when 'weekends'
      parsed_days = [6, 7]
    else
      # Parse custom days (e.g., "1,2,3,4,5" or "mon,tue,wed")
      parsed_days = parse_days_string(days)
    end
  end
  
  # Parse devices if provided
  device_list = []
  if devices.is_a?(String)
    device_list = devices.split(',').map(&:strip)
  elsif devices.is_a?(Array)
    device_list = devices
  end
  
  begin
    app.create_schedule(
      name: name,
      start_time: start_time,
      end_time: end_time,
      devices: device_list,
      days: parsed_days,
      enabled: true
    )
  rescue => e
    warn "Error creating schedule: #{e.message}"
    exit 1
  end
end

def handle_schedule_test(app, args)
  if args.size < 2
    warn "Error: schedule name and action (enable/disable) required for test command"
    puts "\nExample: ruby pihole_manager.rb schedule test Night_Block enable"
    exit 1
  end
  
  name = args[0]
  action = args[1]
  
  unless %w[enable disable].include?(action)
    warn "Error: test action must be 'enable' or 'disable'"
    exit 1
  end
  
  app.test_schedule(name, action)
end

def parse_days_string(days_str)
  day_map = {
    'mon' => 1, 'monday' => 1,
    'tue' => 2, 'tuesday' => 2,
    'wed' => 3, 'wednesday' => 3,
    'thu' => 4, 'thursday' => 4,
    'fri' => 5, 'friday' => 5,
    'sat' => 6, 'saturday' => 6,
    'sun' => 7, 'sunday' => 7
  }
  
  days = []
  days_str.split(/[,\s]+/).each do |day|
    day = day.strip.downcase
    if day.match?(/^\d+$/)
      # Numeric day
      day_num = day.to_i
      days << day_num if day_num.between?(1, 7)
    elsif day_map[day]
      # Named day
      days << day_map[day]
    end
  end
  
  days.uniq.sort
end

# Main execution
def main
  parsed = parse_arguments(ARGV.dup)
  command = parsed[:command]
  options = parsed[:options] || {}
  remaining_args = parsed[:args] || []

  # Create application instance with dependency injection
  app = PiHoleManager::Application.new(
    config_path: options[:config_path],
    verbose: options[:verbose]
  )

  case command
  when 'help', '--help', '-h'
    app.print_help
  when 'version', '--version', '-v'
    app.print_version
  when 'install'
    app.install
  when 'start'
    app.start_container
  when 'stop'
    app.stop_container
  when 'restart'
    app.restart_container
  when 'status'
    app.show_status
  when 'update'
    app.update_container
  when 'block'
    if remaining_args.empty?
      warn "Error: domain argument required for block command"
      app.print_help
      exit 1
    end
    app.block_domain(remaining_args[0])
  when 'unblock'
    if remaining_args.empty?
      warn "Error: domain argument required for unblock command"
      app.print_help
      exit 1
    end
    app.unblock_domain(remaining_args[0])
  when 'list-blocked'
    app.list_blocked_domains
  when 'bulk-block'
    if remaining_args.empty?
      warn "Error: file path argument required for bulk-block command"
      app.print_help
      exit 1
    end
    app.bulk_block(remaining_args[0])
  when 'bulk-unblock'
    if remaining_args.empty?
      warn "Error: file path argument required for bulk-unblock command"
      app.print_help
      exit 1
    end
    app.bulk_unblock(remaining_args[0])
  when 'backup'
    if remaining_args.empty?
      warn "Error: destination path argument required for backup command"
      app.print_help
      exit 1
    end
    app.backup(remaining_args[0])
  when 'restore'
    if remaining_args.empty?
      warn "Error: archive path argument required for restore command"
      app.print_help
      exit 1
    end
    app.restore(remaining_args[0])
  when 'logs'
    app.show_logs
  when 'query-logs'
    app.show_query_logs
  when 'stats'
    app.show_stats
  when 'web'
    app.open_web
  when 'setpassword'
    app.pihole_setpassword
  when 'cli'
    app.pihole_cli(*remaining_args)
  when 'schedule'
    handle_schedule_command(app, remaining_args, options)
  when 'menu'
    app.run_menu
  when nil
    # No command provided, show interactive menu
    app.run_menu
  else
    warn "Unknown command: #{command}"
    app.print_help
    exit 1
  end
rescue Interrupt
  puts "\nOperation cancelled."
  exit 130
rescue StandardError => e
  warn "Error: #{e.message}"
  exit 1
end

# Run the application
main if __FILE__ == $0
