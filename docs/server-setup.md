# Конфигурация виртуальной машины devops-vm

Фактически выполнено и проверено 28.10.2026. Репозиторий: https://github.com/OverGoat157/devops-course-2026.

## 1. Параметры машины

- Oracle VirtualBox 7.1.18r173720, гипервизор типа 2.
- Ubuntu Server 24.04.5 LTS, ядро 6.8.0-147-generic; `lsb_release -ds`: `Ubuntu 24.04.5 LTS`.
- Имя VM: `devops-vm`; UUID `198572eb-aac9-471f-b9e6-a1901ca03d74`.
- RAM: 2048 МБ; CPU: 2; динамический диск VDI: 25600 МБ (25 ГиБ).
- Виртуальный диск `/dev/sda`, корневой раздел `/dev/sda2`, файловая система ext4.
- Короткое имя: `devops-vm`; `hostname -f`: `devops-vm.devops.local`.
- Установлены обновления ОС, `openssh-server`, `ufw`.
- Установочный ISO повторно не использовался: Ubuntu уже была установлена в существующей VM. Забытый пароль student сброшен через разовую загрузку с `init=/bin/bash`; обычная загрузка затем восстановлена. Перед этим создан резервный снимок 00-before-password-reset.

## 2. Сетевые интерфейсы

| Интерфейс | Тип адаптера | Адрес/маска | Назначение |
| --- | --- | --- | --- |
| enp0s3 | NAT | 10.0.2.15/24 | Интернет, обновления, SSH через проброс |
| enp0s8 | Host-only, vboxnet0 | 192.168.56.101/24 | Прямой доступ с хоста, будущий веб-сервер |

Хост: `vboxnet0`, `192.168.56.1/24`. DHCP: `192.168.56.100`, пул `192.168.56.101–192.168.56.254`, маска `255.255.255.0`, включён. Адрес выдан DHCP: после отката или изменения сети проверять `ip -brief address` и при необходимости обновлять hosts.

Существующий `/etc/netplan/50-cloud-init.yaml` сохранён:

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
```

Создан `/etc/netplan/60-hostonly.yaml`, права 600:

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
      optional: true
```

Применение: `sudo netplan generate && sudo netplan apply`.

На хосте в `/etc/hosts` добавлено `192.168.56.101 devops.local`. Остальные записи сохранены, резервная копия — `/etc/hosts.backup-devops-practice5`.

В VM `/etc/hosts` первоначально был пуст; создано содержимое:

```text
127.0.0.1 localhost
127.0.1.1 devops-vm.devops.local devops-vm
::1 localhost ip6-localhost ip6-loopback
```

Создан `/etc/cloud/cloud.cfg.d/99-practice5-hostname.cfg` для сохранения настройки после перезагрузки:

```yaml
preserve_hostname: true
manage_etc_hosts: false
```

Проверки на хосте: `getent hosts devops.local`, `ping -c 3 devops.local`, `ssh devops.local 'hostname -f'`.

## 3. Правило проброса портов

Имя `ssh`, TCP; IP хоста `127.0.0.1`; порт хоста `2222`; IP гостя не задан. Исходный гостевой порт — 22, итоговый — 2222:

```text
127.0.0.1:2222 → VM:2222
```

Изменение на работающей VM:

```bash
VBoxManage controlvm devops-vm natpf1 delete ssh
VBoxManage controlvm devops-vm natpf1 'ssh,tcp,127.0.0.1,2222,,2222'
```

При восстановлении порта 22 последнюю цифру правила также заменить на 22.

## 4. Учётные записи

- `student`: UID/GID 1000, группы `student`, `sudo`; вход через локальную консоль. После `AllowUsers devops` SSH-вход для student запрещён.
- `devops`: UID/GID 1001, группы `devops`, `sudo`, `users`; создан `sudo adduser devops`, включён `sudo usermod -aG sudo devops`.
- Вход devops по ключу Ed25519; sudo требует пароль devops. `NOPASSWD` не настраивался.
- Закрытый ключ остаётся на хосте: `~/.ssh/devops_vm`, права 600; открытый — `~/.ssh/devops_vm.pub`.
- В VM: `/home/devops/.ssh` — 700, `/home/devops/.ssh/authorized_keys` — 600, владелец devops.
- Ключ клиента: `SHA256:k0e9yCxcfbmO9vPlybXrqVRYFlycHdpLzaNaYrubQ4o`.
- Ключ сервера Ed25519: `SHA256:xnKY5ESjlI1phoOsZZobRVlq8+zXiS5OJmtQKemUDbs`; отпечаток сверён с консолью VM до первого SSH-входа.
- Исходно сервер предлагал `publickey,password`; после hardening — `publickey`.

Добавленные блоки `~/.ssh/config` на хосте (права 600):

```sshconfig
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes

Host devops.local
    HostName devops.local
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```

Существующие блоки для других серверов сохранены; резервная копия — `~/.ssh/config.backup-devops-practice5`. Пароли и закрытые ключи не включены в репозиторий и отчёт.

## 5. Служба SSH

Резервные копии: `/etc/ssh/sshd_config.backup` и `/etc/ssh/sshd_config.d.backup-practice5`. Основной `sshd_config` не изменялся. До hardening каталог `sshd_config.d` был пуст, ранних конфликтов не обнаружено. Основной файл содержит `Include /etc/ssh/sshd_config.d/*.conf` и `KbdInteractiveAuthentication no`.

Создан `/etc/ssh/sshd_config.d/99-hardening.conf`:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Проверка и применение:

```bash
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh
sudo ss -tlnp | grep sshd
```

Фактически слушаются `0.0.0.0:2222` и `[::]:2222`; SSH на 22 не слушает. `ssh.service` — enabled, `ssh.socket` — disabled.

На протяжении изменения сохранено установленное SSH-соединение через ControlMaster; после изменения NAT проверено новое соединение `ssh devops`. Для root с ключом и для devops с `PubkeyAuthentication=no` получены `Permission denied (publickey)` и код 255. В журнале root: `not allowed because not listed in AllowUsers`; для клиента без ключа: закрытие соединения на этапе `preauth`. Одинаковое сообщение клиента не означает одинаковую причину отказа.

## 6. Правила межсетевого экрана

UFW активен; `deny (incoming)`, `allow (outgoing)`, `disabled (routed)`; логирование medium. Итоговые правила для IPv4 и IPv6:

| Порт | Действие | Источник |
| --- | --- | --- |
| 2222/tcp | LIMIT IN | Anywhere / Anywhere (v6) |
| 80/tcp | ALLOW IN | Anywhere / Anywhere (v6) |
| 443/tcp | ALLOW IN | Anywhere / Anywhere (v6) |

Порядок настройки:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw enable
# На хосте проверить новое соединение: ssh devops
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw logging medium
sudo ufw status verbose
```

В установленной версии UFW команда `limit` обновила существующее правило ALLOW (`Rule updated`); дополнительное удаление ALLOW сообщило `Could not delete non-existent rule`. После проверки осталось только LIMIT — отдельного ALLOW на 2222 нет.

Проверка закрытого порта на хосте:

```bash
curl --noproxy '*' -m 3 http://192.168.56.101:8080
```

Получены тайм-аут и код curl 28. Записи доступны в `/var/log/ufw.log` и `sudo journalctl -k`: `SRC=192.168.56.1`, `DST=192.168.56.101`, `PROTO=TCP`, `DPT=8080`.

Скрипт аудита в VM: `~/scripts/audit.sh`; в репозитории: `scripts/audit.sh`. Запускать от devops с доступом sudo:

```bash
~/scripts/audit.sh
echo $?
```

Фактически: 6 OK, 0 FAIL, код 0. При временной замене `MaxAuthTries 3` на `10` — 5 OK, 1 FAIL, код 1. После возврата к 3 — снова 6 OK и код 0. Для отрицательной проверки SSH не перезапускался: `sshd -T` читает конфигурацию с диска.

Факультативно проверен туннель `ssh -L 127.0.0.1:9090:127.0.0.1:8080 -N devops` к HTTP-серверу на `127.0.0.1:8080` внутри VM. Прямой запрос блокировался; через туннель получена HTML-страница. После проверки сервер и туннель остановлены, правило на 8080 не добавлялось.

## 7. Снимки состояния

Время Europe/Moscow, 28.10.2026:

| Снимок | Время | Состояние |
| --- | --- | --- |
| 00-before-password-reset | 03:38:51 | Дополнительная страховка перед сбросом пароля student |
| 01-clean-install | 03:42:25 | Обновлённая ОС, оба адреса, OpenSSH на 22; VM выключена |
| 02-keys-configured | 03:42:38 | Создан devops, установлен ключ, вход и права проверены |
| 03-ssh-hardened | 03:43:05 | SSH на 2222, запреты root/пароля проверены; до UFW и FQDN |

Итоговая настроенная VM сохранена для следующих практических работ; текущее состояние содержит также UFW, FQDN и audit.sh. Откат к 03 убирает последующие настройки UFW/имени — это ожидаемый порядок методички.

### Восстановление из 01-clean-install

1. Штатно выключить VM, восстановить снимок 01-clean-install. Проверить правило NAT: гостевой порт 22; первый адаптер NAT, второй vboxnet0. Запустить VM.
2. На хосте: `ssh student@127.0.0.1 -p 2222`. Сверить ключ сервера. В VM: `sudo adduser devops` и `sudo usermod -aG sudo devops`.
3. На хосте: `ssh-copy-id -i ~/.ssh/devops_vm.pub -p 2222 devops@127.0.0.1`. Проверить `ssh devops` и права 700/600. Сохранить эту сессию; консоль VirtualBox остаётся доступной.
4. В VM сохранить резервные копии SSH и создать 99-hardening.conf с полным содержимым из раздела 5. Выполнить `sudo /usr/sbin/sshd -t` и проверить `sudo /usr/sbin/sshd -T`. Ранних конфликтов в исходном снимке нет.
5. Отключить ssh.socket, включить и перезапустить ssh.service командами раздела 5. На хосте заменить гостевой порт NAT на 2222. В отдельном терминале проверить новый `ssh devops`; затем проверить отказы root/входа без ключа.
6. Настроить UFW командами раздела 6. Проверить новое SSH-соединение после enable и после LIMIT.
7. В VM выполнить `sudo hostnamectl set-hostname devops-vm`; создать `/etc/hosts` и `/etc/cloud/cloud.cfg.d/99-practice5-hostname.cfg` с содержимым из раздела 2. Проверить `hostname -f`. На хосте проверить соответствие `devops.local` фактическому Host-only адресу.
8. Из корня репозитория на хосте: `ssh devops 'mkdir -p ~/scripts'`, `scp scripts/audit.sh devops:~/scripts/audit.sh`. В VM: `chmod +x ~/scripts/audit.sh`, `~/scripts/audit.sh`, сразу `echo $?`. Должно быть 6 OK и 0.
9. Проверить `ssh devops.local 'hostname -f'`, `sudo ufw status verbose`, `sudo ss -tlnp`. Убедиться, что VM остаётся сохранённой для работы 6.

Пароль student после сброса и пароль devops сохранены только в приватном локальном каталоге пользователя. Они не публикуются в Git.

## 8. Веб-сервер

Практика 6 выполнена 28.10.2026. Перед настройкой проверено восстановление из 01-clean-install по разделам 1–7: настройки восстановлены за 12,5 с, аудит — 6/6, код 0. Полное состояние работы 5 сохранено снимком 03a-practice5-complete.

Пакет: nginx из репозитория Ubuntu, версия 1.24.0; rsync установлен на хосте и в VM. Nginx включён в автозагрузку. Master работает от root, workers — www-data. Доступ с хоста идёт напрямую через Host-only, без проброса портов HTTP.

- Конфигурация: /etc/nginx/sites-available/devops-site; ссылка /etc/nginx/sites-enabled/devops-site.
- Ссылка sites-enabled/default удалена, исходный sites-available/default сохранён.
- Каталог /var/www/devops-site: devops:devops, 755; index.html и 404.html — 644. www-data читает содержимое, но не имеет права записи.
- Логи: /var/log/nginx/devops-site.access.log и /var/log/nginx/devops-site.error.log.
- TLS-сертификат: /etc/ssl/certs/devops.crt, root:root, 644. Закрытый ключ: /etc/ssl/private/devops.key, root:root, 600; он остаётся исключительно в VM.
- Сертификат самоподписанный, RSA 2048, срок 365 дней, SAN DNS:devops.local. HSTS не включён.

Команда выпуска:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj /CN=devops.local -addext subjectAltName=DNS:devops.local
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
```

Конфигурация ресурса:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name devops.local;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name devops.local;
    ssl_certificate /etc/ssl/certs/devops.crt;
    ssl_certificate_key /etc/ssl/private/devops.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/devops-site;
    index index.html;
    location / { try_files $uri $uri/ =404; }
    error_page 404 /404.html;
    access_log /var/log/nginx/devops-site.access.log;
    error_log /var/log/nginx/devops-site.error.log;
}
```

После каждого изменения: `sudo nginx -t && sudo systemctl reload nginx`. HTTP возвращает 301 на HTTPS; HTTPS — 200, неизвестный путь — собственную страницу 404 с кодом 404. Запрос curl без доверенного сертификата возвращает ошибку 60. Открытый сертификат получен на хост через проверенное SSH-соединение:

```bash
scp devops:/etc/ssl/certs/devops.crt ~/devops.crt
curl --cacert ~/devops.crt -I https://devops.local/
```

Код и страницы: `site/`, деплой: `scripts/deploy.sh [--dry-run]`. Скрипт работает из любого каталога, требует чистый Git и наличие index.html, выполняет один rsync с `--delete --chmod=D755,F644`, использует BatchMode/ConnectTimeout, проверяет HTTPS с --cacert, сообщает короткий SHA и возвращает 0 при успехе, 1 при ошибке. Новый вариант rsync --delete сначала проверен с --dry-run.

Проверены все пять сценариев деплоя, включая staged-изменения. Опыты с правами: файл 600 → 403; каталог 755 → 200, 750 → 403, 744 → 403, 711 → 200. Доставка 666 без --chmod позволила www-data подменить HTML; штатный деплой восстановил страницу и 644/755. Итоговых файлов с правом записи всем нет.

Аудит дополнен четырьмя проверками: nginx активен; nginx -t успешен; сертификат годен минимум 30 дней; нет world-writable файлов и TLS-ключ имеет права 600. Всего 10 проверок; корректная конфигурация — код 0. `CERT_MIN_SECONDS=63072000` проверяет отказ по сроку, временный chmod 666 — отказ по правам, оба дают код 1; исходные значения восстановлены.

Снимок `04-nginx-https` создан после HTTPS и до rsync/самостоятельной части. Текущее состояние дополнительно содержит сайт, deploy.sh и расширенный audit.sh. Для восстановления после снимка: доставить site/ через deploy.sh (или rsync с --chmod), скопировать audit.sh в ~/scripts/ и проверить аудит. Для восстановления с 01 сначала выполнить разделы 1–7, затем установить nginx/rsync, создать каталог и конфигурацию выше, выпустить сертификат, включить сайт и проверить HTTPS.

## 9. Контейнеризация

Практика 7 выполнена 28.10.2026 на той же VM. Docker Engine 29.9.2, Docker Compose v5.6.1, Buildx 0.38.1 установлены из официального apt-репозитория https://download.docker.com/linux/ubuntu (noble/stable), а не из docker.io. Ключ репозитория: /etc/apt/keyrings/docker.asc; источник: /etc/apt/sources.list.d/docker.sources. Команды установки приведены в официальной инструкции https://docs.docker.com/engine/install/ubuntu/ . Служба docker включена в автозагрузку.

В группе docker только devops (UID 1001); он уже входит в sudo. После usermod -aG docker devops создана новая SSH-сессия, hello-world выполнен без sudo. Членство docker предоставляет фактический root-доступ к VM, поскольку позволяет управлять Docker socket.

Исходники: app/ в репозитории, серверный проект: /home/devops/app. Образ devops-app:1.0 на базе python:3.12-slim; Flask 3.0.3, psycopg2-binary 2.9.9, gunicorn 22.0.0 соответствуют заданию. Процесс работает от app, UID/GID 999, а файлы образа принадлежат root и доступны app только для чтения. Изменённый текст: Hello from Docker, Епифанов!

Dockerfile:

```dockerfile
FROM python:3.12-slim

RUN useradd --system --no-create-home app
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

USER app
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "app:app"]
```

Порядок COPY сохраняет кэш pip при изменении app.py. Первая проверка без СУБД: /health → 200, / → 500 с psycopg2.OperationalError и Connection refused для localhost:5432. В Compose DB_HOST=db использует DNS общей сети; localhost внутри отдельного контейнера относится к нему самому.

Файл /home/devops/app/.env создан только в VM со случайным POSTGRES_PASSWORD (openssl rand -hex 16), владелец devops, права 600. На хост он не копировался. .env исключён из Git и Docker build context; в репозитории только .env.example с заглушкой. Доставка:

```bash
rsync -avz --delete --exclude=.env --dry-run app/ devops:app/
rsync -avz --delete --exclude=.env app/ devops:app/
```

Исключение защищает серверный секрет от удаления при --delete. Создание .env при первом развёртывании, выполнять в VM:

```bash
cd ~/app
umask 077
cp .env.example .env
chmod 600 .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/" .env
```

Не повторять генерацию пароля поверх работающей СУБД без согласованной смены пароля в PostgreSQL: env_file не меняет пароль уже инициализированной БД.

Compose:

```yaml
services:
  db:
    image: postgres:16-alpine
    env_file: .env
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped

  app:
    build: .
    image: devops-app:1.0
    env_file: .env
    ports:
      - "127.0.0.1:5000:5000"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - backend
    restart: unless-stopped

volumes:
  db_data:

networks:
  backend:
```

- Проект app: контейнеры app-app-1 и app-db-1.
- Сеть app_backend типа bridge, сервис db разрешается встроенным DNS.
- Именованный том app_db_data хранит /var/lib/postgresql/data.
- PostgreSQL: postgres:16-alpine, порт 5432 доступен только внутри сети, на VM не публикуется.
- Приложение: только 127.0.0.1:5000 → контейнер:5000.
- depends_on condition: service_healthy ждёт успешного pg_isready; restart: unless-stopped задан обоим сервисам.

Запуск: `cd ~/app && docker compose up -d --build`. Проверки: `docker compose ps`, `docker compose exec -T app id`, `docker compose exec -T app getent hosts db`, `sudo ss -tlnp`. Запросы к / увеличивают Visits. Проверено: down/up сохраняет счётчик через именованный том; down -v на свежих учебных данных удаляет том, первый запрос после нового up возвращает Visits: 1. В итоговом состоянии том сохранён.

Обратный прокси: в HTTPS server /etc/nginx/sites-available/devops-site добавлено:

```nginx
    location /app/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
```

Применение: `sudo nginx -t && sudo systemctl reload nginx`. Завершающий / заменяет префикс /app/: /app/health передаётся как /health. Статический root /var/www/devops-site и прямой deploy.sh из работы 6 сохранены; / → статическая страница, /app/ → счётчик, /app/health → ok. TLS завершает Nginx, внутри VM к приложению идёт HTTP.

Воспроизведён учебный обход UFW: отдельный контейнер exposed опубликован на 0.0.0.0:5001; при отсутствии правила UFW запрос с хоста к :5001/health дал 200. Docker создаёт NAT/forwarding-правила, обходящие обычную INPUT-политику UFW. После проверки exposed остановлен. Итоговая публикация приложения только на loopback.

Остановка app дала Nginx 502 и connect() failed (111: Connection refused) while connecting to upstream; app затем снова запущен. Это отказ на участке Nginx → приложение, а не ошибка TLS клиента.

Аудит дополнен четырьмя проверками: Docker активен; app-db-1 healthy; ни 5000, ни 5432 не слушаются на адресах, отличных от 127.0.0.1; ~/app/.env имеет 600. Всего 14 проверок. Для отрицательного теста публикация временно изменена на 5000:5000, после up -d аудит дал 1; затем loopback-публикация восстановлена и аудит возвращает 0.

Снимок 05-docker-compose создан после проверки тома и до добавления обратного прокси/расширения аудита. После отката к нему нужно добавить location /app/, проверить/reload Nginx и доставить итоговый audit.sh в ~/scripts/. Для восстановления с 01 сначала выполнить разделы 1–8, установить Docker по официальной инструкции, добавить devops в docker и переподключиться, доставить app с --exclude=.env, создать серверный .env, запустить Compose и проверить HTTPS/аудит.
