#!/usr/bin/env bash
# Запускать внутри учебной Ubuntu VM от пользователя devops с правом sudo.
set -uo pipefail
export LC_ALL=C

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        printf ' [OK]   %s\n' "$desc"
        ((PASS+=1))
    else
        printf " [FAIL] %s (ожидалось: '%s', получено: '%s')\n" "$desc" "$expected" "$actual"
        ((FAIL+=1))
    fi
}

if ! sudo -v; then
    printf 'Не удалось получить права sudo.\n' >&2
    exit 1
fi
if ! SSH_CONFIG=$(sudo /usr/sbin/sshd -T); then
    printf 'Не удалось прочитать действующую конфигурацию sshd.\n' >&2
    exit 1
fi

printf 'Аудит конфигурации: %s, %s\n' "$(hostname -f)" "$(date '+%Y-%m-%d %H:%M')"

printf '[1] Служба SSH\n'
check 'Вход от имени root запрещён' 'no' "$(awk '$1=="permitrootlogin" {print $2}' <<< "$SSH_CONFIG")"
check 'Парольная аутентификация отключена' 'no' "$(awk '$1=="passwordauthentication" {print $2}' <<< "$SSH_CONFIG")"
# Проверка 1: каждый настроенный порт SSH должен отличаться от 22.
PORT_CHECK=$(awk '$1=="port" {found=1; if ($2==22) bad=1} END {print (found && !bad) ? "yes" : "no"}' <<< "$SSH_CONFIG")
check 'Все порты SSH отличаются от 22' 'yes' "$PORT_CHECK"
# Проверка 2: проверка MaxAuthTries.
check 'MaxAuthTries равен 3' '3' "$(awk '$1=="maxauthtries" {print $2}' <<< "$SSH_CONFIG")"

printf '[2] Межсетевой экран\n'
if ! UFW_STATUS=$(sudo env LC_ALL=C ufw status verbose); then
    printf 'Не удалось получить состояние UFW.\n' >&2
    exit 1
fi
check 'Межсетевой экран активен' 'active' "$(awk '/^Status:/ {print $2}' <<< "$UFW_STATUS")"
# Проверка 3: политика по умолчанию для входящего трафика.
check 'Политика входящего трафика — deny' 'deny' "$(sed -nE 's/^Default: ([^ ]+) \(incoming\).*/\1/p' <<< "$UFW_STATUS")"

printf '[3] Учётные записи\n'
awk -F: '$3>=1000 && $3<65534 {printf "        %s (uid=%s)\n", $1, $3}' /etc/passwd

printf 'Пройдено: %s, не пройдено: %s\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
    exit 0
fi
exit 1
