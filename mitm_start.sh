#!/bin/sh

# vars
IFACE_WAN="eth0"

IFACE_BR="br0"
IFACE_LAN="eth1"
IFACE_WIFI="wlan0"

WIFI_SSID="mitm"
WIFI_PWD="mitmmitm"

LAN_IP="192.168.200.6"
LAN_SUBNET="255.255.255.0"
LAN_DHCP_START="192.168.200.110"
LAN_DHCP_END="192.168.200.115"
LAN_DNS_SERVER="1.1.1.1"
BR_IP="192.168.200.116"

DNSMASQ_CONF="tmp_dnsmasq.conf"
HOSTAPD_CONF="tmp_hostapd.conf"
HOSTAPD_CONF_COUNTRY_CODE="NL"

# what must we do
if [ "$1" != "up" ] && [ "$1" != "down" ] || [ $# != 1 ]; then
    echo "missing required argument"
    echo "$0: <up/down>"
    exit
fi

# stopping
echo "== stop router services"
sudo killall wpa_supplicant
sudo killall dnsmasq

# reset all
echo "== reset all network interfaces"
sudo ifconfig $IFACE_LAN 0.0.0.0
sudo ifconfig $IFACE_LAN down

sudo ifconfig $IFACE_BR 0.0.0.0
sudo ifconfig $IFACE_BR down

sudo ifconfig $IFACE_WIFI 0.0.0.0
sudo ifconfig $IFACE_WIFI down

sudo brctl delbr $IFACE_BR

# bring up
if [ $1 = "up" ]; then
	echo "== bringing up"
	
    echo "== create dnsmasq config file"
    echo "interface=${IFACE_BR}" > $DNSMASQ_CONF
    echo "dhcp-range=${LAN_DHCP_START},${LAN_DHCP_END},${LAN_SUBNET},12h" >> $DNSMASQ_CONF
    echo "dhcp-option=6,${LAN_DNS_SERVER}" >> $DNSMASQ_CONF
    
    echo "create hostapd config file"
    echo "interface=${IFACE_WIFI}" > $HOSTAPD_CONF
    echo "bridge=${IFACE_BR}" >> $HOSTAPD_CONF
    echo "ssid=${WIFI_SSID}" >> $HOSTAPD_CONF
    echo "country_code=$HOSTAPD_CONF_COUNTRY_CODE" >> $HOSTAPD_CONF
    echo "hw_mode=g" >> $HOSTAPD_CONF
    echo "channel=11" >> $HOSTAPD_CONF
    echo "wpa=2" >> $HOSTAPD_CONF
    echo "wpa_passphrase=${WIFI_PWD}" >> $HOSTAPD_CONF
    echo "wpa_key_mgmt=WPA-PSK" >> $HOSTAPD_CONF
    echo "wpa_pairwise=CCMP" >> $HOSTAPD_CONF
    echo "ieee80211n=1" >> $HOSTAPD_CONF
    #echo "ieee80211w=1" >> $HOSTAPD_CONF # PMF
    
    echo "== bring up interfaces and bridge"
    sudo ifconfig $IFACE_WIFI up
    sudo ifconfig $IFACE_WAN up
    sudo ifconfig $IFACE_LAN up
    sudo brctl addbr $IFACE_BR
    sudo brctl addif $IFACE_BR $IFACE_LAN
    sudo ifconfig $IFACE_BR up
    
    echo "== setup iptables"
    sudo iptables --flush
    sudo iptables -t nat --flush
    #sudo iptables -t nat -A POSTROUTING -o $IFACE_WAN -j MASQUERADE
    #sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    #sudo iptables -A FORWARD -i $IFACE_BR -o $IFACE_WAN -j ACCEPT
	
	sudo iptables -t nat -A POSTROUTING -o $IFACE_WAN -j MASQUERADE
	sudo iptables -A FORWARD -i $IFACE_WAN -o $IFACE_BR -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i $IFACE_BR -o $IFACE_WAN -j ACCEPT
    # optional mitm rules
    #sudo iptables -t nat -A PREROUTING -i $IFACE_WIFI -p tcp -d 1.2.3.4 --dport 443 -j REDIRECT --to-ports 8081
    
    
    echo "== setting static IP on bridge interface"
    sudo ifconfig $IFACE_BR inet $LAN_IP netmask $LAN_SUBNET
    
    echo "== starting dnsmasq"
    sudo dnsmasq -C $DNSMASQ_CONF
    
    echo "== starting hostapd"
    sudo hostapd $HOSTAPD_CONF
fi
