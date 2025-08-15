# Pi-hole Manager SOLID Refactoring Guide

This document explains how the Pi-hole Container Manager was refactored following SOLID design principles.

## Original Issues

The original `pihole_manager.rb` violated several SOLID principles:

1. **Single Responsibility Violation**: One large class handled everything (container management, UI, logging, configuration, domain management, etc.)
2. **Open/Closed Violation**: Adding new container runtimes required modifying existing code
3. **Interface Segregation Violation**: Clients were forced to depend on methods they didn't use
4. **Dependency Inversion Violation**: High-level modules depended on low-level implementation details

## SOLID Principles Applied

### 1. Single Responsibility Principle (SRP)

Each class now has a single reason to change:

- **`Config`**: Configuration management only
- **`Logger`**: Logging functionality only  
- **`UI`**: User interface and terminal interactions only
- **`DockerContainer`**: Docker-specific container operations only
- **`DomainService`**: Domain blocking/unblocking operations only
- **`InstallationService`**: Pi-hole installation and setup only
- **`PiHoleService`**: Pi-hole specific operations only
- **`BackupService`**: Backup and restore operations only
- **`MenuSystem`**: Menu navigation and display only
- **`Application`**: Application flow control and service coordination only

### 2. Open/Closed Principle (OCP)

The system is now open for extension but closed for modification:

- **Container Interface**: `ContainerInterface` defines the contract for container operations
- **Multiple Implementations**: Easy to add support for Podman, Containerd, etc. by implementing the interface
- **Service Extension**: New services can be added without modifying existing ones

### 3. Liskov Substitution Principle (LSP)

Container implementations are interchangeable:

- Any class implementing `ContainerInterface` can be substituted without breaking the application
- `DockerContainer` can be replaced with `PodmanContainer` without changing dependent code

### 4. Interface Segregation Principle (ISP)

Interfaces are focused and specific:

- **`ContainerInterface`**: Only container-related operations
- Services only depend on the methods they actually use
- No "fat interfaces" that force unnecessary dependencies

### 5. Dependency Inversion Principle (DIP)

High-level modules don't depend on low-level modules:

- **`Application`** depends on abstractions (services) not concrete implementations
- **Dependency Injection**: All dependencies are injected through constructors
- **Inversion of Control**: The main application coordinates services rather than services calling each other directly

## New Architecture

```
Application (High-level coordination)
├── Config (Configuration management)
├── Logger (Logging)
├── UI (User interface)
├── DockerContainer (implements ContainerInterface)
├── DomainService (Domain operations)
├── InstallationService (Installation logic)
├── PiHoleService (Pi-hole specific operations)
├── BackupService (Backup/restore operations)
└── MenuSystem (Menu navigation)
```

## Benefits of Refactoring

### 1. Maintainability
- **Easier to understand**: Each class has a clear, single purpose
- **Easier to modify**: Changes to one concern don't affect others
- **Better organization**: Related functionality is grouped together

### 2. Testability
- **Unit testing**: Each class can be tested in isolation
- **Mocking**: Dependencies can be easily mocked for testing
- **Test coverage**: Smaller classes are easier to test thoroughly

### 3. Extensibility
- **New container runtimes**: Implement `ContainerInterface` for Podman, Containerd, etc.
- **New services**: Add new services without modifying existing code
- **New UI types**: Replace `UI` with web interface, API, etc.

### 4. Reusability
- **Service composition**: Services can be reused in different contexts
- **Modular design**: Individual services can be extracted for other projects
- **Flexible configuration**: Easy to swap implementations

## Usage Examples

### Basic Usage (Same as Original)
```bash
# All original commands work exactly the same
ruby pihole_manager.rb --help
ruby pihole_manager.rb status
ruby pihole_manager.rb block ads.example.com
```

### Extending with New Container Runtime
```ruby
# Create new container implementation
class PodmanContainer
  include ContainerInterface
  
  def start_container
    # Podman-specific implementation
  end
  
  # ... other interface methods
end

# Use in application
app = Application.new
app.container = PodmanContainer.new(config, logger, ui)
```

### Custom Service Integration
```ruby
# Add new monitoring service
class MonitoringService
  def initialize(container, logger, ui)
    @container = container
    @logger = logger
    @ui = ui
  end
  
  def check_health
    # Custom health checking logic
  end
end

# Integrate into application
class Application
  def initialize(...)
    # ... existing setup
    @monitoring = MonitoringService.new(@container, @logger, @ui)
  end
  
  def health_check
    @monitoring.check_health
  end
end
```

## File Structure

```
lib/pihole_manager/
├── application.rb           # Main application coordinator
├── config.rb               # Configuration management
├── logger.rb               # Logging functionality
├── ui.rb                   # User interface
├── container_interface.rb  # Container operations interface
├── docker_container.rb     # Docker implementation
├── domain_service.rb       # Domain management
├── installation_service.rb # Installation logic
├── pihole_service.rb       # Pi-hole operations
├── backup_service.rb       # Backup/restore
└── menu_system.rb          # Menu navigation

pihole_manager.rb # Main entry point (refactored version)
```

## Migration Guide

✅ **Migration Complete**: The original monolithic script has been replaced with the refactored SOLID architecture.

The `pihole_manager.rb` file now uses the refactored architecture with:
- Modular class structure following SOLID principles
- Enhanced maintainability and testability
- All original functionality preserved
- Same command-line interface

## Conclusion

The refactored Pi-hole Manager demonstrates how SOLID principles lead to:
- **Better code organization**
- **Improved maintainability**
- **Enhanced testability**
- **Greater extensibility**

While the refactored version has more files and classes, each piece is simpler, more focused, and easier to understand. This trade-off of complexity distribution (many simple classes vs. one complex class) is a hallmark of good object-oriented design.
