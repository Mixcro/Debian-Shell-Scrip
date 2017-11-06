#!/bin/bash

#适用于树莓派3 raspbian系统，至于其他的我就不知道了

apt update& apt upgrade -y
apt install hostapd dnsmasq -y
if [ $? == 1 ] ; then echo"相关软件获取失败，请检查网络连接" && exit 1 ; fi ;
echo 设定AP参数
read -p "Local IP(默认192.168.3.1):" ip
[ -z "$ip" ] && ip=192.168.3.1
read -p "Start of DHCP(默认192.168.3.2):" start
[ -z "$start" ] && start=192.168.3.2
read -p "End of DHCP(默认192.168.3.100):" end
[ -z "$end" ] && end=192.168.3.100
read -p "Name of AP:" name
read -p "Password:" ser
cat >>/etc/dnsmasq.conf <<-EOF


interface=wlan0
dhcp-range=${start},${end},255.255.255.0,12h
EOF
cat >/etc/hostapd/hostapd.conf <<-EOF
interface=wlan0
hw_mode=g
channel=10
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=${ser}
ssid=${name}
EOF
sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sed -i '/^exit 0/i\cd \/root' /etc/rc.local
sed -i '/^exit 0/i\.\/start.sh >start.log' /etc/rc.local
cat >/root/start.sh <<-EOF
#!/bin/bash

#Hostapd&dnsmasp
way=ap
interface=ppp0
if [ \${way} == ap ] ; then
  ifconfig wlan0 down
  ifconfig wlan0 ${ip} netmask 255.255.255.0 up
  iwconfig wlan0 power off
  service dnsmasq restart
  hostapd -B /etc/hostapd/hostapd.conf & > /dev/null 2>&1
  iptables -t nat -A POSTROUTING -o \${interface} -j MASQUERADE
  iptables -A FORWARD -i \${interface} -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT  
  iptables -A FORWARD -i wlan0 -o \${interface} -j ACCEPT
fi
echo "wlan0 works in \${way} mod"
EOF
chmod 755 /root/start.sh
echo "AP配置完成，重启生效"
echo "默认为AP模式，可在/root/start.sh中更改"
