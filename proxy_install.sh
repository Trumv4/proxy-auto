#!/bin/bash

# === Cấu hình BOT TELEGRAM ===
BOT_TOKEN="7661562599:AAG5AvXpwl87M5up34-nj9AvMiJu-jYuWlA"
CHAT_ID="-1002322055133"

# === Bắt đầu cài đặt SOCKS5 ===
if [ -f /etc/debian_version ]; then
  apt update -y
  apt install -y gcc make wget tar firewalld curl iproute2
else
  yum update -y
  yum install -y gcc make wget tar firewalld curl
fi

# Cài Dante
cd /root
wget https://www.inet.no/dante/files/dante-1.4.2.tar.gz
tar -xvzf dante-1.4.2.tar.gz
cd dante-1.4.2
./configure
make
make install

# Lấy interface mạng chính (auto)
EXT_IF=$(ip -o -4 route show to default | awk '{print $5}')

# Lấy IP public
IP=$(curl -s ifconfig.me)

# Random port và pass
PORT=$(shuf -i 20000-60000 -n 1)
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c12)
USER=anhtu

# Tạo user nếu chưa có
id "$USER" &>/dev/null || useradd "$USER"
echo "$USER:$PASS" | chpasswd

# Ghi cấu hình vào file cấu hình chính
cat > /etc/sockd.conf <<EOF
logoutput: /var/log/sockd.log
internal: 0.0.0.0 port = $PORT
external: $EXT_IF
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

# Mở port firewall
if command -v firewall-cmd >/dev/null 2>&1; then
  systemctl start firewalld
  firewall-cmd --permanent --add-port=${PORT}/tcp
  firewall-cmd --reload
else
  iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
fi

# Thêm cấu hình hệ thống nếu chưa có
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

# Khởi động lại dịch vụ
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable sockd
systemctl restart sockd

# Kiểm tra tốc độ proxy
SPEED=$(curl -x socks5h://$USER:$PASS@$IP:$PORT -o /dev/null -s -w "%{time_total}" http://ifconfig.me)
PING_RESULT=$(ping -c 3 $IP | tail -2 | head -1 | awk -F '/' '{print $5 " ms"}')

# Gửi về Telegram
MSG="SOCKS5 Proxy Created!
➡️ $IP:$PORT

⏱ Tốc độ phản hồi: $SPEED s
📶 Ping trung bình: $PING_RESULT

Ip:port:user:pass
$IP:$PORT:$USER:$PASS

Tạo Proxy Thành Công - Bot By Phạm Anh Tú
Zalo : 0326615531"
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="$MSG"

echo "✅ Proxy đã tạo và gửi về Telegram!"
