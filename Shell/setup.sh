#!/bin/bash

#仅仅是能用罢了...联系我:qq:772311195

# 获取服务器的IP地址
get_server_ip() {
	SERVER_IP=$(ip addr | grep -Eo "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | \
		grep -Ev "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | \
		head -n 1)
	[ -z "$SERVER_IP" ] && SERVER_IP=$(wget -q -O - ipv4.icanhazip.com)
}

#初次安装
install() {
    echo "正在更新软件"
    get_server_ip
    apt update 
    apt upgrade -y 
    echo "正在安装Shadowsocks..."
    apt install python-pip nano -y 
    pip install shadowsocks 
    if [ $? == 0 ] ; then echo "Shadowsocks 安装成功" ; else echo "Shadowsocks 安装失败" ; fi ;
    mkdir -p /root/kcptun/{conf.d,log.d} 
    mkdir -p /etc/log/shadowsocks 
    echo "正在安装KCPTUN..."
    echo "请访问https://github.com/xtaci/kcptun/releases/并复制合适版本的下载地址"
    read -p "粘贴该地址:" url
    cd /root/kcptun
    wget $url -O kcptun.tar.gz 
    if [ $? == 0 ] ; then echo "KCPTUN 安装成功" ; else echo "KCPTUN 安装失败" ; fi ;
    tar -xf kcptun.tar.gz && rm kcptun.tar.gz
    mv client* client
    mv server* server
    chmod +x client*
    chmod +x server*
    echo "正在安装Supervisor..."
    apt install supervisor -y
    if [ $? == 0 ] ; then echo "Supervisor 安装成功" ; else echo "Supervisor 安装失败" ; fi ;
    cp /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf.bak
    read -p "是否启用supervisor的web管理页面,y/n(默认:y)？" sel
    [ -z "$sel" ] && sel=y
    if [ ${sel} == y ] ;then
        read -p "请输入端口(默认9000):" port
        [ -z "$port" ] && port=9000
        read -p "请输入用户名：" user
        read -p "请输入密码:" password
        cat >>/etc/supervisor/supervisord.conf <<-EOF

[inet_http_server]
port = ${SERVER_IP}:${port}
username = ${user}
password = ${password}
EOF
        echo 你现在可以通过http://${SERVER_IP}:${port}对Supervisor进行管理
    fi    
}

#初始化设置
resetall() {
    rm -rf /etc/supervisor/conf.d/* /root/kcptun/conf.d/* /root/kcptun/log.d/* /etc/log/shadowsocks/*
    rm /etc/supervisor/supervisord.conf
    cp /etc/supervisor/supervisord.conf.bak /etc/supervisor/supervisord.conf
    read -p "是否启用supervisor的web管理页面,y/n(默认:y)？" sel
    [ -z "$sel" ] && sel=y
    if [ ${sel} == y ] ;then
        get_server_ip
        read -p "请输入端口(默认9000):" port
        [ -z "$port" ] && port=9000
        read -p "请输入登录名:" user
        read -p "请输入密码:" password
        cat >>/etc/supervisor/supervisord.conf <<-EOF

[inet_http_server]
port = ${SERVER_IP}:${port}
username = ${user}
password = ${password}
EOF
    echo 你现在可以通过http://${SERVER_IP}:${port}对Supervisor进行管理
    fi
    echo SS，KCP均已重置
}

#查看并编辑已存在的配置文件
list(){
    echo "以下服务已存在:"
    ls /etc/supervisor/conf.d/${1}*.conf
	cat >&2 <<-'EOF'

请选择你希望的操作:
(1) 删除一个配置文件
(2) 退出到上级菜单(默认)
EOF
	read -p "请选择 [1~2]: " sel
	echo
	[ -z "$sel" ] && sel=2
    if [ $sel == 1 ] ; then
        read -p "请输入文件名中的端口号+c/s:" port
        rm /etc/supervisor/conf.d/${1}${port}.conf
        if [ $1 == kcptun ] ; then 
            rm /root/kcptun/conf.d/${port}.json
            systemctl restart supervisor
        fi
    fi
}

#添加Supersivor
add_supervisor(){
    #name user dir cmd logdir
    cat >/etc/supervisor/conf.d/$1.conf  <<-EOF
[program:${1}]
user=${2}
directory=${3}
command=${4}
process_name=%(program_name)s
autostart=true
redirect_stderr=true
stdout_logfile=${5}/${1}.log
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=0
EOF
    echo ${1}已添加
}

#添加kcptunclient的json
add_kcpclient_json(){
    read -p "服务器地址(ipv6地址请加上[]):" remoteaddress
    read -p "服务器端口：" remoteport
    read -p "本地监听端口：" localport
    read -p "服务器密码(默认:it's a secrect)：" key
    [ -z "${key}" ] && key="it's a secrect"
    cat >&2 <<-EOF
请输入加密方式："aes""aes-128""aes-192""salsa20""blowfish"
                "twofish""cast5""3des""tea""xtea""xor""none"
EOF

    read -p "(默认:aes)：" crypt
    [ -z "${crypt}" ] && crypt=aes
    cat >&2 <<-EOF
请输入加速模式："normal""fast""fast2""fast3""manual"
EOF
    read -p "(默认:fast)：" mode
    [ -z "${mode}" ] && mode=fast
    cat >/root/kcptun/conf.d/${localport}c.json <<-EOF
{
    "localaddr": ":${localport}",
    "remoteaddr": "${remoteaddress}:${remoteport}",
    "key": "${key}",
    "crypt": "${crypt}",
    "mode": "${mode}",
    "conn": 1,
    "autoexpire": 60,
    "mtu": 1350,
    "sndwnd": 1024,
    "rcvwnd": 1024,
    "datashard": 10,
    "parityshard": 3,
    "dscp": 0,
    "nocomp": false,
    "acknodelay": false,
    "nodelay": 0,
    "interval": 20,
    "resend": 2,
    "nc": 1,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF
    read -p "是否手动修改配置文件,y/n?（默认:n）" sel
    [ -z "${sel}" ] && sel=n
    if [ ${sel} == y ] ; then nano /root/kcptun/conf.d/${localport}c.json ; fi
}

#添加kcptunserver的json
add_kcpserver_json(){
    read -p "原服务地址(默认:127.0.0.1)" remoteaddress
    [ -z "${remoteaddress}" ] && remoteaddress=127.0.0.1
    read -p "原服务端口：" remoteport
    read -p "KCPTUN端口：" localport
    read -p "服务器密码(默认:it's a secrect)：" key
    [ -z "${key}" ] && key="it's a secrect"
    cat >&2 <<-EOF
请输入加密方式："aes""aes-128""aes-192""salsa20""blowfish"
                "twofish""cast5""3des""tea""xtea""xor""none"
EOF

    read -p "(默认:aes)：" crypt
    [ -z "${crypt}" ] && crypt=aes
    cat >&2 <<-EOF
请输入加速模式："normal""fast""fast2""fast3""manual"
EOF
    read -p "(默认:fast)：" mode
    [ -z "${mode}" ] && mode=fast
    cat >/root/kcptun/conf.d/${localport}s.json <<-EOF
{
    "listen": ":${localport}",
    "target": "${remoteaddress}:${remoteport}",
    "key": "${key}",
    "crypt": "${crypt}",
    "mode": "${mode}",
    "mtu": 1350,
    "sndwnd": 1024,
    "rcvwnd": 1024,
    "datashard": 10,
    "parityshard": 3,
    "dscp": 0,
    "nocomp": false,
    "acknodelay": false,
    "nodelay": 0,
    "interval": 20,
    "resend": 2,
    "nc": 1,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF
    read -p "是否手动修改配置文件,y/n?（默认:n）" sel
    [ -z "${sel}" ] && sel=n
    if [ ${sel} == y ] ; then nano /root/kcptun/conf.d/${localport}s.json ; fi
}

while :
do
	cat >&2 <<-'EOF'

请选择你希望的操作:
(1) 安装
(2) 初始化设置
(3) 添加自定义supersivor服务
(4) 添加KCPTUN服务端
(5) 添加KCPTUN客户端
(6) 查看并编辑KCPTUN
(7) 添加SS服务端
(8) 添加SS客户端
(9) 查看并编辑SS
(10)退出脚本
注:SS与KCP各服务均将自启动
EOF
	read -p "(默认: 10) 请选择 [1~10]: " sel
	echo
	[ -z "$sel" ] && sel=10
		case $sel in
		1)
            install
            continue
			;;
		2)
            resetall
            continue
			;;
		3)
			read -p "name=" name
            read -p "user=" user
            read -p "directory=" dir
            read -p "command=" cmd
            add_supervisor ${name} ${user} ${dir} "${cmd}" /etc/log
            continue
			;;
		4)
			add_kcpserver_json
            app=/root/kcptun/server
            add_supervisor kcptun${localport}s root /root/kcptun "${app} -c /root/kcptun/conf.d/${localport}s.json" /root/kcptun/log.d
            systemctl restart supervisor
            continue
			;;
		5)
			add_kcpclient_json
            app=/root/kcptun/client
            add_supervisor kcptun${localport}c root /root/kcptun "${app} -c /root/kcptun/conf.d/${localport}c.json" /root/kcptun/log.d
            systemctl restart supervisor
            continue
			;;
		6)
			list kcptun
            continue
			;;
		7)
			read -p "端口：" port
            read -p "密码：" key
            add_supervisor ss${port}s root /root "ssserver -p ${port} -k ${key}" /etc/log/shadowsocks
            systemctl restart supervisor
            continue
			;;
		8)
			read -p "服务器端口：" port
            read -p "密码：" key
            read -p "服务器地址:" ip
            read -p "本地端口(默认1080):" lport
            [ -z "${lport}" ] && lport=1080
            add_supervisor ss${port}c root /root "sslocal -p ${port} -k ${key} -s ${ip} -l ${lport} -b :: " /etc/log/shadowsocks
            systemctl restart supervisor
            continue
			;;
		9)
			list ss
            continue
			;;
		10)
			;;
		*)
			echo "输入有误, 请输入有效数字 1~10!"
			continue
			;;
	esac
    
	exit 0
done
