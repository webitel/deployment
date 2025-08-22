# OpenSIPS

OpenSIPS is a GPL implementation of a multi-functionality SIP Server that targets to deliver a high-level 
technical solution (performance, security and quality).

## Install
```shell
curl https://apt.opensips.org/opensips-org.gpg -o /usr/share/keyrings/opensips-org.gpg
echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org bookworm 3.4-releases" > /etc/apt/sources.list.d/opensips.list
echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org bookworm cli-nightly" > /etc/apt/sources.list.d/opensips-cli.list
    
apt update
apt install opensips opensips-http-modules opensips-postgres-module \
  opensips-presence-modules opensips-rabbitmq-modules opensips-wss-module \
  opensips-tls-module opensips-tlsmgm-module opensips-xmlrpc-module \
  opensips-auth-modules opensips-tls-wolfssl-module
```

## Configure

### Download the config file
```shell
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/opensips/opensips.cfg \
  -o /etc/opensips/opensips.cfg
```

## Run
```shell
systemctl enable opensips
systemctl restart opensips
```


## Addons

### Fail2Ban

To make opensips work with `fail2ban`, you will have to send the logs to a different file than `/var/log/syslog`.

- Change the `log_facility`:
    ```diff
    - log_facility=LOG_LOCAL0
    + log_facility=LOG_LOCAL7
    ```

- Match the loglevel with a new log file, add to `/etc/rsyslog.conf`:
    ```shell
    local7.* /var/log/opensips.log
    ```

- Install `fail2ban`.
    ```shell
    apt-get install fail2ban
    ```

- Add the new jail for `fail2ban` to `/etc/fail2ban/jail.conf`:
    ```
    [opensips]
    enabled  = true
    filter   = opensips
    action   = iptables-allports[name=opensips, protocol=all]
    logpath  = /var/log/opensips.log
    maxretry = 5
    bantime = 3600
    ```

- Create a new `fail2ban` filter in `/etc/fail2ban/filter.d/opensips.conf`:
    ```shell
    # Fail2Ban configuration file
    #
    #
    # $Revision: 250 $
    #

    [INCLUDES]

    # Read common prefixes. If any customizations available -- read them from
    # common.local
    #before = common.conf


    [Definition]

    #_daemon = opensips

    # Option:  failregex
    # Notes.:  regex to match the password failures messages in the logfile. The
    #          host must be matched by a group named "host". The tag "<HOST>" can
    #          be used for standard IP/hostname matching and is only an alias for
    #          (?:::f{4,6}:)?(?P<host>\S+)
    # Values:  TEXT
    #

    failregex = Auth error for .* from <HOST> (.*) cause -[0-9]

    # Option:  ignoreregex
    # Notes.:  regex to ignore. If this regex matches, the line is ignored.
    # Values:  TEXT
    #
    ignoreregex =
    ```

- Configure `logrotate` target in `/etc/logrotate.d/opensips`:
    ```
    /var/log/opensips.log {
        rotate 5
        daily
        compress
        copytruncate
        sharedscripts
        missingok
        notifempty
        postrotate
            /bin/kill -HUP `pgrep syslogd 2>/dev/null` 2>/dev/null || true
        endscript
    }
    ```
  
- Restart to apply configuration:
    ```shell
    touch /var/log/opensips.log
    systemctl restart rsyslog
    systemctl restart logrotate
    systemctl enable fail2ban
    systemctl restart fail2ban
    ```
    