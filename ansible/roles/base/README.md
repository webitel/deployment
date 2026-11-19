# base

Common host preparation: packages, locales, sysctl, timezone, NTP, Webitel APT repository.

- `webitel_repo_uri` (default `s3://webitel-apt-repo`) is the Webitel APT repository. With an
  `s3://` URI the role installs `apt-transport-s3` and needs the S3 keys; with `http(s)://`
  (a mirror such as Nexus) it adds the repository as is and the S3 keys are not used.
- `webitel_repo_key_url` downloads the armored key that signs `webitel_repo_uri` instead of
  the bundled Webitel key.
- With `apt_mirror_host` set, the role writes `/etc/apt/auth.conf.d/mirror.conf` with
  `apt_mirror_username` / `vault_apt_mirror_password`; with it empty, it removes that file.
- `base_timezone` (default `UTC`) sets the host timezone; empty keeps the host setting.
- `base_ntp_servers` installs `systemd-timesyncd` and sets its NTP servers; empty keeps the host setting.

See `defaults/main.yml` for configurable variables.
