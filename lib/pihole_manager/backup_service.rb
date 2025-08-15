# frozen_string_literal: true

require 'fileutils'

module PiHoleManager
  # Single Responsibility: Backup and restore operations
  class BackupService
    def initialize(config, logger, ui)
      @config = config
      @logger = logger
      @ui = ui
    end

    def backup(destination_path)
      @logger.log "Creating backup to: #{destination_path}"
      
      if destination_path.end_with?('.tar.gz')
        backup_to_archive(destination_path)
      else
        backup_to_directory(destination_path)
      end
    end

    def restore(archive_path)
      unless File.exist?(archive_path)
        @ui.puts_error("Archive not found: #{archive_path}")
        return
      end

      @logger.log "Restoring from: #{archive_path}"
      
      if archive_path.end_with?('.tar.gz')
        restore_from_archive(archive_path)
      else
        @ui.puts_error("Unsupported archive format. Only .tar.gz is supported.")
      end
    end

    private

    def backup_to_directory(destination_path)
      FileUtils.mkdir_p(destination_path)
      
      # Copy Pi-hole configuration files
      source_dirs = [@config['etc_pihole'], @config['etc_dnsmasq']]
      
      source_dirs.each do |source_dir|
        next unless Dir.exist?(source_dir)
        
        dest_subdir = File.join(destination_path, File.basename(source_dir))
        FileUtils.cp_r(source_dir, dest_subdir)
        @ui.puts "Copied #{source_dir} to #{dest_subdir}"
      end

      # Copy manager configuration
      if File.exist?(@config.config_path)
        FileUtils.cp(@config.config_path, destination_path)
        @ui.puts "Copied manager config to #{destination_path}"
      end

      @ui.puts_success("Backup completed to directory: #{destination_path}")
    end

    def backup_to_archive(destination_path)
      temp_dir = "/tmp/pihole_backup_#{Time.now.to_i}"
      
      begin
        backup_to_directory(temp_dir)
        
        # Create tar.gz archive
        cmd = %(tar -czf #{shell_escape(destination_path)} -C #{shell_escape(File.dirname(temp_dir))} #{shell_escape(File.basename(temp_dir))})
        
        if system(cmd)
          @ui.puts_success("Backup archive created: #{destination_path}")
        else
          @ui.puts_error("Failed to create backup archive")
        end
      ensure
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    def restore_from_archive(archive_path)
      temp_dir = "/tmp/pihole_restore_#{Time.now.to_i}"
      
      begin
        FileUtils.mkdir_p(temp_dir)
        
        # Extract archive
        cmd = %(tar -xzf #{shell_escape(archive_path)} -C #{shell_escape(temp_dir)})
        
        unless system(cmd)
          @ui.puts_error("Failed to extract archive")
          return
        end

        # Find the backup directory in the extracted content
        extracted_dirs = Dir.glob(File.join(temp_dir, '*')).select { |d| File.directory?(d) }
        
        if extracted_dirs.empty?
          @ui.puts_error("No backup directory found in archive")
          return
        end

        backup_dir = extracted_dirs.first
        restore_from_directory(backup_dir)
        
      ensure
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    def restore_from_directory(backup_dir)
      unless Dir.exist?(backup_dir)
        @ui.puts_error("Backup directory not found: #{backup_dir}")
        return
      end

      # Restore Pi-hole configuration directories
      config_subdirs = ['etc-pihole', 'etc-dnsmasq.d']
      
      config_subdirs.each do |subdir|
        source_path = File.join(backup_dir, subdir)
        dest_path = @config[subdir.tr('-', '_')]
        
        next unless Dir.exist?(source_path)
        
        # Backup existing directory
        if Dir.exist?(dest_path)
          backup_existing = "#{dest_path}.backup.#{Time.now.to_i}"
          FileUtils.mv(dest_path, backup_existing)
          @ui.puts "Backed up existing #{dest_path} to #{backup_existing}"
        end

        FileUtils.cp_r(source_path, dest_path)
        @ui.puts "Restored #{source_path} to #{dest_path}"
      end

      # Restore manager configuration
      manager_config = File.join(backup_dir, 'manager_config.json')
      if File.exist?(manager_config)
        FileUtils.cp(manager_config, @config.config_path)
        @config.load_config
        @ui.puts "Restored manager configuration"
      end

      @ui.puts_success("Restore completed from: #{backup_dir}")
      @ui.puts_warning("Note: Restart the container to apply restored configuration.")
    end

    def shell_escape(str)
      "'#{str.to_s.gsub("'", "'\\''")}'"
    end
  end
end
