#!/usr/bin/env ruby
# frozen_string_literal: true

# Pi-hole Container Manager for macOS using Docker
# - Direct command mode (e.g., install/start/stop/...)
# - Interactive menu when run without arguments
# - No external gems; uses only Ruby stdlib

require 'json'
require 'open3'
require 'fileutils'
require 'io/console'

class PiHoleManager
  SCRIPT_VERSION = '1.0.0'

  DEFAULTS = {
    'container_name' => 'pihole',
    'image' => 'pihole/pihole:latest',
    'config_root' => '/opt/pihole',
    'etc_pihole' => '/opt/pihole/etc-pihole',
    'etc_dnsmasq' => '/opt/pihole/etc-dnsmasq.d',
    'log_file' => '/opt/pihole/pihole-manager.log',
    'config_file' => '/opt/pihole/manager_config.json',
    'timezone' => ENV['TZ'] || 'Etc/UTC',
    'web_password' => nil,
    'host_ip' => nil,
    'web_port' => 80,
    'dns_port' => 53,
    'verbose' => false
  }.freeze

  # ANSI colors (optional)
  COLOR = {
    reset: "\e[0m",
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    cyan: "\e[36m",
    bold: "\e[1m"
  }.freeze

  attr_reader :config_path, :cfg

  def initialize(config_path: nil, verbose: false)
    @config_path = config_path || DEFAULTS['config_file']
    @cfg = DEFAULTS.dup
    load_config
    @cfg['verbose'] = verbose || @cfg['verbose']
    ensure_log_dir
  end

  # --------------- Utility Methods -----------------

  # Terminal color formatting with fallback
  def color(type, text)
    if ENV['NO_COLOR'] || !$stdout.tty?
      text
    else
      "#{COLOR[type]}#{text}#{COLOR[:reset]}"
    end
  end

  # --------------- Public: Commands -----------------

  def install
    log 'Starting installation'
    require_container_cli!
    ensure_directories
    check_ports_available_or_warn
    prompt_for_initial_config

    if container_exists?
      puts color(:yellow, "Container '#{@cfg['container_name']}' already exists.")
      if yes?('Overwrite existing container? This will stop and remove it')
        stop_container(silent: true)
        remove_container(silent: true)
      else
        puts 'Installation aborted.'
        return
      end
    end

    run_container
    post_install_message
  end

  def start_container(silent: false)
    require_container_cli!
    log 'Starting container'
    if container_running?
      puts 'Container is already running.' unless silent
      return
    end

    if container_exists?
      cmd = %(docker start #{@cfg['container_name']})
      ok = run_system(cmd)
      puts(ok ? 'Container started.' : 'Failed to start container.') unless silent
    else
      puts 'Container does not exist. Running a new one...'
      run_container
    end
  end

  def stop_container(silent: false)
    require_container_cli!
    log 'Stopping container'
    return puts('Container is not running.') unless container_running?

    cmd = %(docker stop #{@cfg['container_name']})
    ok = run_system(cmd)
    puts(ok ? 'Container stopped.' : 'Failed to stop container.') unless silent
  end

  def restart_container
    require_container_cli!
    log 'Restarting container'
    stop_container(silent: true)
    sleep 1
    start_container
  end

  def status_container
    require_container_cli!
    name = @cfg['container_name']
    status = container_status
    puts "Container: #{name} | Status: #{status}"
  end

  def update_container
    require_container_cli!
    log 'Updating container to latest image'
    ensure_directories

    if container_running?
      stop_container(silent: true)
    end

    remove_container(silent: true)
    # Re-run with same configuration; image latest will be pulled if needed
    run_container
  end

  def block_domain(domain)
    require_container_cli!
    validate_domain!(domain)
    log "Blocking domain: #{domain}"
    ensure_container_running!
    cmd = %(docker exec #{@cfg['container_name']} /usr/local/bin/pihole -b #{shell_escape(domain)})
    exec_and_stream(cmd)
  end

  def unblock_domain(domain)
    require_container_cli!
    validate_domain!(domain)
    log "Unblocking domain: #{domain}"
    ensure_container_running!
    cmd = %(docker exec #{@cfg['container_name']} /usr/local/bin/pihole -b -d #{shell_escape(domain)})
    exec_and_stream(cmd)
  end

  def list_blocked_domains
    require_container_cli!
    ensure_container_running!
    cmd = %(docker exec #{@cfg['container_name']} /usr/local/bin/pihole -b -l)
    exec_and_stream(cmd)
  end

  def bulk_block(file_path)
    domains = read_lines_file(file_path)
    puts "Blocking #{domains.size} domains..."
    domains.each { |d| block_domain(d) }
  end

  def bulk_unblock(file_path)
    domains = read_lines_file(file_path)
    puts "Unblocking #{domains.size} domains..."
    domains.each { |d| unblock_domain(d) }
  end

  def logs
    require_container_cli!
    name = @cfg['container_name']
    cmd = %(docker logs #{name} --tail 200)
    exec_and_stream(cmd)
  end

  def query_logs
    require_container_cli!
    ensure_container_running!
    cmd = %(docker exec #{@cfg['container_name']} tail -n 200 /var/log/pihole/pihole.log)
    exec_and_stream(cmd)
  end

  def stats
    require_container_cli!
    ensure_container_running!
    # Use pihole console stats; -c prints summary to console
    cmd = %(docker exec #{@cfg['container_name']} /usr/local/bin/pihole -c -e)
    exec_and_stream(cmd)
  end

  def open_web
    url = if @cfg['host_ip'] && !@cfg['host_ip'].empty?
            "http://#{@cfg['host_ip']}/admin"
          else
            "http://localhost:#{@cfg['web_port']}/admin"
          end
    puts "Opening #{url}"
    system('open', url)
  end

  def backup(dest_path)
    ensure_directories
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dest = File.directory?(dest_path) ? File.join(dest_path, "pihole_backup_#{timestamp}.tar.gz") : dest_path
    src1 = @cfg['etc_pihole']
    src2 = @cfg['etc_dnsmasq']
    puts "Creating backup at #{dest}"
    FileUtils.mkdir_p(File.dirname(dest))
    cmd = %(sudo tar -czf #{shell_escape(dest)} -C / #{shell_escape(src1[1..])} #{shell_escape(src2[1..])})
    ok = run_system(cmd)
    puts(ok ? 'Backup created.' : 'Backup failed.')
  end

  def restore(src_archive)
    unless File.file?(src_archive)
      puts "Archive not found: #{src_archive}"
      return
    end
    ensure_directories
    puts "Restoring from #{src_archive}"
    cmd = %(sudo tar -xzf #{shell_escape(src_archive)} -C /)
    ok = run_system(cmd)
    puts(ok ? 'Restore completed.' : 'Restore failed.')
  end

  def view_config
    load_config # refresh
    puts JSON.pretty_generate(@cfg)
  end

  def change_admin_password
    ensure_container_running!
    print 'Enter new admin password: '
    new_pw = STDIN.noecho(&:gets)&.strip
    puts
    if new_pw.nil? || new_pw.empty?
      puts 'Password cannot be empty.'
      return
    end
    @cfg['web_password'] = new_pw
    save_config
    # Update running container env by executing pihole command
    cmd = %(docker exec #{@cfg['container_name']} /usr/local/bin/pihole -a -p #{shell_escape(new_pw)} #{shell_escape(new_pw)})
    exec_and_stream(cmd)
    puts 'Admin password updated.'
  end

  def pihole_setpassword
    require_container_cli!
    ensure_container_running!
    log 'Running pihole setpassword interactively'
    puts 'Running interactive password setup inside Pi-hole container...'
    puts color(:yellow, 'Note: You will be prompted to enter the password twice for confirmation.')
    puts
    
    # Run pihole setpassword interactively
    cmd = %(docker exec -it #{@cfg['container_name']} pihole setpassword)
    system(cmd)
    
    if $?.success?
      puts
      puts color(:green, 'Password updated successfully!')
      puts 'You may want to save this password to the manager config:'
      print 'Update manager config with new password? [y/N]: '
      if STDIN.gets&.strip&.downcase&.start_with?('y')
        print 'Enter the password you just set: '
        new_pw = STDIN.noecho(&:gets)&.strip
        puts
        unless new_pw.empty?
          @cfg['web_password'] = new_pw
          save_config
          puts 'Manager config updated.'
        end
      end
    else
      puts
      puts color(:red, 'Failed to update password. Check container status.')
    end
  end

  def pihole_cli(*args)
    require_container_cli!
    ensure_container_running!
    
    if args.empty?
      puts 'Entering interactive Pi-hole CLI...'
      puts color(:yellow, 'Type "exit" or press Ctrl+D to return to manager.')
      puts 'Available commands: help, version, status, chronometer, query, etc.'
      puts
      log 'Starting interactive pihole CLI session'
      cmd = %(docker exec -it #{@cfg['container_name']} pihole)
    else
      pihole_cmd = args.join(' ')
      log "Running pihole CLI command: #{pihole_cmd}"
      cmd = %(docker exec -it #{@cfg['container_name']} pihole #{pihole_cmd})
    end
    
    system(cmd)
  end

  def update_timezone
    print 'Enter timezone (e.g., America/New_York): '
    tz = STDIN.gets&.strip
    if tz.nil? || tz.empty?
      puts 'Timezone not changed.'
      return
    end
    @cfg['timezone'] = tz
    save_config
    puts 'Timezone saved. Restart container to apply.'
  end

  # --------------- Interactive Menu -----------------

  def menu
    loop do
      clear_screen
      header_status = container_status
      puts color(:bold, '==== Pi-hole Container Manager ====')
      puts "Status: #{header_status}"
      puts
      puts '1. Container Management'
      puts '2. Domain Management'
      puts '3. Configuration'
      puts '4. Logs & Monitoring'
      puts '5. Advanced Options'
      puts '0. Exit'
      print '\nEnter your choice: '
      case STDIN.gets&.strip
      when '1' then menu_container
      when '2' then menu_domain
      when '3' then menu_config
      when '4' then menu_logs
      when '5' then menu_advanced
      when '0', nil then break
      else
        puts 'Invalid choice.'
        wait_key
      end
    end
  end

  def menu_container
    loop do
      clear_screen
      puts color(:cyan, '==== Container Management ====')
      puts 'a. Install Pi-hole'
      puts 'b. Start container'
      puts 'c. Stop container'
      puts 'd. Restart container'
      puts 'e. Update container'
      puts 'f. Show status'
      puts 'x. Back'
      print '\nEnter your choice: '
      case STDIN.gets&.strip&.downcase
      when 'a' then install
      when 'b' then start_container
      when 'c' then stop_container
      when 'd' then restart_container
      when 'e' then update_container
      when 'f' then status_container
      when 'x', nil then break
      else puts 'Invalid choice.'
      end
      wait_key
    end
  end

  def menu_domain
    loop do
      clear_screen
      puts color(:cyan, '==== Domain Management ====')
      puts 'a. Block domain'
      puts 'b. Unblock domain'
      puts 'c. List blocked domains'
      puts 'd. Bulk block domains (from file)'
      puts 'e. Bulk unblock domains (from file)'
      puts 'x. Back'
      print '\nEnter your choice: '
      case STDIN.gets&.strip&.downcase
      when 'a'
        print 'Enter domain to block: '
        d = STDIN.gets&.strip
        block_domain(d) if d && !d.empty?
      when 'b'
        print 'Enter domain to unblock: '
        d = STDIN.gets&.strip
        unblock_domain(d) if d && !d.empty?
      when 'c' then list_blocked_domains
      when 'd'
        print 'Enter path to file: '
        f = STDIN.gets&.strip
        bulk_block(f) if f && !f.empty?
      when 'e'
        print 'Enter path to file: '
        f = STDIN.gets&.strip
        bulk_unblock(f) if f && !f.empty?
      when 'x', nil then break
      else puts 'Invalid choice.'
      end
      wait_key
    end
  end

  def menu_config
    loop do
      clear_screen
      puts color(:cyan, '==== Configuration ====')
      puts 'a. View current settings'
      puts 'b. Change admin password'
      puts 'c. Interactive password setup (pihole setpassword)'
      puts 'd. Update timezone'
      puts 'e. Export configuration (backup)'
      puts 'f. Import configuration (restore)'
      puts 'x. Back'
      print '\nEnter your choice: '
      case STDIN.gets&.strip&.downcase
      when 'a' then view_config
      when 'b' then change_admin_password
      when 'c' then pihole_setpassword
      when 'd' then update_timezone
      when 'e'
        print 'Enter destination path (dir or file): '
        p = STDIN.gets&.strip
        backup(p) if p && !p.empty?
      when 'f'
        print 'Enter archive path: '
        p = STDIN.gets&.strip
        restore(p) if p && !p.empty?
      when 'x', nil then break
      else puts 'Invalid choice.'
      end
      wait_key
    end
  end

  def menu_logs
    loop do
      clear_screen
      puts color(:cyan, '==== Logs & Monitoring ====')
      puts 'a. View container logs'
      puts 'b. View Pi-hole query logs'
      puts 'c. Show DNS statistics'
      puts 'x. Back'
      print '\nEnter your choice: '
      case STDIN.gets&.strip&.downcase
      when 'a' then logs
      when 'b' then query_logs
      when 'c' then stats
      when 'x', nil then break
      else puts 'Invalid choice.'
      end
      wait_key
    end
  end

  def menu_advanced
    loop do
      clear_screen
      puts color(:cyan, '==== Advanced Options ====')
      puts 'a. Pi-hole CLI (interactive)'
      puts 'b. Container shell (bash)'
      puts 'c. Open web interface'
      puts 'x. Back'
      print '\nEnter your choice: '
      case STDIN.gets&.strip&.downcase
      when 'a' then pihole_cli
      when 'b'
        ensure_container_running!
        puts 'Opening container shell...'
        system("docker", "exec", "-it", @cfg['container_name'], "/bin/bash")
      when 'c' then open_web
      when 'x', nil then break
      else puts 'Invalid choice.'
      end
      wait_key
    end
  end

  # --------------- Helpers -----------------

  def require_container_cli!
    return if container_cli_available?

    puts color(:red, "Docker CLI 'docker' is not installed or not in PATH.")
    puts "Install Docker Desktop for Mac from: https://www.docker.com/products/docker-desktop/"
    puts "Or install Docker via Homebrew: brew install --cask docker"
    puts "Verify installation with 'docker --version'"
    exit 1
  end

  def container_cli_available?
    system('bash', '-lc', 'command -v docker >/dev/null 2>&1')
  end

  def ensure_directories
    [@cfg['config_root'], @cfg['etc_pihole'], @cfg['etc_dnsmasq']].each do |dir|
      next if Dir.exist?(dir)
      run_system(%(sudo mkdir -p #{shell_escape(dir)}))
    end
    # Ensure log file can be created
    ensure_log_dir
  end

  def ensure_log_dir
    FileUtils.mkdir_p(File.dirname(@cfg['log_file']))
  end

  def check_ports_available_or_warn
    ports = [@cfg['dns_port'], @cfg['web_port']]
    used = []
    ports.each do |p|
      cmd = %(sudo lsof -nP -i :#{p} -sTCP:LISTEN 2>/dev/null | wc -l)
      out, _ = run_capture(cmd)
      used << p if out.to_i > 0
    end
    return if used.empty?

    puts color(:yellow, "Warning: These ports are in use: #{used.join(', ')}")
    puts 'You may need to stop conflicting services before proceeding.'
  end

  def prompt_for_initial_config
    puts '=== Initial Configuration ==='
    print "Timezone [#{@cfg['timezone']}]: "
    tz = STDIN.gets&.strip
    @cfg['timezone'] = tz unless tz.nil? || tz.empty?

    print 'Admin password (leave blank to auto-generate): '
    pw = STDIN.noecho(&:gets)&.strip
    puts
    if pw.nil? || pw.empty?
      pw = generate_password(16)
      puts "Generated password: #{pw}"
    end
    @cfg['web_password'] = pw

    print 'Host static IP (optional, for web open): '
    ip = STDIN.gets&.strip
    @cfg['host_ip'] = ip unless ip.nil? || ip.empty?

    save_config
  end

  def save_config
    FileUtils.mkdir_p(File.dirname(@config_path))
    File.write(@config_path, JSON.pretty_generate(@cfg))
  end

  def load_config
    if File.file?(@config_path)
      json = JSON.parse(File.read(@config_path))
      @cfg.merge!(json)
    end
  rescue JSON::ParserError
    # Ignore and keep defaults
  end

  def container_exists?
    name = @cfg['container_name']
    out, _ = run_capture(%(docker ps -a --format "{{.Names}}" 2>/dev/null))
    out.include?(name)
  end

  def container_running?
    name = @cfg['container_name']
    out, _ = run_capture(%(docker ps --format "{{.Names}}" 2>/dev/null))
    out.include?(name)
  end

  def container_status
    if container_running?
      'Running'
    elsif container_exists?
      'Stopped'
    else
      'Not Installed'
    end
  end

  def remove_container(silent: false)
    name = @cfg['container_name']
    return unless container_exists?

    log 'Removing container'
    ok = run_system(%(docker rm -f #{name} 2>/dev/null))
    puts(ok ? 'Container removed.' : 'Failed to remove container.') unless silent
  end

  def run_container
    name = @cfg['container_name']
    env_tz = @cfg['timezone']
    env_pw = @cfg['web_password'] || ''

    ensure_directories

    parts = []
    parts << 'docker run'
    parts << "--name #{name}"
    parts << "--detach"  # Run in background
    parts << "--restart unless-stopped"  # Auto-restart policy
    
    # Port mappings for DNS and web interface
    parts << "--publish #{@cfg['dns_port']}:53/tcp"
    parts << "--publish #{@cfg['dns_port']}:53/udp"
    parts << "--publish #{@cfg['web_port']}:80/tcp"
    
    # Volume mounts for configuration persistence
    parts << "--volume #{shell_escape(@cfg['etc_pihole'])}:/etc/pihole"
    parts << "--volume #{shell_escape(@cfg['etc_dnsmasq'])}:/etc/dnsmasq.d"
    
    # Environment variables
    parts << "--env TZ=#{shell_escape(env_tz)}"
    parts << "--env WEBPASSWORD=#{shell_escape(env_pw)}"
    
    parts << @cfg['image']

    cmd = parts.join(' ')
    log "Running container: #{cmd}"
    ok = run_system(cmd)
    if ok
      puts 'Pi-hole container is now running.'
      puts "Web interface: http://#{@cfg['host_ip']&.empty? ? 'localhost' : @cfg['host_ip']}:#{@cfg['web_port']}/admin"
    else
      puts color(:red, 'Failed to run Pi-hole container. See logs for details.')
      puts color(:yellow, 'Note: Make sure Docker is running and ports 53 and 80 are available.')
      puts color(:yellow, 'Check if another Pi-hole container already exists with: docker ps -a')
    end
  end

  def ensure_container_running!
    unless container_running?
      puts color(:yellow, 'Container is not running.')
      exit 1
    end
  end

  def validate_domain!(domain)
    if domain.nil? || domain.strip.empty?
      puts 'Domain is required.'
      exit 1
    end
  end

  def read_lines_file(path)
    unless File.file?(path)
      puts "File not found: #{path}"
      exit 1
    end
    File.read(path).lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') }
  end

  def yes?(prompt)
    print "#{prompt} [y/N]: "
    ans = STDIN.gets&.strip&.downcase
    ans == 'y' || ans == 'yes'
  end

  def clear_screen
    system('clear')
  end

  def wait_key
    print '\nPress Enter to continue...'
    STDIN.gets
  end

  def post_install_message
    puts
    puts color(:green, '✓ Pi-hole installation completed successfully!')
    puts
    puts 'Next steps:'
    puts "1. Web Interface: http://#{@cfg['host_ip'] || 'localhost'}:#{@cfg['web_port']}"
    puts "2. Set your router's DNS to: #{@cfg['host_ip'] || 'this-machine-ip'}"
    puts "3. Or configure individual devices to use this DNS server"
    puts
    puts 'You can now:'
    puts '• Use the interactive menu: ruby pihole_manager.rb'
    puts '• Block domains: ruby pihole_manager.rb block example.com'
    puts '• View status: ruby pihole_manager.rb status'
    puts
    puts "Admin password: #{@cfg['web_password'] || '(not set)'}"
    puts "Log file: #{@cfg['log_file']}"
    puts
  end

  def log(message)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    line = "[#{timestamp}] #{message}\n"
    
    begin
      File.open(@cfg['log_file'], 'a') { |f| f.write(line) }
    rescue Errno::EACCES, Errno::ENOENT => e
      # If we can't write to the configured log file, try a fallback location
      fallback_log = File.expand_path('~/pihole-manager.log')
      begin
        File.open(fallback_log, 'a') { |f| f.write(line) }
        @cfg['log_file'] = fallback_log if @cfg['log_file'] != fallback_log
      rescue => fallback_error
        # If all else fails, just output to stdout
        $stderr.puts "Warning: Cannot write to log file (#{e.message}). Falling back to stdout."
      end
    end
    
    puts line if @cfg['verbose']
  end

  def run_system(cmd)
    log "EXEC: #{cmd}"
    system(cmd).tap do |ok|
      log(" -> #{ok ? 'OK' : 'FAIL'}")
    end
  end

  def run_capture(cmd)
    log "CAPTURE: #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)
    log " -> exit #{status.exitstatus}"
    [stdout, stderr]
  end

  def exec_and_stream(cmd)
    log "STREAM: #{cmd}"
    Open3.popen3(cmd) do |_, stdout, stderr, wait_thr|
      Thread.new { stdout.each_line { |l| print l } }
      Thread.new { stderr.each_line { |l| print l } }
      wait_thr.value
    end
  end

  def generate_password(length)
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    Array.new(length) { chars.sample }.join
  end

  def shell_escape(str)
    # Simple escape for args in our usage context
    return "''" if str.nil? || str.empty?
    str = str.to_s
    if str =~ /[^A-Za-z0-9_\-\.:\/@]/
      "'#{str.gsub("'", "'\\''")}'"
    else
      str
    end
  end
end

# --------------- CLI Entrypoint -----------------

def print_help
  puts <<~USAGE
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

      backup <path>                Backup configuration to path (dir or .tar.gz)
      restore <archive>            Restore configuration from archive

      logs                         View container logs
      query-logs                   View Pi-hole query logs
      stats                        Show DNS statistics
      web                          Open web interface
      setpassword                  Interactive password setup (pihole setpassword)
      cli [command]                Access Pi-hole CLI directly (e.g., cli help, cli status)

      menu                         Launch interactive menu

    Options:
      --config <file>              Use custom config file
      --verbose                    Enable verbose output
      --version                    Show script version
      --help                       Show this help
  USAGE
end

# Parse options
config_path = nil
verbose = false
args = ARGV.dup

# Extract global options
parsed = []
while (arg = args.shift)
  case arg
  when '--help'
    print_help
    exit 0
  when '--version'
    puts PiHoleManager::SCRIPT_VERSION
    exit 0
  when '--verbose'
    verbose = true
  when '--config'
    config_path = args.shift
    if config_path.nil?
      warn "--config requires a path"
      exit 1
    end
  else
    parsed << arg
  end
end

cmd = parsed.shift
manager = PiHoleManager.new(config_path: config_path, verbose: verbose)

if cmd.nil? || cmd == 'menu'
  manager.menu
  exit 0
end

# Direct commands
case cmd
when 'install' then manager.install
when 'start' then manager.start_container
when 'stop' then manager.stop_container
when 'restart' then manager.restart_container
when 'status' then manager.status_container
when 'update' then manager.update_container
when 'block' then manager.block_domain(parsed[0])
when 'unblock' then manager.unblock_domain(parsed[0])
when 'list-blocked' then manager.list_blocked_domains
when 'bulk-block' then manager.bulk_block(parsed[0])
when 'bulk-unblock' then manager.bulk_unblock(parsed[0])
when 'backup' then manager.backup(parsed[0])
when 'restore' then manager.restore(parsed[0])
when 'logs' then manager.logs
when 'query-logs' then manager.query_logs
when 'stats' then manager.stats
when 'web' then manager.open_web
when 'setpassword' then manager.pihole_setpassword
when 'cli' then manager.pihole_cli(*parsed)
else
  warn "Unknown command: #{cmd}"
  print_help
  exit 1
end
