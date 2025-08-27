# Webitel

## Install

**Login and Password** are required to access Webitel install packages.
```shell
sudo -s
apt-get update
apt-get install -qqy --no-install-recommends gnupg2 wget lsb-release

WBTU=webitel_repo_user
WBTP=webitel_repo_password
wget --http-user=$WBTU --http-password=$WBTP -O /usr/share/keyrings/webitel-repo.gpg http://deb.webitel.com/webitel-repo.gpg
echo "machine http://deb.webitel.com login $WBTU password $WBTP" > /etc/apt/auth.conf.d/webitel.conf
echo "deb [signed-by=/usr/share/keyrings/webitel-repo.gpg] http://deb.webitel.com/debian `lsb_release -sc` main" > /etc/apt/sources.list.d/webitel.list
echo "deb [signed-by=/usr/share/keyrings/webitel-repo.gpg] http://deb.webitel.com/debian `lsb_release -sc` 25.08-releases" >> /etc/apt/sources.list.d/webitel.list

apt-get update
apt install webitel-common
```

## Configure

### Linux
```shell
sudo tee /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
fs.file-max = 1000000
vm.max_map_count=262144
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
EOF

sysctl -p
```

### Core services
```shell
apt install webitel-core

cd /opt/webitel
cp etc/default/webitel /etc/default/webitel
cp etc/systemd/system/webitel-app.service /etc/systemd/system/
cp etc/systemd/system/webitel-uac.service /etc/systemd/system/
cp etc/systemd/system/webitel-api.service /etc/systemd/system/

systemctl enable --now webitel-app webitel-uac webitel-api
```

### Storage service
```shell
apt install webitel-storage

cp /opt/webitel/etc/systemd/system/storage.service /etc/systemd/system/

systemctl enable --now storage
```

### Engine service
```shell
apt install webitel-engine

cp /opt/webitel/etc/systemd/system/engine.service /etc/systemd/system/

systemctl enable --now engine
```

### FlowManager service
```shell
apt install webitel-flow-manager

cp /opt/webitel/etc/systemd/system/flow_manager.service /etc/systemd/system/

systemctl enable --now flow_manager
```

### Messages service
```shell
apt install webitel-messages

cp /opt/webitel/etc/systemd/system/messages-bot.service /etc/systemd/system/
cp /opt/webitel/etc/systemd/system/messages-srv.service /etc/systemd/system/

systemctl enable --now messages-bot messages-srv
```

### CallCenter service
```shell
apt install webitel-call-center

cp /opt/webitel/etc/systemd/system/call_center.service /etc/systemd/system/

systemctl enable --now call_center
```

### Cases service
```shell
apt install webitel-cases

cp /opt/webitel/etc/default/webitel-cases /etc/default/
cp /opt/webitel/etc/systemd/system/webitel-cases.service /etc/systemd/system/

systemctl enable --now webitel-cases
```

### Logger service
```shell
apt install webitel-logger

cp /opt/webitel/etc/systemd/system/webitel-logger.service /etc/systemd/system/

systemctl enable --now webitel-logger
```

## Addons

### Logrotate

Edit file `/etc/logrotate.d/rsyslog`:
```shell
/var/log/syslog
{
        rotate 7
        daily
        size=2048M
        missingok
        notifempty
        delaycompress
        compress
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}

/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
        rotate 4
        size=1024M
        daily
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
```







