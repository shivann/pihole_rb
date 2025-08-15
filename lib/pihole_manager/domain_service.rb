# frozen_string_literal: true

module PiHoleManager
  # Single Responsibility: Domain blocking/unblocking operations
  class DomainService
    def initialize(container, logger, ui)
      @container = container
      @logger = logger
      @ui = ui
    end

    def block_domain(domain)
      validate_domain!(domain)
      @logger.log "Blocking domain: #{domain}"
      @container.execute_command("pihole deny #{shell_escape(domain)}")
    end

    def unblock_domain(domain)
      validate_domain!(domain)
      @logger.log "Unblocking domain: #{domain}"
      @container.execute_command("pihole deny remove #{shell_escape(domain)}")
    end

    def list_blocked_domains
      @ui.puts "Listing blocked domains..."
      # Try the modern command first, fall back to showing where domains are stored
      begin
        @container.execute_command("pihole deny -l")
      rescue
        @ui.puts_warning("Unable to list domains with Pi-hole CLI.")
        @ui.puts "You can view blocked domains in the Pi-hole web interface:"
        @ui.puts "Go to: http://your-pihole-ip/admin -> Group Management -> Domains"
      end
    end

    def bulk_block(file_path)
      domains = read_domains_file(file_path)
      @ui.puts "Blocking #{domains.size} domains from #{file_path}..."
      
      domains.each_with_index do |domain, index|
        @ui.print "#{index + 1}/#{domains.size}: #{domain}... "
        begin
          block_domain(domain)
          @ui.puts_success("OK")
        rescue => e
          @ui.puts_error("FAILED: #{e.message}")
        end
      end
    end

    def bulk_unblock(file_path)
      domains = read_domains_file(file_path)
      @ui.puts "Unblocking #{domains.size} domains from #{file_path}..."
      
      domains.each_with_index do |domain, index|
        @ui.print "#{index + 1}/#{domains.size}: #{domain}... "
        begin
          unblock_domain(domain)
          @ui.puts_success("OK")
        rescue => e
          @ui.puts_error("FAILED: #{e.message}")
        end
      end
    end

    private

    def validate_domain!(domain)
      if domain.nil? || domain.strip.empty?
        raise ArgumentError, 'Domain cannot be empty'
      end
      
      # Basic domain validation
      unless domain.match?(/\A[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\z/)
        raise ArgumentError, "Invalid domain format: #{domain}"
      end
    end

    def read_domains_file(file_path)
      unless File.exist?(file_path)
        raise ArgumentError, "File not found: #{file_path}"
      end

      domains = File.readlines(file_path).map(&:strip).reject(&:empty?)
      if domains.empty?
        raise ArgumentError, "No domains found in file: #{file_path}"
      end

      domains
    end

    def shell_escape(str)
      "'#{str.to_s.gsub("'", "'\\''")}'"
    end
  end
end
