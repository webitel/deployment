# NGCP rtpengine

The [Sipwise](http://www.sipwise.com/) NGCP rtpengine is a proxy for RTP traffic and other UDP based
media traffic.

## Install
```shell
apt-get install -qqy --no-install-recommends gnupg2 wget lsb-release

wget https://deb.sipwise.com/spce/ngcp-keyring-latest.deb && \
  sudo dpkg -i ngcp-keyring-latest.deb && \
  rm ngcp-keyring-latest.deb

echo "deb https://deb.sipwise.com/spce/mr13.2.1 bookworm main" > /etc/apt/sources.list.d/rtpengine.list
apt-get update
apt-get install -qqy --no-install-recommends linux-headers-`uname -r` ngcp-rtpengine
```

## Configure

1. Download the config file:
    ```shell
    curl https://git.webitel.com/projects/WEP/repos/rtpengine/raw/rtpengine.conf \
      -o /etc/rtpengine/rtpengine.conf
    ```
2. Change external IP:
```diff
[rtpengine]

- interface = 1.1.1.1
+ interface = 8.8.8.8
```

## Run
```shell
systemctl disable ngcp-rtpengine-recording-daemon
systemctl enable ngcp-rtpengine-daemon
systemctl start ngcp-rtpengine-daemon
```


## Documentation

Check general [documentation](https://rtpengine.readthedocs.io/en/latest/).