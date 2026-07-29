# Установка и настройка ADB CM, ADB ET, ADBM, ADBC & ADB (offline)
* `ADB CM` - ADB Cluster manager
* `ADB ET` - ADB Enterprise Tools
* `ADBM` - ADB Backup Manager 
* `ADBC` - ADB Control
* `ADB` - Arena DB

### Шаг 0. Создать ВМ для ADB в VK Cloud
*Важно! Версия Astra Linux 1.8.5 которая присутствует в нашем IaaS не поддерживается.
Установка на ней будет прерываться на этапе `Precheck` с ошибкой `Unsupported platform`.
Коварство в том что падает с ошибкой не все программные продукты. В моей случае `ADB`
был нормально установлен, но завнершилась с ошибкой установка `ADB Enterprise Services`,
и целиком вся инфраструктура не заработала. Были запрошены паки и бандлы под `РЕД ОС 8.0`*

Была созданы ВМ со следующими характеристиками:
| Название экземпляра  | IPv4       | Flavor    | Disk   |        OS        | Назначение
| -------------------- | ---------- | --------  | ------ |----------------- | --------------
| dwh-adb-ent-tools    | 10.0.0.130 | STD3-1-2  | 100 GB | РЕД ОС 8.0 ФСТЭК | local reposutory & docker registry
| dwh-adb-ent-services | 10.0.0.29 | STD3-8-16 | 100 GB | РЕД ОС 8.0 ФСТЭК | ADB Control, ADB Backup Manager
| dwh-adb-master       | 10.0.0.251 | STD3-1-2  | 20 GB  | РЕД ОС 8.0 ФСТЭК | Master of Cluster
| dwh-adb-standby      | 10.0.0.250 | STD3-1-2  | 20 GB  | РЕД ОС 8.0 ФСТЭК | Standby of Cluster
| dwh-adb-segment1     | 10.0.0.73  | STD3-8-16 | 100 GB | РЕД ОС 8.0 ФСТЭК | First segment of Cluster
| dwh-adb-segment2     | 10.0.0.249 | STD3-8-16 | 100 GB | РЕД ОС 8.0 ФСТЭК | Second segment of Cluster

При создании ВМ был указан id_rsa ключ для дальнейшего подключения по `ssh`. Подключение по ssh будет производииться от основного юзера операционной системы, в данном случае `redos`.

### Шаг 1. Установка ADCM (Arenadata Cluster Manager)
Установка ADCM выполняется по [документации](https://docs.arenadata.io/ru/ADB/current/introduction/intro.html). Наиболее удобный способ - установка в контейнерах докер. Этот репозиторий содержит `docker-compose.yml` с уже настроенным `adcm` и `postgres` для хранения данных. Для развертывания `adcm` просто склонируйте репозиторий и выполните команду `docker compose up -d`

### Шаг 2. Вход и настройка adcm
* Для запуска после установки воспользуйтесь [инструкцией](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D1%88%D0%B0%D0%B3-3-%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-adcm). В отличие от инструкции вместо 8000 используется порт: 80. 
* Для входа используйте логин: `admin` и пароль: `admin`. Далее смените пароль как описано в [тут](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-web-%D0%B8%D0%BD%D1%82%D0%B5%D1%80%D1%84%D0%B5%D0%B9%D1%81%D0%B0-adcm)
* Вручную установите URL ADCM как описато в [инструкции](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#adcm-url)

### Шаг 3. Загрузить bundles
*Важно! Перед выполнением этого шага вам надо запросить у команды `Arenadata` бандлы и паки для установки всех необходимых программных продуктов. Для этого отправьте им заявку с указанием точной версии операционной системы на которую вы будете устанавливать  `ADB` и все вспомогательный программы, а также саму версию `ADB` (рекомендуется к установке наиболее свежая на данный момент). В данной примере установка ведется на `РЕД ОС 8.0 ФСТЭК` версии `ADB 6.30.0.1`*

* Для установки продуктов Arenadata нам постребуется 4 бандла: 

| Название бандла                    | Назначение |     
| ---------------------------------- | ---------- |
| SSH Hostprovider                   | Для подключения хостов (физических или виртуальных) в кластерам (и сервисам) по ssh
| ADB Enterprise Tools               | Для `offline` установки потребуется локальный репозиторий для пакетного менеджера и docker registry для хранения образов. В этом бандле все что нужно для разворачивания кластера с этими сервисами. |
| ADB Enterprise Services            | Для развертывания кластера со вспомогальными программами: ADB Control для управления кластером МРР СУБД, ADB Backup Manager и все необходимые для их работы службы |
| ADB                                | Непостредственно для разворачивания самой MPP СУБД Arenadata DB |

Перейдите в ADCM на вкладку `Bundles` и добавьте все 4.

### Шаг 4. Подключить все хосты к ADB CM.
Для этого в ADB Cluster Manager перейдите во вкладку вкладку `Hosts` и добавьте созданные на предыдущем Шаге 0 хосты ВМ. Для этого постребуется указаться имя юзера для подключения по ssh (в данном примере `redos`), ввести его секретный ключ ssh и указать IPv4 адрес в локальной сети, в данном примере 10.0.0.130.

Для удобства предлагаю имена хостов в VK Cloud и имена хостов в ADB CM указывать одинаковые во избежании случайных ошибок: 

| Название экземпляра в VK Cloud  | Название хоста в ADB CM |     
| ------------------------------- | ----------------------- |
| dwh-adb-ent-tools               | dwh-adb-ent-tools       |
| dwh-adb-ent-services            | dwh-adb-ent-services    |
| dwh-adb-master                  | dwh-adb-master          |
| dwh-adb-standby                 | dwh-adb-standby         |
| dwh-adb-segment1                | dwh-adb-segment1        |
| dwh-adb-segment2                | dwh-adb-segment2        |

### Шаг 5. Установка ADB ET
* Во вкладке `Clusters` создать новый кластер из бандла `ADB Enterprise Tools`, назовем его идентично - `ADB Enterprise Tools`
* Перейдите в созданный кластер, затем в раздел `Services` -> добавьте сервисы `Docker Registry` и `HTTP Mirror`
* Перейдите во владку `Hosts` -> добавьте хост `dwh-adb-ent-tools`
* Перейдите во вкладку `Mappings` -> привяжите к каждому сервису добавленный ранее хост `dwh-adb-ent-tools`
* Остальные настройки можно оставить по-умолчанию. Сохраните изменения -> выберите действие `Install`
* После завершения установки выберите действие `Start Service`















### Шаг 2. Установить java 17 на хосте
На хосте `dwh-adb-control` установите java 17 воспользовавшись [инструкцией](https://support.minehosting.ru/servers/java/java17)
Из под рутового пользователя выполнить команды
```bash
sudo -i
wget https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.6%2B10/OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    tar xf OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    rm OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz -f && \
    rm /opt/jdk-17.0.6+10 -rf && \
    mv jdk-17.0.6+10 /opt

ln -svf /opt/jdk-17.0.6+10/bin/java /usr/bin/java
```

### Шаг 3. Создать кластер ADB Enterprise Tools
* Из бандла ADB Enterprise Tools создать кластер
* Добавить сервисы `Docker Registry` и `HTTP Mirror`
* Добавить хост `dwh-adb-et` к кластеру
* Настроить `Mapping` хоста `dwh-adb-et` к сервисам `Docker Registry` и `HTTP Mirror`

### Шаг 4. Установка кластера ADB Enterprise Tools
* Напротив названия кластера нажмите `Install`
* Выберите опцию `offline`
* Укажите путь к исполняемому файлу `/home/astra/et_2026062900_ce_astralinux_1.8_x86_64.sh`
* Запустите установку

Дождитесь завершения установки кластера ADB Enterprise Tools.

url: http://10.0.0.161:81/arenadata-repo/ADQM/26.3.3.20_arenadata1/ubuntu/22.04/community/
result: {'redirected': False, 'url': 'http://10.0.0.161:81/arenadata-repo/ADQM/26.3.3.20_arenadata1/ubuntu/22.04/community/x86_64/dists/arenadata/Release', 'status': 404, 'server': 'nginx/1.30.1', 'date': 'Wed, 29 Jul 2026 10:24:30 GMT', 'content_type': 'text/html', 'content_length': '153', 'connection': 'close', 'elapsed': 0, 'changed': False, 'failed': True, 'msg': 'Status code was 404 and not [200]: HTTP Error 404: Not Found', 'attempts': 3}

## Установка ADB Control

Для online установки ADB Control прежде всего необходимо загрузить в ADCM его bundle. Начиная с версии ADB 6.30.0.1 ADBControl устанавливается в отдельном кластере с помощью отдельного bundle ADB ES (ADB Enterprise Services). 
Компанией Arenadata был предоставлен следующий bundle для ее установки: adb_es_1.1.1_ee_astralinux_1.8_x86_64.sh.xz под дистрибутив Astra Linux 1.8. У меня успешно установился на Ubuntu 22.04.

### Шаг 1. Загрузка бандла ADB ES
Загрузите бандл из файла adb_es_1.1.1_ee_astralinux_1.8_x86_64.sh.xz

### Шаг 2. Сздайте ВМ в VK Cloud
Была создана ВМ со следующими характеристиками:
| Название экземпляра | IPv4       | Flavor   | Disk Space | OS           |
| ------------------- | ---------- | -------- | ---------- |------------- |
| dwh-adb-control     | 10.0.0.73  | STD3-2-8 | 80 GB      | Ubuntu 22.04 |

### Шаг 3. Создать хосты для будущего развертывания `ADB ES`
* Создать и настроить хостпровайдера по [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/get-started/install.html#%D1%88%D0%B0%D0%B3-3-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D1%85%D0%BE%D1%81%D1%82%D0%BF%D1%80%D0%BE%D0%B2%D0%B0%D0%B9%D0%B4%D0%B5%D1%80%D0%B0-%D0%BD%D0%B0-%D0%B1%D0%B0%D0%B7%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B6%D0%B5%D0%BD%D0%BD%D0%BE%D0%B3%D0%BE-%D0%B1%D0%B0%D0%BD%D0%B4%D0%BB%D0%B0). Про то что такое `hostprovider` и для чего он нужен можно прочитать [здесь](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/hostprovider/index.html)
* Создать и настроить хост согласно [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/how-to/create-hosts.html). потребуется заполнить имя пользователя, ipv4 адрес и приватный ключ для SSH подключения. После настройки рекомендуется проверить подключение запустив джобу `Check connection` и/или `Install statuschecker`

### Шаг 4. Установить java 17 на хосте
На хосте `dwh-adb-control` установите java 17 воспользовавшись [инструкцией](https://support.minehosting.ru/servers/java/java17)
Из под рутового пользователя выполнить команды
```bash
sudo -i
wget https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.6%2B10/OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    tar xf OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    rm OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz -f && \
    rm /opt/jdk-17.0.6+10 -rf && \
    mv jdk-17.0.6+10 /opt
```

Если нет `wget` то установите его выполнив команды:
```bash
apt update
apt install wget -y
```

Затем установите скачанную версию java как основную
```bash
ln -svf /opt/jdk-17.0.6+10/bin/java /usr/bin/java
```

### Шаг 5. Создать и настроить кластер `ADB ES`
* Создайте кластер `ADB ES` воспользовавшесь этой [инструкцией](https://docs.arenadata.io/ru/ADBES/current/offline-cluster-creation.html)
* Во вкладке `Services` добавьте в кластер сервис `ADB Control`
* Во вкладке `Hosts` добавьте созданный на предыдущем шаге хост
* Во вкладке `Mappings` сопоставьте хост по ролям в кластере

### Шаг 6. Установка кластера
* Сначала выполните `Precheck`
* Затем запустите `Install`

### Шаг 7. Подключение к ADB Control 
Выполняется с помощью [документации](https://docs.arenadata.io/ru/ADBES/current/connect.html)

* В браузере откройте страницу http://10.0.0.73:8890
* Введите логин и пароль по умолчанию, логин: `admin`, пароль: `1234`
* Установите новый надежный пароль при первом входе (система запросит автоматически)

