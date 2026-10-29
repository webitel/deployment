# base

Common host preparation: packages, locales, sysctl, timezone, NTP, Webitel S3 APT repository.

- `base_timezone` (default `UTC`) sets the host timezone; empty keeps the host setting.
- `base_ntp_servers` installs `systemd-timesyncd` and sets its NTP servers; empty keeps the host setting.

See `defaults/main.yml` for configurable variables.
