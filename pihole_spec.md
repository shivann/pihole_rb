# Pi-hole Docker Installation & Management Script Specification

## Overview
This specification describes a Ruby-based script to automate:
- Installation of Pi-hole inside a Docker container
- Configuration for DNS traffic management on a Mac mini
- Lifecycle management of the Pi-hole container
- Helper methods for client-specific domain blocking/unblocking

The script should be designed for **macOS** and assume the host is a **Mac mini** that will act as a DNS server for the home network.

---

## Requirements

### Language & Environment
- **Scripting Language**: Ruby (>= 3.0)
- Must run on **macOS** with full terminal support
- No external Ruby gems unless absolutely necessary
- Must interact with `docker` CLI
- Must handle Docker daemon requirements

### Pi-hole Container Details
- Container name: `pihole`
- Base image: `pihole/pihole:latest`
- Configuration paths (mounted from host):
  - `/opt/pihole/etc-pihole` → `/etc/pihole`
  - `/opt/pihole/etc-dnsmasq.d` → `/etc/dnsmasq.d`
- Web interface port: `80`
- DNS ports: `53/tcp` and `53/udp`
- Environment variables:
  - `TZ` (Time Zone, configurable)
  - `WEBPASSWORD` (Admin password, configurable)
- Restart policy: `unless-stopped` (automatic restart on system reboot)

---

## Script Capabilities

### 1. Installation & Setup
- **Check Dependencies**
  - Verify `docker` CLI is installed and Docker daemon is running
  - Verify network ports 53 and 80 are available
  - Verify directories for configuration exist, create if missing
- **Download Pi-hole Image**
  - Pull `pihole/pihole:latest` using `docker run` which automatically pulls if needed
- **Initial Configuration**
  - Prompt user for:
    - Timezone (`TZ`)
    - Admin password (`WEBPASSWORD`)
    - Static IP address for the host Mac mini
  - Generate container configuration file for reproducibility
- **Run Container**
  - Use `docker run` to start Pi-hole with the required port mappings, volume mounts, and environment variables

### 2. Lifecycle Methods
The script must include reusable helper methods:

```ruby
start_container     # Start the Pi-hole container
stop_container      # Stop the Pi-hole container
restart_container   # Restart the Pi-hole container
status_container    # Show running status of Pi-hole container
update_container    # Pull latest image and redeploy while preserving config
```

### 3. DNS Management Methods
Methods to manage domain blocking/unblocking from the host using `docker exec`:

```ruby
block_domain(domain)    # Block a domain using pihole -b
unblock_domain(domain)  # Unblock a domain using pihole -b -d
list_blocked_domains    # Show current blocked domains
```

### 4. Scheduling Support (Optional)
- Provide helper functions to schedule blocking/unblocking using macOS `launchd` jobs
- Allow setting time-based rules via script arguments

### 5. CLI Menu System
The script should include an interactive CLI menu system when run without arguments:

```ruby
display_menu           # Show the main menu options
get_user_choice       # Get and validate user input
handle_menu_choice    # Execute the selected menu option
```

#### Menu Structure
```
==== Pi-hole Container Manager ====
1. Container Management
   a. Install Pi-hole
   b. Start container
   c. Stop container
   d. Restart container
   e. Update container
   f. Show status
   
2. Domain Management
   a. Block domain
   b. Unblock domain
   c. List blocked domains
   d. Bulk block domains (from file)
   e. Bulk unblock domains (from file)
   
3. Configuration
   a. View current settings
   b. Change admin password
   c. Update timezone
   d. Export configuration
   e. Import configuration
   
4. Logs & Monitoring
   a. View container logs
   b. View Pi-hole query logs
   c. Show DNS statistics
   d. View manager logs
   
5. Advanced Options
   a. Access Pi-hole CLI directly
   b. Open web interface
   c. Backup configuration
   d. Restore configuration
   
0. Exit

Enter your choice:
```

#### Menu Features
- **Navigation**: Support sub-menus for grouped functionality
- **Input Validation**: Validate all user inputs with clear error messages
- **Confirmation Prompts**: Ask for confirmation on destructive operations
- **Back/Exit Options**: Allow users to go back to previous menu or exit
- **Help Text**: Display brief descriptions for each menu option
- **State Awareness**: Show current container status in the menu header
- **Color Support**: Use terminal colors for better UX (optional, with fallback)

#### Menu Implementation Requirements
- **Persistent Loop**: Menu should continue until user chooses to exit
- **Error Handling**: Gracefully handle invalid menu choices
- **Clear Screen**: Option to clear screen between menu transitions
- **Status Display**: Show current Pi-hole status at the top of main menu
- **Quick Actions**: Support keyboard shortcuts for common actions

### 6. Logging
- Maintain a log file at `/opt/pihole/pihole-manager.log`
- Log every lifecycle and domain management action with a timestamp

---

## Command-Line Interface
The script should accept subcommands and also provide an interactive menu when run without arguments:

### Interactive Menu Mode
```bash
ruby pihole_manager.rb                      # Launch interactive CLI menu system
ruby pihole_manager.rb menu                 # Alternative way to launch menu
```

### Direct Command Mode
```bash
ruby pihole_manager.rb install              # Install and configure Pi-hole in Docker container
ruby pihole_manager.rb start                # Start Pi-hole container
ruby pihole_manager.rb stop                 # Stop Pi-hole container
ruby pihole_manager.rb restart              # Restart Pi-hole container
ruby pihole_manager.rb status               # Show container status
ruby pihole_manager.rb update               # Update Pi-hole container

ruby pihole_manager.rb block <domain>       # Block a domain
ruby pihole_manager.rb unblock <domain>     # Unblock a domain
ruby pihole_manager.rb list-blocked         # List blocked domains

# Extended commands for menu functionality
ruby pihole_manager.rb bulk-block <file>    # Block domains from file (one per line)
ruby pihole_manager.rb bulk-unblock <file>  # Unblock domains from file (one per line)
ruby pihole_manager.rb backup <path>        # Backup configuration to specified path
ruby pihole_manager.rb restore <path>       # Restore configuration from specified path
ruby pihole_manager.rb logs                 # Show Pi-hole logs
ruby pihole_manager.rb stats                # Show DNS query statistics
ruby pihole_manager.rb web                  # Open web interface in default browser
```

### Command-Line Options
```bash
ruby pihole_manager.rb --help               # Show usage information
ruby pihole_manager.rb --version            # Show script version
ruby pihole_manager.rb --verbose            # Enable verbose output for any command
ruby pihole_manager.rb --config <file>      # Use custom configuration file
```

---

## Example Lifecycle Usage

### Using Interactive Menu System
1. **Launch Menu**
   ```bash
   ruby pihole_manager.rb
   ```
   - Displays interactive menu with current Pi-hole status
   - Navigate through options using number keys
   - Guided prompts for all configuration steps

### Using Direct Commands
1. **Install & Configure Pi-hole**
   ```bash
   ruby pihole_manager.rb install
   ```
   - Checks dependencies
   - Prompts for timezone & admin password
   - Creates host config directories
   - Runs Pi-hole container with Docker

2. **Start Pi-hole**
   ```bash
   ruby pihole_manager.rb start
   ```

3. **Block Social Media for a Client**
   ```bash
   ruby pihole_manager.rb block facebook.com
   ruby pihole_manager.rb block instagram.com
   ```

4. **Unblock at a Later Time**
   ```bash
   ruby pihole_manager.rb unblock facebook.com
   ```

5. **Update Pi-hole**
   ```bash
   ruby pihole_manager.rb update
   ```

### Example Menu Workflow
```
$ ruby pihole_manager.rb

==== Pi-hole Container Manager ====
Status: Running | Uptime: 2 days, 3 hours
DNS Queries Today: 1,247 | Blocked: 89 (7.1%)

1. Container Management
2. Domain Management  
3. Configuration
4. Logs & Monitoring
5. Advanced Options
0. Exit

Enter your choice: 2

==== Domain Management ====
a. Block domain
b. Unblock domain  
c. List blocked domains
d. Bulk block domains (from file)
e. Bulk unblock domains (from file)
b. Back to main menu

Enter your choice: a
Enter domain to block: ads.example.com
Successfully blocked ads.example.com
Press Enter to continue...
```

---

## Error Handling
- If the container name already exists during installation, prompt to overwrite or exit
- If ports are in use, display a clear error and suggest remediation
- If `docker` CLI is missing or Docker daemon is not running, prompt for installation/startup instructions
- All methods should rescue from shell execution errors and display friendly messages

---

## Notes for Coding Agent
- Use `system()` or backticks for shell execution
- Use `docker exec` for executing commands inside containers
- Ensure the script works idempotently (safe to rerun)
- All paths should be configurable at the top of the script
- Consider using constants for container name and mount points
- Include comments above each method for clarity
