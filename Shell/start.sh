#!/bin/bash
#This shell will run at boot

#Hostapd&dnsmasp
way=ap
interface=ppp0
if [ ${way} == ap ] ; then
  #sleep 5s
  ifconfig wlan0 down
  ifconfig wlan0 192.168.3.1 netmask 255.255.255.0 up
  iwconfig wlan0 power off
  service dnsmasq restart
  hostapd -B /etc/hostapd/hostapd.conf & > /dev/null 2>&1
  iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
  iptables -A FORWARD -i ${interface} -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT  
  iptables -A FORWARD -i wlan0 -o ${interface} -j ACCEPT
fi
echo "wlan0 works in ${way} mod"
#ref https://spaces.ac.cn/archives/3728/


#vpnserver
cd /home/root/vpnserver
./vpnserver start >/dev/null
echo "vpnserver part finished"


#Kiwix
cd /home/root/kiwix
echo "kiwix part finished"


#supervisor
rm /var/log/supervisor/ss.stderr.log /var/log/supervisor/ss.stdout.log
supervisord -c /etc/supervisor/supervisord.conf
echo "superbisor part finished"
#conf /etc/supervisord.conf
#ref https://blog.phpgao.com/supervisor_shadowsocks.html


#Kcptun
autorun=0
if [ ${autorun} == 1 ] ; then
  cd /home/root/kcptun
  ./client_linux_arm7 -c "/home/root/kcptun/config/kcptun9000.json" >log9000.txt 2>&1
  sleep 2s
  ./client_linux_arm7 -c "/home/root/kcptun/config/ss8086.json" >log8838.txt 2>&1
  sleep 2s
  ./client_linux_arm7 -c "/home/root/kcptun/config/vpnserver128.json" >log4546.txt 2>&1
fi
echo "kcp part finished"


echo "shell finished"
