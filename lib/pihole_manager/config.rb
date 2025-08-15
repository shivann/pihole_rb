# frozen_string_literal: true

require 'json'
require 'fileutils'

module PiHoleManager
  # Single Responsibility: Configuration management
  class Config
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

    attr_reader :config_path, :data

    def initialize(config_path: nil, verbose: false)
      @config_path = config_path || DEFAULTS['config_file']
      @data = DEFAULTS.dup
      load_config
      @data['verbose'] = verbose || @data['verbose']
      ensure_log_dir
    end

    def load_config
      return unless File.exist?(@config_path)

      begin
        content = File.read(@config_path)
        loaded = JSON.parse(content)
        @data.merge!(loaded) if loaded.is_a?(Hash)
      rescue JSON::ParserError, StandardError
        # Ignore errors and keep defaults
      end
    end

    def save_config
      ensure_log_dir
      File.write(@config_path, JSON.pretty_generate(@data))
    end

    def get(key)
      @data[key]
    end

    def set(key, value)
      @data[key] = value
    end

    def [](key)
      get(key)
    end

    def []=(key, value)
      set(key, value)
    end

    private

    def ensure_log_dir
      FileUtils.mkdir_p(File.dirname(@data['log_file']))
      FileUtils.mkdir_p(File.dirname(@config_path))
    end
  end
end
