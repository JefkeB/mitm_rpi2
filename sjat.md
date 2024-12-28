To set up a Raspberry Pi as a bridge between `eth1` (LAN) and `wlan0` (LAN), connecting them to `eth0` (WAN) for internet access and enabling monitoring on the bridge with an external PC using Wireshark, follow these steps:

### Assumptions
- `eth0`: WAN interface (connected to the internet).
- `eth1`: LAN interface (wired network for clients).
- `wlan0`: Wireless LAN (Wi-Fi network for clients).
- Bridge interface: `br0`.

### 1. **Prepare the Raspberry Pi**
Ensure you have the required tools:
```bash
sudo apt update
sudo apt install bridge-utils dnsmasq hostapd tcpdump iptables-persistent
```

### 2. **Enable IP Forwarding**
Enable IPv4 forwarding to route traffic between interfaces:
```bash
sudo nano /etc/sysctl.conf
```
Uncomment or add the following line:
```plaintext
net.ipv4.ip_forward=1
```

Apply the changes:
```bash
sudo sysctl -p
```

### 3. **Configure the Bridge Interface**
Edit the network configuration file. On Raspberry Pi OS Bullseye or later, this is managed via `dhcpcd` or `netplan`.

#### Using `dhcpcd` (Default for Raspberry Pi OS):
Edit `/etc/dhcpcd.conf`:
```bash
sudo nano /etc/dhcpcd.conf
```

Add the following:
```plaintext
denyinterfaces eth1
denyinterfaces wlan0
```

Create a new file for the bridge configuration:
```bash
sudo nano /etc/network/interfaces.d/bridge
```

Add:
```plaintext
auto br0
iface br0 inet dhcp
    bridge_ports eth1 wlan0
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
```

Restart `dhcpcd`:
```bash
sudo systemctl restart dhcpcd
```

### 4. **Set Up `iptables` for NAT**
Enable NAT so that LAN devices can access the internet via `eth0`:
```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i br0 -o eth0 -j ACCEPT
```

Save the `iptables` rules:
```bash
sudo netfilter-persistent save
```

### 5. **Configure `dnsmasq` for DHCP**
Provide IP addresses to LAN clients:
```bash
sudo nano /etc/dnsmasq.conf
```

Add:
```plaintext
interface=br0
dhcp-range=192.168.100.2,192.168.100.100,255.255.255.0,24h
```

Restart `dnsmasq`:
```bash
sudo systemctl restart dnsmasq
```

### 6. **Enable Wireless Access Point (`wlan0`)**
Edit `/etc/hostapd/hostapd.conf`:
```bash
sudo nano /etc/hostapd/hostapd.conf
```

Add:
```plaintext
interface=wlan0
bridge=br0
ssid=YourSSID
hw_mode=g
channel=7
auth_algs=1
wmm_enabled=1
wpa=2
wpa_passphrase=YourPassphrase
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
```

Point `hostapd` to this configuration:
```bash
sudo nano /etc/default/hostapd
```

Set:
```plaintext
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

Restart `hostapd`:
```bash
sudo systemctl restart hostapd
```

### 7. **Monitor Traffic with Wireshark**
#### a. Enable Monitoring on `br0`
Use `tcpdump` to capture traffic and stream it to Wireshark:
```bash
sudo tcpdump -i br0 -w - | wireshark -k -i -
```

Alternatively, log traffic to a file:
```bash
sudo tcpdump -i br0 -w bridge_traffic.pcap
```

Copy the file to your PC:
```bash
scp pi@raspberrypi:/path/to/bridge_traffic.pcap /local/path/
```

#### b. Monitor Remotely
If the Raspberry Pi and your PC are on the same network, you can remotely view traffic using Wireshark:
1. Run `tcpdump` on the Raspberry Pi:
   ```bash
   sudo tcpdump -i br0 -s 0 -w - | nc -l 9999
   ```
2. Connect to the stream from your PC:
   ```bash
   nc raspberrypi 9999 | wireshark -k -i -
   ```

### 8. **Reboot and Verify**
Reboot the Raspberry Pi to apply all changes:
```bash
sudo reboot
```

Test that:
- LAN devices can connect to the internet.
- Wireshark captures traffic on `br0`.

### Troubleshooting
- Use `bridge-utils` to check the bridge status:
  ```bash
  brctl show
  ```
- Use `ifconfig` or `ip addr` to verify IP addresses and interface states.
