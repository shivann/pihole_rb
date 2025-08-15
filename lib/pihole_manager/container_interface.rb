# frozen_string_literal: true

module PiHoleManager
  # Interface Segregation: Container operations interface
  module ContainerInterface
    def start_container
      raise NotImplementedError, 'Subclasses must implement start_container'
    end

    def stop_container
      raise NotImplementedError, 'Subclasses must implement stop_container'
    end

    def restart_container
      raise NotImplementedError, 'Subclasses must implement restart_container'
    end

    def container_exists?
      raise NotImplementedError, 'Subclasses must implement container_exists?'
    end

    def container_running?
      raise NotImplementedError, 'Subclasses must implement container_running?'
    end

    def create_container
      raise NotImplementedError, 'Subclasses must implement create_container'
    end

    def remove_container
      raise NotImplementedError, 'Subclasses must implement remove_container'
    end

    def execute_command(command)
      raise NotImplementedError, 'Subclasses must implement execute_command'
    end

    def get_logs
      raise NotImplementedError, 'Subclasses must implement get_logs'
    end
  end
end
