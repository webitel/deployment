# base

Common host preparation: packages, locales, sysctl, timezone, NTP, Webitel APT repository.

- `webitel_repo_uri` (default `s3://webitel-apt-repo`) is the Webitel APT repository. With an
  `s3://` URI the role installs `apt-transport-s3` and needs the S3 keys; with `http(s)://`
  (a mirror such as Nexus) it adds the repository as is and the S3 keys are not used.
- `base_timezone` (default `UTC`) sets the host timezone; empty keeps the host setting.
- `base_ntp_servers` installs `systemd-timesyncd` and sets its NTP servers; empty keeps the host setting.

See `defaults/main.yml` for configurable variables.
