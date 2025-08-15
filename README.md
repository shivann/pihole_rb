# Pi-hole Container Manager for macOS

A Ruby-based CLI tool for managing Pi-hole DNS server deployments using Docker on macOS. Designed specifically for Mac mini home server setups with both interactive menu and direct command-line interfaces.

## 🚀 Features

- **Easy Installation**: Automated Pi-hole container setup with Docker
- **Interactive CLI Menu**: User-friendly menu system for all operations
- **Direct Commands**: Power-user friendly command-line interface
- **Domain Management**: Block/unblock domains with bulk operations support
- **Time-Based Blocking**: Schedule automatic blocking during specific hours/days
- **Device-Specific Control**: Target blocking to specific devices or network-wide
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

### 🚀 Quick Router Setup Reference
**Need to configure your router quickly?** Here's the essential info:

1. **Get your Mac mini's IP**: `ifconfig | grep "inet " | grep -v 127.0.0.1`
2. **Set static IP** for Mac mini (System Preferences > Network)
3. **Access router admin** (usually `192.168.1.1` or `192.168.0.1`)
4. **Find DNS settings** (look for DHCP, DNS, or Internet settings)
5. **Set Primary DNS** to your Mac mini's IP
6. **Set Secondary DNS** to `1.1.1.1` or `8.8.8.8`
7. **Save & reboot router**
8. **Test**: Visit `http://pi.hole/admin` to verify

📋 **See detailed router instructions in the [Network Setup](#-network-setup) section below.**

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

#### Schedule Management (Time-based Blocking)
```bash
# Create schedules
ruby pihole_manager.rb schedule create --name Night_Block --start 22:00 --end 06:00
ruby pihole_manager.rb schedule create --name Work_Hours --start 09:00 --end 17:00 --days weekdays

# Manage schedules
ruby pihole_manager.rb schedule list        # List all schedules
ruby pihole_manager.rb schedule status      # Show current schedule status
ruby pihole_manager.rb schedule enable Night_Block     # Enable a schedule
ruby pihole_manager.rb schedule disable Night_Block    # Disable a schedule
ruby pihole_manager.rb schedule delete Night_Block     # Delete a schedule

# Test schedules
ruby pihole_manager.rb schedule test Night_Block enable  # Test enable blocking
ruby pihole_manager.rb schedule test Night_Block disable # Test disable blocking
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

## ⏰ Time-Based Blocking

### Overview
The Pi-hole manager includes powerful scheduling capabilities that allow you to automatically block or allow internet access during specific times. This is perfect for:

- **Parental controls** - Block internet during bedtime or study hours
- **Digital detox** - Schedule internet-free periods
- **Work/school focus** - Block distracting sites during work hours
- **Device management** - Control specific devices on your network

### How It Works
Time-based blocking uses:
1. **Pi-hole Groups** to organize blocking rules
2. **Regex filters** to block all domains or specific categories
3. **Automatic cron jobs** to enable/disable blocking on schedule
4. **Database operations** to manage Pi-hole group states

### Quick Start Examples

#### Network-Wide Blocking
```bash
# Block all devices from 10 PM to 6 AM every day
ruby pihole_manager.rb schedule create \
  --name "Night_Block" \
  --start 22:00 \
  --end 06:00

# Block all devices on weekends from 8 PM to 11 PM
ruby pihole_manager.rb schedule create \
  --name "Weekend_Block" \
  --start 20:00 \
  --end 23:00 \
  --days weekends
```

#### Device-Specific Blocking
```bash
# Block specific devices during work hours
ruby pihole_manager.rb schedule create \
  --name "Work_Focus" \
  --start 09:00 \
  --end 17:00 \
  --days weekdays \
  --devices 192.168.1.50,192.168.1.51

# Block kids' devices during bedtime
ruby pihole_manager.rb schedule create \
  --name "Kids_Bedtime" \
  --start 21:00 \
  --end 07:00 \
  --devices 192.168.1.100,192.168.1.101
```

#### Custom Day Schedules
```bash
# Block on specific days
ruby pihole_manager.rb schedule create \
  --name "Study_Days" \
  --start 14:00 \
  --end 18:00 \
  --days "mon,wed,fri"

# Block Tuesday and Thursday evenings
ruby pihole_manager.rb schedule create \
  --name "Evening_Block" \
  --start 19:00 \
  --end 22:00 \
  --days "tue,thu"
```

### Interactive Menu
Access scheduling through the interactive menu:
```
5. Schedule Management
   1. Create new schedule
   2. List all schedules
   3. Show schedule status
   4. Enable schedule
   5. Disable schedule
   6. Test schedule
   7. Delete schedule
```

### Schedule Management

#### Create Schedules
Use the `schedule create` command with these options:
- `--name`: Unique schedule name (letters, numbers, underscore, dash)
- `--start`: Start time in HH:MM format (24-hour)
- `--end`: End time in HH:MM format (24-hour)
- `--days`: Optional - `all`, `weekdays`, `weekends`, or custom (e.g., `mon,tue,wed`)
- `--devices`: Optional - Comma-separated IP addresses (default: all devices)

#### List and Monitor
```bash
# View all configured schedules
ruby pihole_manager.rb schedule list

# Check current status (which schedules are active)
ruby pihole_manager.rb schedule status
```

#### Enable/Disable
```bash
# Enable a schedule
ruby pihole_manager.rb schedule enable Night_Block

# Disable a schedule
ruby pihole_manager.rb schedule disable Night_Block
```

#### Testing
```bash
# Test enable blocking immediately
ruby pihole_manager.rb schedule test Night_Block enable

# Test disable blocking immediately
ruby pihole_manager.rb schedule test Night_Block disable
```

#### Delete Schedules
```bash
# Delete a schedule (removes cron jobs and Pi-hole groups)
ruby pihole_manager.rb schedule delete Night_Block
```

### Advanced Features

#### Overnight Schedules
Schedules can span midnight:
```bash
# Block from 10 PM to 6 AM (crosses midnight)
ruby pihole_manager.rb schedule create \
  --name "Overnight_Block" \
  --start 22:00 \
  --end 06:00
```

#### Day Format Options
Multiple ways to specify days:
- **Numbers**: `1,2,3,4,5` (Monday=1, Sunday=7)
- **Names**: `mon,tue,wed,thu,fri`
- **Full names**: `monday,tuesday,wednesday`
- **Presets**: `all`, `weekdays`, `weekends`

#### Schedule Status Display
The status command shows:
- Currently active schedules
- Next schedule changes
- Time until next change
- Which devices are affected

### Technical Details

#### Automatic Cron Management
The manager automatically:
- Creates cron jobs for each enabled schedule
- Updates cron jobs when schedules change
- Removes cron jobs when schedules are deleted
- Manages Pi-hole group states via SQLite database

#### Pi-hole Groups
Each schedule creates:
- A Pi-hole group named `Schedule_<name>`
- A regex filter `.*` to block all domains
- Client associations for device-specific blocking
- Automatic DNS restart when rules change

#### Data Storage
- Schedules stored in `<data_dir>/schedules.json`
- Cron jobs managed automatically
- Pi-hole database updated in real-time

### Troubleshooting

#### Common Issues
```bash
# Check if cron jobs are installed
crontab -l | grep "PiHole Schedule"

# Verify Pi-hole groups exist
ruby pihole_manager.rb cli
# Then: sqlite3 /etc/pihole/gravity.db "SELECT * FROM 'group' WHERE name LIKE 'Schedule_%';"

# Test schedule immediately
ruby pihole_manager.rb schedule test <name> enable
```

#### Manual Cleanup
If needed, clean up manually:
```bash
# Remove cron jobs
crontab -l | grep -v "PiHole Schedule" | crontab -

# Access Pi-hole database to remove groups
ruby pihole_manager.rb
# Choose: 6. Advanced Options → 2. Container shell (bash)
# Then: sqlite3 /etc/pihole/gravity.db "DELETE FROM 'group' WHERE name LIKE 'Schedule_%';"
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

### Prerequisites for Router Configuration
1. **Get your Mac mini's IP address**:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   # Example output: inet 192.168.1.100 netmask 0xffffff00 broadcast 192.168.1.255
   ```

2. **Set a static IP for your Mac mini** (highly recommended):
   - Go to **System Preferences > Network**
   - Select your network connection (Wi-Fi or Ethernet)
   - Click **Advanced > TCP/IP**
   - Change **Configure IPv4** from "Using DHCP" to "Manually"
   - Set a static IP (e.g., `192.168.1.100`)
   - Note this IP address - you'll need it for router configuration

### Router Configuration Guide

#### Option 1: Network-Wide Configuration (Recommended)
Configure your router to use Pi-hole as the DNS server for all devices.

##### Common Router Brands:

**ASUS Routers:**
1. Access router admin: `http://192.168.1.1` (or `192.168.50.1`)
2. Login with admin credentials
3. Go to **Advanced Settings > LAN > DHCP Server**
4. Set **DNS Server 1** to your Mac mini's IP (e.g., `192.168.1.100`)
5. Set **DNS Server 2** to `1.1.1.1` (Cloudflare as backup)
6. Click **Apply**
7. Reboot router for changes to take effect

**Netgear Routers:**
1. Access router admin: `http://192.168.1.1` or `http://routerlogin.net`
2. Login with admin credentials
3. Go to **Advanced > Setup > Internet Setup**
4. Under **Domain Name Server (DNS) Address**, select **Use These DNS Servers**
5. Set **Primary DNS** to your Mac mini's IP
6. Set **Secondary DNS** to `8.8.8.8` (Google DNS as backup)
7. Click **Apply**

**Linksys Routers:**
1. Access router admin: `http://192.168.1.1`
2. Login with admin credentials
3. Go to **Smart Wi-Fi Tools > Internet**
4. Under **Internet Connection Type**, click **Edit**
5. Set **Static DNS 1** to your Mac mini's IP
6. Set **Static DNS 2** to `9.9.9.9` (Quad9 as backup)
7. Click **OK** and **Apply**

**TP-Link Routers:**
1. Access router admin: `http://192.168.1.1` or `http://tplinkwifi.net`
2. Login with admin credentials
3. Go to **Advanced > Network > Internet**
4. Set **Primary DNS** to your Mac mini's IP
5. Set **Secondary DNS** to `1.1.1.1`
6. Click **Save**

**Apple AirPort (Legacy):**
1. Open **AirPort Utility** on Mac
2. Select your AirPort router
3. Click **Edit**
4. Go to **Internet** tab
5. Under **Internet Options**, click **Configure IPv4**
6. Set **DNS Servers** to your Mac mini's IP
7. Add backup DNS (e.g., `8.8.8.8`)
8. Click **Update**

**Generic Router Instructions:**
1. Access router admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Look for **DHCP Settings**, **DNS Settings**, or **Internet Settings**
3. Find **Primary/Secondary DNS** or **DNS Server** fields
4. Set Primary DNS to your Mac mini's IP address
5. Set Secondary DNS to a reliable backup (e.g., `1.1.1.1`, `8.8.8.8`)
6. Save settings and reboot router

#### Option 2: Device-Specific Configuration
Configure individual devices when router configuration isn't possible.

**macOS:**
1. **System Preferences > Network**
2. Select your connection > **Advanced > DNS**
3. Add your Mac mini's IP to DNS Servers list
4. Drag it to the top of the list
5. Click **OK > Apply**

**iOS/iPadOS:**
1. **Settings > Wi-Fi**
2. Tap the (i) next to your network
3. Scroll down to **Configure DNS > Manual**
4. Add your Mac mini's IP as a DNS server
5. Tap **Save**

**Windows:**
1. **Control Panel > Network and Internet > Network Connections**
2. Right-click your connection > **Properties**
3. Select **Internet Protocol Version 4 (TCP/IPv4)** > **Properties**
4. Select **Use the following DNS server addresses**
5. Set **Preferred DNS** to your Mac mini's IP
6. Click **OK**

**Android:**
1. **Settings > Wi-Fi**
2. Long press your network > **Modify network**
3. **Advanced options > IP settings > Static**
4. Set **DNS 1** to your Mac mini's IP
5. Tap **Save**

### Network Verification & Testing

#### Verify Pi-hole is Working
1. **Check DNS resolution**:
   ```bash
   # Test from command line
   nslookup google.com 192.168.1.100
   
   # Should return results without errors
   ```

2. **Test ad blocking**:
   ```bash
   # Try to resolve known ad domain
   nslookup doubleclick.net 192.168.1.100
   
   # Should return Pi-hole's blocking IP (0.0.0.0 or Pi-hole IP)
   ```

3. **Web-based verification**:
   - Visit: `http://pi.hole/admin` or `http://your-mac-mini-ip/admin`
   - Check **Query Log** for DNS requests
   - Visit an ad-heavy website and verify blocked queries appear

#### Network Performance Testing
```bash
# Test DNS response time
dig @192.168.1.100 google.com

# Compare with public DNS
dig @8.8.8.8 google.com

# Test from different devices on network
ping pi.hole
```

### Advanced Router Configuration

#### DHCP Reservation
Set up DHCP reservation to ensure your Mac mini always gets the same IP:

1. Access router admin panel
2. Go to **DHCP Settings** or **LAN Settings**
3. Look for **DHCP Reservation** or **Static DHCP**
4. Add your Mac mini's MAC address and desired IP
5. Apply settings

#### Conditional Forwarding (Optional)
For better local network name resolution:

1. In Pi-hole admin: **Settings > DNS**
2. Enable **Conditional forwarding**
3. Set **Local network** to your router's IP range (e.g., `192.168.1.0/24`)
4. Set **Router IP** to your router's address (e.g., `192.168.1.1`)
5. Save settings

#### IPv6 Configuration
If your network uses IPv6:

1. Set your Mac mini's IPv6 address as DNS in router
2. In Pi-hole admin: **Settings > DNS**
3. Enable IPv6 DNS servers if needed
4. Consider disabling IPv6 if experiencing issues

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

### DNS & Router Configuration Issues

**DNS not resolving through Pi-hole**
```bash
# Check if devices are using Pi-hole DNS
nslookup google.com
# Should show Pi-hole's IP in the server field

# Force DNS check with specific server
nslookup google.com 192.168.1.100

# Check what DNS your device is actually using
scutil --dns | grep 'nameserver\['
```

**Router configuration not taking effect**
1. **Reboot router** after changing DNS settings
2. **Release/renew DHCP leases** on client devices:
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   
   # Renew DHCP lease
   sudo ipconfig set en0 DHCP
   ```
3. **Check router DHCP lease time** - changes may take hours to propagate
4. **Manually set DNS** on a test device to verify Pi-hole is working

**Devices still showing ads**
1. **Clear browser cache and DNS cache**
2. **Check if device has hardcoded DNS** (some smart TVs, streaming devices)
3. **Verify in Pi-hole query log** that requests are being received
4. **Check whitelist/blacklist** settings in Pi-hole admin
5. **Some ads may be served from the same domain** as content (can't be blocked)

**Slow internet after Pi-hole setup**
```bash
# Test DNS response times
dig @192.168.1.100 google.com | grep "Query time"
dig @8.8.8.8 google.com | grep "Query time"

# If Pi-hole is slower, check:
# 1. Upstream DNS servers in Pi-hole settings
# 2. Network congestion
# 3. Mac mini performance/resources
```

**Can't access local devices by name**
1. **Enable conditional forwarding** in Pi-hole:
   - Pi-hole Admin → Settings → DNS
   - Check "Use Conditional Forwarding"
   - Set local network range (e.g., 192.168.1.0/24)
   - Set router IP

**Some websites won't load**
1. **Check Pi-hole query log** for blocked domains
2. **Temporarily disable Pi-hole** to test:
   ```bash
   ruby pihole_manager.rb stop
   # Test website, then restart:
   ruby pihole_manager.rb start
   ```
3. **Whitelist necessary domains** in Pi-hole admin
4. **Check if website uses multiple domains** for content delivery

**Network devices can't find each other**
1. **Verify router's local DNS** is still functioning
2. **Check Pi-hole conditional forwarding** settings
3. **Ensure mDNS/Bonjour** services are not blocked
4. **Consider adding local DNS records** in Pi-hole:
   - Pi-hole Admin → Local DNS → DNS Records

### Router-Specific Troubleshooting

**ASUS Router Issues**
- Try **Adaptive QoS** → Disable if causing DNS issues
- Check **AiProtection** settings aren't overriding DNS
- Some models require setting DNS in **WAN** settings instead of DHCP

**Netgear Router Issues**
- **Dynamic DNS** settings may override custom DNS
- Check **Circle with Disney** isn't managing DNS
- Some models need DNS set in **Internet** tab rather than DHCP

**ISP Router/Modem Combo Issues**
- **Bridge mode** may be required for proper DNS control
- Some ISP devices **override DNS settings**
- Consider using **double NAT** setup with your own router

**Enterprise/Business Routers**
- May have **DNS filtering** policies that override settings
- Check for **content filtering** or **security features**
- **VLAN configurations** may affect DNS propagation

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
