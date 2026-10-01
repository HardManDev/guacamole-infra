# Bastion сервер основанный на Apache Guacamole
В этом репозитории находится всё необходимое для развёртывания [Apache Guacamole](https://guacamole.apache.org/) на Linux-сервере. Отличительной особенностью является наличие конфигурации LDAPS, TOTP (двухфакторной аутентификации), session recording и file share, а также конфигурация Nginx.

## Подготовка к установке
1. Подготовьте Linux-сервер и проведите базовую настройку. Обязательно уделите внимание настройке безопасности!
2. Установите Docker Engine согласно [официальной документации docker](https://docs.docker.com/engine/install/ubuntu/).
3. Выберите тег версии Apache Guacamole, руководствуясь официальной страницей образа на [docker.io](https://hub.docker.com/r/guacamole/guacamole).
```bash
# Подставьте необходимую версию или тег latest
export GUAC_VERSION=1.6.0
```
> [!NOTE]
> В данном репозитории используется версия 1.6.0, а также в конфигурации проекта эта версия используется по умолчанию.

## Установка
1. Склонируйте репозиторий.
```bash
cd /opt
git clone https://github.com/HardManDev/guacamole-bastion.git
```
2. Измените права на директорию.
```bash
# Подставьте необходимое имя пользователя и группы
sudo chown user:user -R ./guacamole-bastion
```
3. Извлеките скрипт инициализации базы данных из официального образа Guacamole.
```bash
sudo docker run --rm guacamole/guacamole:$GUAC_VERSION /opt/guacamole/bin/initdb.sh --postgresql > ./init-scripts/initdb.sql
```
4. Подготовьте конфигурацию, используя переменные окружения.
```bash
sudo mv .env.example .env && nano .env
```
5. Запустите Docker Compose.
```bash
sudo docker compose up -d
```
6. Проверьте запуск.
```bash
sudo docker ps
#CONTAINER ID   IMAGE                         COMMAND                  CREATED       STATUS                 PORTS                      NAMES
#efa355643e58   guacamole-bastion-guacamole   "/opt/guacamole/bin/…"   9 hours ago   Up 9 hours             127.0.0.1:8080->8080/tcp   guacamole-web
#6347c2078ff0   postgres:17-alpine            "docker-entrypoint.s…"   9 hours ago   Up 9 hours             127.0.0.1:5432->5432/tcp   postgres
#418be0e8da44   guacamole/guacd:1.6.0         "/opt/guacamole/entr…"   9 hours ago   Up 9 hours (healthy)   4822/tcp                   guacamole-guacd

sudo ss -tulpn | grep docker-proxy
# tcp   LISTEN 0      4096          127.0.0.1:8080       0.0.0.0:*    users:(("docker-proxy",pid=29008,fd=8)
# tcp   LISTEN 0      4096          127.0.0.1:8080       0.0.0.0:*    users:(("docker-proxy",pid=29008,fd=8)
```
 7. Для корректной работы измените права на директорию `./guacamole_data/`
```bash
# Подставьте такой же UID и GID, как в переменной GUACAMOLE_UID
sudo chown 1000:1000 -R ./guacamole_data/
```

## Установка Nginx
> [!WARNING]
> Apache Guacamole очень чувствителен к конфигурации Nginx. В данном репозитории представлена базовая конфигурация; подробнее вы можете узнать в [официальной документации](https://guacamole.apache.org/doc/gug/reverse-proxy.html).

1. Установите Nginx.
```bash
sudo apt install nginx -y
```
2. Подготовьте SSL-сертификат.
- Поместите сертификат по следующему пути:
`/etc/ssl/certs/guacamole.crt`
- Поместите ключ по следующему пути:
`/etc/ssl/private/guacamole.key`

> [!NOTE]
> Вы также можете сгенерировать временный сертификат.

```bash
sudo mkdir -p /etc/ssl/certs /etc/ssl/private

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/guacamole.key \
  -out /etc/ssl/certs/guacamole.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=localhost"
```

3. Создайте символическую ссылку на конфигурацию Guacamole для `/etc/nginx/sites-enabled/`.
```bash
sudo ln -s $(realpath ./nginx/guacamole.conf) /etc/nginx/sites-enabled/

# По желанию удалите default-сайт
sudo rm -rf /etc/nginx/sites-enabled/defaul
```
4. Проверьте и примените конфигурацию.
```bash
sudo nginx -t
sudo systemctl reload nginx
```
5. Проверьте работу Nginx при помощи curl или перейдите на веб-страницу вашего сервера.
```bash
curl -k -I https://localhost/gucamole/
```

## Конфигурация LDAPS
> Apache Guacamole имеет возможность авторизации с использованием доменных учётных записей при помощи LDAP. В данном репозитории мы рассмотрим именно конфигурацию защищённой версии LDAP — LDAPS.

Так как мы будем использовать LDAPS, нам необходимо поместить сертификат корневого УЦ (CA) в список корневых сертификатов контейнера `guacamole-web`.
> [!NOTE]
> Так как веб-интерфейс Apache Guacamole написан на Java, нам придётся поместить сертификат в оригинальный Docker-образ на этапе сборки. Для этого в проекте есть Dockerfile.

1. Поместите корневой сертификат в корень проекта под именем `custom-ca-certificate.crt`.
2. Измените `docker-compose.yml`.
```yml
...
# Закомментируйте, если планируете использовать корневой сертификат LDAPS
#image: guacamole/guacamole:${DOCKER_GUACAMOLE_IMAGE_TAG:-1.6.0}
# Раскомментируйте, если планируете использовать корневой сертификат LDAPS
build:
  context: .
  dockerfile: Dockerfile
  args:
    - DOCKER_GUACAMOLE_IMAGE_TAG=${DOCKER_GUACAMOLE_IMAGE_TAG:-1.6.0}
...
```
3. Измените конфигурацию .env для LDAP.
4. Перезапустите Docker-контейнер и попробуйте авторизоваться в веб-интерфейсе Apache Guacamole с использованием доменной учётной записи, соответствующей фильтрам LDAP, заданным в конфигурации.
```bash
sudo docker compose up -d --force-recreate guacamole-web
```

## Конфигурация переменых окружения (.env)
| Переменная                  | Необходимость | Значение по умолчанию | Описание |
| --------------------------- | ------------- | ----------- | ----------- |
| DOCKER_POSTGRES_IMAGE_TAG | required | 17-alpine | Тег Docker-образа postgres |
| DOCKER_GUACAMOLE_IMAGE_TAG | required | 1.6.0 | Тег Docker-образа guacamole |
| POSTGRES_DB | required | guacamole | Имя базы данных |
| POSTGRES_USER | required | guacamole | Имя пользователя базы данных |
| POSTGRES_PASSWORD | required | postgres | Пароль базы данных. ОБЯЗАТЕЛЬНО изминте до первого запуска! |
| DNS_SEARCH_DOMAIN | | | Суффикс DNS-домена |
| DNS_SERVER_PRIMARY | | | Первичный адрес DNS-сервера |
| DNS_SERVER_SECONDARY | | | Вторичный адрес DNS-сервера |
| POSTGRES_PORT | required | 5432 | Внешний порт базы данных |
| POSTGRES_HOST_BIND | required | 127.0.0.1 | Привязка внешнего IP базы данных. Внимание! Не изменяйте его без необходимости |
| GUACAMOLE_WEB_PORT  | required | 8080 | Внешний порт веб-интерфейса Guacamole |
| GUACAMOLE_WEB_HOST_BIND | required | 127.0.0.1 | Привязка внешнего IP веб-интерфейса. Вы можете изменить его на 0.0.0.0, если не используете проксирование через Nginx |
| GUACAMOLE_UID | required | 1000 | Внешний UID пользователя для контейнеров Guacamole. Помните, что директория `./guacamole_data` должна принадлежать этому UID |
| TOTP_ENABLE | required | false | Переключает использование двухфакторной аутентификации на основе TOTP |
| TOTP_ISSUER | required | Apache Guacamole | Отображаемое имя кода авторизации в приложениях для TOTP |
| LDAP_HOSTNAME | | | Имя хоста или IP-адрес LDAP-сервера |
| LDAP_PORT | | | Порт LDAP-сервера (например, 636 для LDAPS) |
| LDAP_ENCRYPTION_METHOD | | | Метод шифрования соединения с LDAP-сервером (например, `ssl` или `starttls`) |
| LDAP_SEARCH_BIND_DN | | | DN учётной записи, используемой для поиска в каталоге LDAP |
| LDAP_SEARCH_BIND_PASSWORD | | | Пароль учётной записи, используемой для поиска в каталоге LDAP |
| LDAP_USER_BASE_DN | | | Базовый DN, в котором выполняется поиск пользовательских учётных записей |
| LDAP_USERNAME_ATTRIBUTE | | | Атрибут LDAP, содержащий имя пользователя (например, `sAMAccountName` или `uid`) |
| LDAP_USER_SEARCH_FILTER | | | Фильтр LDAP для поиска пользователей (например, `(objectClass=person)`) |
| LDAP_GROUP_MEMBER_ATTRIBUTE | | | Атрибут LDAP, содержащий список участников группы (например, `member`) |
| LDAP_GROUP_SEARCH_FILTER | | | Фильтр LDAP для поиска групп (например, `(objectClass=group)`) |
| LDAP_FOLLOW_REFERRALS | | | Определяет, следует ли автоматически следовать ссылкам LDAP (referrals) |
| LDAP_DEREFERENCE_ALIASES | | | Определяет, как обрабатываются алиасы LDAP при поиске |
| LDAP_MAX_SEARCH_RESULTS | | | Максимальное количество результатов, возвращаемых при поиске в LDAP |
