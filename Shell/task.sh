#!/bin/bash

cd /tmp
wget http://xjtu.hly.space/downloads/ipv6
xjtuip=$(cat ipv6)
echo IPV6 is ${xjtuip}
cd /etc/nginx/sites-available
cat >default <<-EOF

server
{
listen          80;
listen [::]:80 default_server ipv6only=on;

server_name     www.hly.space;
location / {
proxy_pass          http://[${xjtuip}]/;
proxy_redirect      off;
proxy_set_header    X-Real-IP       $remote_addr;
proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
}
}

EOF

runtime=0
status=1
while [ ${status} == 1 -a ${runtime} -lt 4 ]
do
  sleep 10s
  systemctl start nginx
  status=$?
  runtime=` expr ${runtime} + 1 `
  echo 启动nginx；第${runtime}次尝试；返回状态:${status}
done

[ ${status} == 0 ] && status=SUCCESS
[ ${status} == 1 ] && status=FAIL

echo XJTU SERVER UPDATE
