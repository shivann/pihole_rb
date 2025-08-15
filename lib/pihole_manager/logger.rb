# frozen_string_literal: true

module PiHoleManager
  # Single Responsibility: Logging functionality
  class Logger
    def initialize(config)
      @config = config
    end

    def log(message)
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      line = "[#{timestamp}] #{message}\n"
      
      begin
        File.open(@config['log_file'], 'a') { |f| f.write(line) }
      rescue Errno::EACCES, Errno::ENOENT => e
        # If we can't write to the configured log file, try a fallback location
        fallback_log = File.expand_path('~/pihole-manager.log')
        begin
          File.open(fallback_log, 'a') { |f| f.write(line) }
          @config['log_file'] = fallback_log if @config['log_file'] != fallback_log
        rescue => fallback_error
          # If all else fails, just output to stdout
          $stderr.puts "Warning: Cannot write to log file (#{e.message}). Falling back to stdout."
        end
      end
      
      puts line if @config['verbose']
    end
  end
end
