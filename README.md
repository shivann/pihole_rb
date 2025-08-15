# Pi-hole Container Manager for macOS

A Ruby-based CLI tool for managing Pi-hole DNS server deployments using Docker on macOS. Designed specifically for Mac mini home server setups with both interactive menu and direct command-line interfaces.

## 🚀 Features

- **Easy Installation**: Automated Pi-hole container setup with Docker
- **Interactive CLI Menu**: User-friendly menu system for all operations
- **Direct Commands**: Power-user friendly command-line interface
- **Domain Management**: Block/unblock domains with bulk operations support
- **Configuration Management**: Backup, restore, and modify Pi-hole settings
- **Monitoring & Logs**: View DNS statistics, query logs, and container status
- **macOS Integration**: Designed specifically for macOS with Docker Desktop support

## 📋 Prerequisites

### Required Software
- **macOS** (tested on macOS 14+)
- **Ruby** 3.0 or higher
- **Docker Desktop** for Mac ([docker.com](https://www.docker.com/products/docker-desktop/))

### System Requirements
- Mac mini (recommended) or any macOS device
- Available ports: 53 (DNS), 80 (Web Interface)
- At least 2GB free disk space for Docker and Pi-hole
- Docker Desktop installed and running

### Installing Docker Desktop
```bash
# Option 1: Download from Docker website
# https://www.docker.com/products/docker-desktop/

# Option 2: Install via Homebrew
brew install --cask docker

# Start Docker Desktop after installation
open -a Docker
```

## 🔧 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/pihole_rb.git
   cd pihole_rb
   ```

2. **Make the script executable**
   ```bash
   chmod +x pihole_manager.rb
   ```

3. **Initial setup**
   ```bash
   ruby pihole_manager.rb install
   ```

The installation process will:
- Check all dependencies (Docker, available ports)
- Prompt for configuration (timezone, admin password)
- Create necessary directories
- Pull and configure the Pi-hole Docker container
- Start the Pi-hole service with proper port mappings

## 🎯 Quick Start

### Interactive Menu Mode (Recommended for beginners)
```bash
ruby pihole_manager.rb
```

This launches an interactive menu with guided options for all Pi-hole management tasks.

### Direct Command Mode (For power users)
```bash
# Container management
ruby pihole_manager.rb start
ruby pihole_manager.rb stop
ruby pihole_manager.rb status

# Domain blocking
ruby pihole_manager.rb block ads.example.com
ruby pihole_manager.rb unblock ads.example.com
ruby pihole_manager.rb list-blocked
```

## 📖 Usage Guide

### Interactive Menu System

When you run the script without arguments, you'll see:

```
==== Pi-hole Container Manager ====
Status: Running | Uptime: 2 days, 3 hours
DNS Queries Today: 1,247 | Blocked: 89 (7.1%)

1. Container Management
2. Domain Management  
3. Configuration
4. Logs & Monitoring
5. Advanced Options
0. Exit

Enter your choice:
```

Navigate using number keys and follow the prompts for each operation.

### Command Reference

#### Container Management
```bash
ruby pihole_manager.rb install              # Install and configure Pi-hole
ruby pihole_manager.rb start                # Start Pi-hole container
ruby pihole_manager.rb stop                 # Stop Pi-hole container
ruby pihole_manager.rb restart              # Restart Pi-hole container
ruby pihole_manager.rb status               # Show container status
ruby pihole_manager.rb update               # Update Pi-hole to latest version
```

#### Domain Management
```bash
ruby pihole_manager.rb block <domain>       # Block a specific domain
ruby pihole_manager.rb unblock <domain>     # Unblock a specific domain
ruby pihole_manager.rb list-blocked         # List all blocked domains
ruby pihole_manager.rb bulk-block <file>    # Block domains from file
ruby pihole_manager.rb bulk-unblock <file>  # Unblock domains from file
```

#### Configuration & Monitoring
```bash
ruby pihole_manager.rb backup <path>        # Backup configuration
ruby pihole_manager.rb restore <path>       # Restore configuration
ruby pihole_manager.rb logs                 # Show Pi-hole logs
ruby pihole_manager.rb stats                # Show DNS statistics
ruby pihole_manager.rb web                  # Open web interface
```

#### Command Options
```bash
ruby pihole_manager.rb --help               # Show help information
ruby pihole_manager.rb --version            # Show script version
ruby pihole_manager.rb --verbose            # Enable verbose output
ruby pihole_manager.rb --config <file>      # Use custom config file
```

## ⚙️ Configuration

### Default Paths
- **Configuration**: `/opt/pihole/etc-pihole`
- **DNS Configuration**: `/opt/pihole/etc-dnsmasq.d`
- **Log Files**: `/opt/pihole/pihole-manager.log`

### Environment Variables
The script supports these Pi-hole environment variables:
- `TZ`: Timezone (e.g., `America/New_York`)
- `WEBPASSWORD`: Admin interface password

### Bulk Domain Management
Create text files with one domain per line for bulk operations:

**blocked_domains.txt**
```
ads.google.com
doubleclick.net
facebook.com
instagram.com
```

Then use:
```bash
ruby pihole_manager.rb bulk-block blocked_domains.txt
```

## 🏠 Network Setup

### DNS Configuration
To use Pi-hole as your network DNS server:

1. **Configure your router** to use the Mac mini's IP as the primary DNS server
2. **Or configure individual devices** to use the Pi-hole IP address
3. **Test DNS resolution**: `nslookup google.com <your-mac-mini-ip>`

### Static IP Recommendation
Set a static IP for your Mac mini to ensure consistent DNS service.

## 🔍 Troubleshooting

### Common Issues

**Port 53 already in use**
```bash
# Check what's using port 53
sudo lsof -i :53
# Stop conflicting service (usually mDNSResponder)
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist
```

**Container won't start**
```bash
# Check container status
ruby pihole_manager.rb status
# View detailed logs
ruby pihole_manager.rb logs
```

**Can't access web interface**
```bash
# Check if port 80 is available
sudo lsof -i :80
# Ensure container is running
ruby pihole_manager.rb status
```

**Docker not found or not running**
- Install Docker Desktop for Mac from the official website
- Start Docker Desktop: `open -a Docker`
- Verify installation: `docker --version`

### Log Files
- Manager logs: `/opt/pihole/pihole-manager.log`
- Container logs: Access via `ruby pihole_manager.rb logs`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Pi-hole](https://pi-hole.net/) - Network-wide ad blocking
- [Docker](https://www.docker.com/) - Container platform
- The open-source community for inspiration and tools

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/pihole_rb/issues)
- **Documentation**: See `pihole_spec.md` for detailed specifications
- **Pi-hole Documentation**: [Official Pi-hole Docs](https://docs.pi-hole.net/)

---

**Note**: This tool is designed for macOS with Docker Desktop. For other platforms or container runtimes, modifications may be required.
