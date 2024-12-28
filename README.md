# mitm_rpi2
Man In The Middle on a rpi2

# setup
- raspberry pi 2, used Debian Bullseye  2024-10-22
- usb wlan adapter
- usb ethernet adapter

After writing the debian image to a sd-card  
Install the following on the pi
- hostapd
- dnsmasq
- bridge-utils (for brctl)
  
# script
```
start the script
> ./mitm_start.sh up
stop the running script with ctrl-c
  
to cleanup after running the script run  
> ./mitm_start.sh down
```

# TCPDUMP

```
to dump the data on the bridge to the console start tcpdump with following command  
> sudo tcpdump -i br0
```
