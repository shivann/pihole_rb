# frozen_string_literal: true

require 'open3'
require_relative 'container_interface'

module PiHoleManager
  # Single Responsibility: Docker container operations
  # Open/Closed Principle: Implements ContainerInterface, extensible for other container runtimes
  class DockerContainer
    include ContainerInterface

    def initialize(config, logger, ui)
      @config = config
      @logger = logger
      @ui = ui
    end

    def start_container(silent: false)
      return @ui.puts_info('Container is already running.') if container_running? && !silent

      if container_exists?
        cmd = %(docker start #{@config['container_name']})
        ok = run_system(cmd)
        @ui.puts(ok ? 'Container started.' : 'Failed to start container.') unless silent
      else
        @ui.puts_info('Container does not exist. Creating a new one...')
        create_container
      end
    end

    def stop_container(silent: false)
      return @ui.puts_info('Container is not running.') unless container_running?

      cmd = %(docker stop #{@config['container_name']})
      ok = run_system(cmd)
      @ui.puts(ok ? 'Container stopped.' : 'Failed to stop container.') unless silent
    end

    def restart_container
      @logger.log('Restarting container')
      stop_container(silent: true) if container_running?
      start_container
    end

    def container_exists?
      name = @config['container_name']
      out, _ = run_capture(%(docker ps -a --format "{{.Names}}" 2>/dev/null))
      out.include?(name)
    end

    def container_running?
      name = @config['container_name']
      out, _ = run_capture(%(docker ps --format "{{.Names}}" 2>/dev/null))
      out.include?(name)
    end

    def create_container
      ensure_directories
      name = @config['container_name']
      env_tz = @config['timezone']
      env_pw = @config['web_password'] || ''

      parts = []
      parts << 'docker run'
      parts << "--name #{name}"
      parts << "--detach"
      parts << "--restart unless-stopped"
      
      # Port mappings for DNS and web interface
      parts << "--publish #{@config['dns_port']}:53/tcp"
      parts << "--publish #{@config['dns_port']}:53/udp"
      parts << "--publish #{@config['web_port']}:80/tcp"
      
      # Volume mounts for configuration persistence
      parts << "--volume #{shell_escape(@config['etc_pihole'])}:/etc/pihole"
      parts << "--volume #{shell_escape(@config['etc_dnsmasq'])}:/etc/dnsmasq.d"
      
      # Environment variables
      parts << "--env TZ=#{shell_escape(env_tz)}"
      parts << "--env WEBPASSWORD=#{shell_escape(env_pw)}"
      
      parts << @config['image']

      cmd = parts.join(' ')
      @logger.log "Running container: #{cmd}"
      ok = run_system(cmd)
      
      if ok
        @ui.puts_success('Pi-hole container is now running.')
        host_display = @config['host_ip']&.empty? ? 'localhost' : @config['host_ip']
        @ui.puts "Web interface: http://#{host_display}:#{@config['web_port']}/admin"
      else
        @ui.puts_error('Failed to run Pi-hole container. See logs for details.')
        @ui.puts_warning('Note: Make sure Docker is running and ports 53 and 80 are available.')
        @ui.puts_warning('Check if another Pi-hole container already exists with: docker ps -a')
      end
    end

    def remove_container(silent: false)
      name = @config['container_name']
      return unless container_exists?

      @logger.log 'Removing container'
      ok = run_system(%(docker rm -f #{name} 2>/dev/null))
      @ui.puts(ok ? 'Container removed.' : 'Failed to remove container.') unless silent
    end

    def execute_command(command, interactive: false)
      ensure_container_running!
      
      if interactive
        cmd = %(docker exec -it #{@config['container_name']} #{command})
        system(cmd)
      else
        cmd = %(docker exec #{@config['container_name']} #{command})
        exec_and_stream(cmd)
      end
    end

    def execute_command_capture(command)
      ensure_container_running!
      cmd = %(docker exec #{@config['container_name']} #{command})
      stdout, stderr, status = run_capture(cmd)
      
      if status.success?
        stdout
      else
        @logger.log "Command failed: #{cmd}, stderr: #{stderr}"
        nil
      end
    end

    def get_logs(tail_lines: 200)
      name = @config['container_name']
      cmd = %(docker logs #{name} --tail #{tail_lines})
      exec_and_stream(cmd)
    end

    def cli_available?
      system('bash', '-lc', 'command -v docker >/dev/null 2>&1')
    end

    def require_cli!
      return if cli_available?

      @ui.puts_error("Docker CLI 'docker' is not installed or not in PATH.")
      @ui.puts "Install Docker Desktop for Mac from: https://www.docker.com/products/docker-desktop/"
      @ui.puts "Or install Docker via Homebrew: brew install --cask docker"
      @ui.puts "Verify installation with 'docker --version'"
      exit 1
    end

    private

    def ensure_container_running!
      unless container_running?
        @ui.puts_warning('Container is not running.')
        raise StandardError, 'Container is not running'
      end
    end

    def ensure_directories
      [@config['config_root'], @config['etc_pihole'], @config['etc_dnsmasq']].each do |dir|
        next if Dir.exist?(dir)
        run_system(%(sudo mkdir -p #{shell_escape(dir)}))
      end
    end

    def shell_escape(str)
      "'#{str.to_s.gsub("'", "'\\''")}'"
    end

    def run_system(cmd)
      @logger.log "EXEC: #{cmd}"
      result = system(cmd)
      @logger.log(" -> #{result ? 'OK' : 'FAIL'}")
      result
    end

    def run_capture(cmd)
      @logger.log "CAPTURE: #{cmd}"
      Open3.capture3(cmd)
    end

    def exec_and_stream(cmd)
      @logger.log "STREAM: #{cmd}"
      system(cmd)
    end
  end
end
