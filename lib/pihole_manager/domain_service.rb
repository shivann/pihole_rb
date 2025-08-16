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
      validate_domain_or_pattern!(domain)
      @logger.log "Blocking domain/pattern: #{domain}"
      @container.execute_command("pihole regex #{shell_escape(domain)}")
    end

    def unblock_domain(domain)
      validate_domain_or_pattern!(domain)
      @logger.log "Unblocking domain/pattern: #{domain}"
      @container.execute_command("pihole regex remove #{shell_escape(domain)}")
    end

    def list_blocked_domains
      @ui.puts "Listing blocked domains and regex patterns..."
      # List both exact domains and regex patterns
      begin
        @ui.puts @ui.color(:cyan, "=== Exact Domain Blocks ===")
        @container.execute_command("pihole deny -l")
        @ui.puts
        @ui.puts @ui.color(:cyan, "=== Regex Pattern Blocks ===")
        @container.execute_command("pihole regex -l")
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

    def show_regex_examples
      @ui.puts @ui.color(:cyan, "=== Common Regex Patterns for Domain Blocking ===")
      @ui.puts
      @ui.puts @ui.color(:bold, "Block all subdomains:")
      @ui.puts "  facebook\\.com$          # Blocks facebook.com and all subdomains"
      @ui.puts "  google\\.com$            # Blocks google.com and all subdomains"
      @ui.puts
      @ui.puts @ui.color(:bold, "Block specific patterns:")
      @ui.puts "  .*ads.*                  # Blocks any domain containing 'ads'"
      @ui.puts "  .*tracking.*             # Blocks any domain containing 'tracking'"
      @ui.puts "  .*analytics.*            # Blocks any domain containing 'analytics'"
      @ui.puts
      @ui.puts @ui.color(:bold, "Block by TLD:")
      @ui.puts "  \\.tk$                    # Blocks all .tk domains"
      @ui.puts "  \\.ml$                    # Blocks all .ml domains"
      @ui.puts
      @ui.puts @ui.color(:bold, "Block number-based domains:")
      @ui.puts "  ^[0-9]+\\.[a-z]+\\.com$   # Blocks domains like 123.example.com"
      @ui.puts
      @ui.puts @ui.color(:warning, "Note: Escape dots with \\\\ and end exact domains with $")
    end

    private

    def validate_domain_or_pattern!(input)
      if input.nil? || input.strip.empty?
        raise ArgumentError, 'Domain/pattern cannot be empty'
      end
      
      # Allow regex patterns (basic validation)
      if is_regex_pattern?(input)
        validate_regex_pattern!(input)
      else
        validate_domain!(input)
      end
    end

    def validate_domain!(domain)
      # Basic domain validation for exact domains
      unless domain.match?(/\A[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\z/)
        raise ArgumentError, "Invalid domain format: #{domain}"
      end
    end

    def is_regex_pattern?(input)
      # Check if input contains regex metacharacters
      input.match?(/[.*+?^${}()|\\]|\[|\]/)
    end

    def validate_regex_pattern!(pattern)
      begin
        # Test if it's a valid regex
        Regexp.new(pattern)
      rescue RegexpError => e
        raise ArgumentError, "Invalid regex pattern: #{e.message}"
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
