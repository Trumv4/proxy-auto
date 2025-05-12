#!/bin/bash

echo "=== Bắt đầu cài đặt SOCKS5 Proxy ==="

# Cập nhật hệ thống và cài gói cần thiết
yum update -y
yum install -y gcc make wget tar firewalld

# Tải và cài đặt Dante SOCKS5
cd /root
wget https://www.inet.no/dante/files/dante-1.4.2.tar.gz
tar -xvzf dante-1.4.2.tar.gz
cd dante-1.4.2
./configure
make
make install

# Tạo user proxy
useradd proxyuser
echo "proxyuser:proxypass" | chpasswd

# Tạo file cấu hình Dante
cat > /etc/sockd.conf << EOF
logoutput: /var/log/sockd.log
internal: eth0 port = 1080
external: eth0
method: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect
    log: connect disconnect error
    method: username
}
EOF

# Tạo service systemd
cat > /etc/systemd/system/sockd.service << EOF
[Unit]
Description=Dante SOCKS5 Proxy
After=network.target

[Service]
ExecStart=/usr/local/sbin/sockd -f /etc/sockd.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Kích hoạt và khởi động proxy
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable sockd
systemctl start sockd

# Mở port 1080 trên firewall
systemctl start firewalld
firewall-cmd --permanent --add-port=1080/tcp
firewall-cmd --reload

echo "=== Hoàn tất! Proxy đang chạy trên port 1080 ==="
echo "IP: $(curl -s ifconfig.me)"
echo "User: proxyuser"
echo "Pass: proxypass"
