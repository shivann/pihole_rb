# frozen_string_literal: true

require 'io/console'

module PiHoleManager
  # Single Responsibility: User interface and terminal interactions
  class UI
    COLOR = {
      reset: "\e[0m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      cyan: "\e[36m",
      bold: "\e[1m"
    }.freeze

    def initialize
    end

    # Terminal color formatting with fallback
    def color(type, text)
      if ENV['NO_COLOR'] || !$stdout.tty?
        text
      else
        "#{COLOR[type]}#{text}#{COLOR[:reset]}"
      end
    end

    def prompt(message)
      print message
      STDIN.gets&.strip
    end

    def prompt_password(message)
      print message
      STDIN.noecho(&:gets)&.strip.tap { puts }
    end

    def confirm(message)
      print "#{message} [y/N]: "
      ans = STDIN.gets&.strip&.downcase
      ans == 'y' || ans == 'yes'
    end

    def clear_screen
      system('clear')
    end

    def wait_for_key
      print '\nPress Enter to continue...'
      STDIN.gets
    end

    def puts(message = '')
      Kernel.puts(message)
    end

    def puts_error(message)
      puts color(:red, message)
    end

    def puts_success(message)
      puts color(:green, message)
    end

    def puts_warning(message)
      puts color(:yellow, message)
    end

    def puts_info(message)
      puts color(:cyan, message)
    end

    def print(message)
      Kernel.print(message)
    end
  end
end
