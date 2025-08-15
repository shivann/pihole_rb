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
  
  while args.any?
    case args.first
    when '--config'
      args.shift
      options[:config_path] = args.shift
    when '--verbose'
      args.shift
      options[:verbose] = true
    when '--version'
      return { command: 'version' }
    when '--help'
      return { command: 'help' }
    else
      break
    end
  end
  
  { command: command, options: options, args: args }
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
