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
