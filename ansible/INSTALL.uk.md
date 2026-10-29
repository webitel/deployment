# Встановлення Webitel 26.6

Webitel встановлюється одним із двох способів:

- **Через Ansible** (рекомендовано). Плейбук із репозиторію
  [webitel/deployment](https://github.com/webitel/deployment) ставить на Debian увесь стек –
  PostgreSQL, RabbitMQ, Consul, FreeSWITCH, OpenSIPS, rtpengine, NGINX, Grafana і сервіси
  Webitel – і налаштовує його під обраний профіль.
- **Вручну**, компонент за компонентом. Див. розділ «Встановлення вручну».

## Профілі

Профіль визначає, скільки серверів використовується і як резервуються компоненти.
Цей посібник описує `singlehost` і `multihost`.

|  | `singlehost` | `multihost` | `failover` | `warm_standby` | `stretch` |
| --- | --- | --- | --- | --- | --- |
| Приклад інвентаря | `singlehost.example` | `multihost.example` | `failover.example` | `warm-standby-2dc.example` | – |
| Дата-центри | 1 (один сервер) | 1 | 1 | 2+ | 3+ |
| PostgreSQL | окремий | окремий | кластер Patroni | основний + N резервних кластерів | один кластер на всі ДЦ |
| Consul | 1 сервер | 1 сервер | кластер, 3+ (непарна кількість) | окремий кластер у кожному ДЦ | один кластер, три зони відмови |
| RabbitMQ / Nomad | один вузол | один вузол | кластер | кластер у кожному ДЦ | кластер у кожному ДЦ |
| Витримує | – | втрату сервера без БД | втрату одного вузла | втрату ДЦ | втрату ДЦ |
| Перемикання БД | – | – | Patroni, автоматично | вручну | Patroni, автоматично |
| RPO | остання резервна копія | остання резервна копія | ~0 (≤ 1 MiB WAL) | затримка реплікації | ~0, або 0 у синхронному режимі |
| RTO | години | години | ~30–45 с | від хвилин до годин | ~60–90 с |

RPO і RTO – цільові значення для бази даних із налаштуваннями за замовчуванням, а не гарантії.

Навантаження: `singlehost` – до 30–40 тис. дзвінків на день (близько 60 одночасних
дзвінків із записом) і до 50 тис. чат-діалогів на день. Для `multihost` див.
[Базова архітектура промислового середовища](https://webitel.atlassian.net/wiki/x/6wNeAQ).

## Вимоги

**Сервери**

- Процесор x86-64 (amd64).
- Debian 12 (bookworm) або 13 (trixie) з доступом в інтернет.
- `singlehost`: від 4 ядер / 8 потоків 3,0 GHz, 8 GB RAM, 100 GB диска (>150 IOPS).
- `multihost`: див. [Базова архітектура промислового середовища](https://webitel.atlassian.net/wiki/x/6wNeAQ).
- Для записів розмов – окремий диск або S3-сховище.
- `multihost`: сервери в одній приватній мережі без обмежень доступу між ними.

**Машина для запуску Ansible** – будь-який Linux-сервер або один із серверів Webitel,
з SSH-доступом і правами `sudo` на всіх серверах.

## Передумови

- Ключі до APT-репозиторію Webitel (access key і secret key) – запросіть у менеджера Webitel.
- SignalWire Personal Access Token для FreeSWITCH –
  [як створити](https://freeswitch.org/confluence/display/FREESWITCH/HOWTO+Create+a+SignalWire+Personal+Access+Token).
- Для HTTPS (потрібен для WebRTC) – одне з:
  - доменне ім'я, що вказує на сервер з NGINX, – для сертифіката Let's Encrypt;
  - власний сертифікат і ключ у форматі PEM;
  - самопідписаний сертифікат (за замовчуванням, браузер покаже попередження).

## Підготовка

Виконайте на машині, з якої запускатимете Ansible.

1. Встановіть Ansible.

   Debian 13:

   ```bash
   apt install git sudo ansible-core python3-cryptography
   ```

   Debian 12:

   ```bash
   apt install git sudo pipx
   pipx install --include-deps ansible-core
   pipx inject ansible-core cryptography
   pipx ensurepath && exec bash
   ```

2. Перевірте, що версія `ansible-core` – 2.16 або новіша:

   ```bash
   ansible --version
   ```

3. Завантажте плейбук і встановіть колекції Ansible:

   ```bash
   cd /opt
   git clone --single-branch -b v26.06 https://github.com/webitel/deployment.git
   cd deployment/ansible
   ansible-galaxy collection install -r requirements.yml
   ```

## Налаштування

Плейбук налаштовується через інвентар – каталог із трьома файлами:

- `01-hosts.yml` – сервери і сервіси на кожному;
- `group_vars/all/main.yml` – параметри;
- `group_vars/all/vault.yml` – секрети.

Створіть інвентар із прикладу вашого профілю:

```bash
cp -r inventories/<профіль>.example inventories/production
```

### Загальні параметри

У `inventories/production/group_vars/all/main.yml`:

| Параметр | Значення |
| --- | --- |
| `nginx_site_name` | Доменне ім'я сервера з NGINX. |
| `nginx_tls_mode` | `self_signed` (за замовчуванням), `letsencrypt` або `provided`. |
| `nginx_mail_address` | Email для Let's Encrypt – лише для `letsencrypt`. |
| `nginx_tls_cert`, `nginx_tls_key` | Шляхи до сертифіката і ключа на машині з Ansible – лише для `provided`. |
| `rtpengine_mode` | `global` – дзвінки з інтернету, `local` – лише локальна мережа. |
| `rtpengine_public_address` | Публічна IP-адреса для медіа, якщо вона не визначається автоматично. |
| `opensips_fail2ban` | `true` – [захист від SIP-атак](https://www.opensips.org/Documentation/Tutorials-Fail2Ban). |
| `grafana_basic_dashboards` | `true` – встановити базові дашборди Grafana. |
| `base_timezone` | Часовий пояс серверів, за замовчуванням `UTC`. |
| `http_proxy`, `https_proxy` | Проксі, якщо сервери виходять в інтернет лише через нього. |

### Загальні секрети

Скопіюйте шаблон і замініть усі значення `CHANGE_ME`:

```bash
cp inventories/production/group_vars/all/vault.yml.example \
   inventories/production/group_vars/all/vault.yml
$EDITOR inventories/production/group_vars/all/vault.yml
```

| Ключ | Значення |
| --- | --- |
| `vault_webitel_repo_s3_access_key`, `vault_webitel_repo_s3_secret_key` | Ключі до APT-репозиторію Webitel. |
| `vault_freeswitch_signalwire_key` | Токен SignalWire. |
| `vault_webitel_cookie_seed` | Випадковий рядок: `openssl rand -hex 32`. |
| `vault_webitel_pg_password`, `vault_webitel_amqp_password` | Паролі PostgreSQL і RabbitMQ. |
| `vault_grafana_admin_password` | Пароль адміністратора Grafana. |
| `vault_grafana_db_password`, `vault_grafana_datasource_password` | Паролі бази даних Grafana. |

Паролі – лише з літер, цифр і символів `.` `_` `~` `-`, наприклад `openssl rand -hex 16`.

### singlehost

У `inventories/production/01-hosts.yml` вкажіть адресу сервера. Список сервісів не змінюйте.

Ansible на самому сервері:

```yaml
all:
  hosts:
    node1:
      ansible_host: 127.0.0.1
      ansible_connection: local
```

Ansible на іншій машині:

```yaml
all:
  hosts:
    node1:
      ansible_host: 203.0.113.10
      ansible_user: admin
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### multihost

У `inventories/production/01-hosts.yml` вкажіть сервери і сервіси на кожному. У прикладі
інфраструктура на `infra1`, застосунки Webitel – на `app1`:

```yaml
all:
  hosts:
    infra1:
      ansible_host: 10.0.0.11
      ansible_user: admin
      services: [consul_server, postgres, rabbitmq, freeswitch, rtpengine, opensips]
    app1:
      ansible_host: 10.0.0.12
      ansible_user: admin
      services:
        - consul_agent
        - nginx
        - grafana
        - webitel_core
        - webitel_engine
        - webitel_call_center
        - webitel_flow_manager
        - webitel_storage
        - webitel_messages
        - webitel_logger
        - webitel_cases
        - webitel_media_exporter
        - webitel_frontend
```

Додатково у `vault.yml`:

| Ключ | Значення |
| --- | --- |
| `vault_consul_encrypt_key` | Ключ шифрування Consul: `openssl rand -base64 32`. |

Паролі не можуть залишатися стандартними (`webitel`).

Перевірте інвентар:

```bash
ansible-playbook -i inventories/production playbooks/validate_topology.yml
```

## Запуск

1. Зашифруйте секрети і запам'ятайте пароль:

   ```bash
   ansible-vault encrypt inventories/production/group_vars/all/vault.yml
   ```

2. Запустіть плейбук:

   ```bash
   ansible-playbook -i inventories/production site.yml --ask-vault-pass
   ```

Плейбук спершу перевіряє налаштування і зупиняється з поясненням, якщо щось не так.
Виправте вказане і запустіть ще раз – повторний запуск безпечний.

## Ліцензування

1. Наприкінці встановлення плейбук виводить ідентифікатор сервера. Його також можна
   отримати на сервері з NGINX:

   ```bash
   curl -k https://localhost/api/srvinfo
   ```

2. Створіть [звернення на порталі підтримки](https://cs.my.webitel.com/servicedesk/customer/portal/3)
   з цим ідентифікатором.
3. Відкрийте `https://<nginx_site_name>`, створіть користувача і домен з отриманим
   ліцензійним ключем.
4. Відкрийте Admin і [перейдіть до налаштувань системи](https://webitel.atlassian.net/wiki/spaces/WEP/pages/21310528).

## Мережевий доступ

З інтернету відкрийте лише `443/tcp` (веб-інтерфейс і WebRTC), `80/tcp` (переадресація
на HTTPS і Let's Encrypt), а також SIP і RTP за вашою схемою підключення.

## Встановлення вручну

Встановіть компоненти в такому порядку. У кожному каталозі – інструкція, приклади
конфігурації і файли сервісів:

1. [PostgreSQL](https://github.com/webitel/deployment/tree/v26.06/postgresql)
2. [Consul](https://github.com/webitel/deployment/tree/v26.06/consul)
3. [RabbitMQ](https://github.com/webitel/deployment/tree/v26.06/rabbitmq)
4. [RTPEngine](https://github.com/webitel/deployment/tree/v26.06/rtpengine)
5. [OpenSIPS](https://github.com/webitel/deployment/tree/v26.06/opensips)
6. [Сервіси Webitel](https://github.com/webitel/deployment/tree/v26.06/webitel)
7. [FreeSWITCH](https://github.com/webitel/deployment/tree/v26.06/freeswitch)
8. [NGINX](https://github.com/webitel/deployment/tree/v26.06/nginx)

Потім перейдіть до розділу «Ліцензування».
