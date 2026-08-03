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
| Название экземпляра  | Open Ports |  Flavor   |  AZ  | Disk   |    Subnet    |        OS        | Назначение
| -------------------- | ---------- | --------  | ---- | ------ | ------------ |----------------- | --------------
| adb-cluster-manager  | 22,8000    | STD3-2-8  |  MS1 | 20 GB  |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | ADB Cluster Manager
| dwh-adb-ent-tools    | 22,81      | STD3-1-2  |  MS1 | 100 GB |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | local reposutory & docker registry
| dwh-adb-ent-services | 22,8890    | STD3-8-16 |  MS1 | 100 GB |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | ADB Control, ADB Backup Manager
| dwh-adb-master       | 22,5432    | STD3-1-2  |  MS1 | 20 GB  |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | Master of Cluster
| dwh-adb-standby      | 22         | STD3-1-2  |  ME1 | 20 GB  |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | Standby of Cluster
| dwh-adb-segment1     | 22         | STD3-8-16 |  MS1 | 100 GB |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | First segment of Cluster
| dwh-adb-segment2     | 22         | STD3-8-16 |  ME1 | 100 GB |  10.0.0.0/24 | РЕД ОС 8.0 ФСТЭК | Second segment of Cluster

При создании ВМ был указан id_rsa ключ для дальнейшего подключения по `ssh`. Подключение по ssh будет производииться от основного юзера операционной системы, в данном случае `redos`.

### Шаг 1. Установка ADCM (Arenadata Cluster Manager)
Для выполнения этого шага на ВМ `adb-cluster-manager` потребуется установить его зависимости:
```bash
# Обновитьпакетный менеджер и установить следующие пакеты
sudo dnf update -y
sudo dnf install -y \
    git \
    wget \
    docker \
    podman-compose
```

```bash
# Создать файл nodocker
sudo mkdir -p /etc/containers
sudo touch /etc/containers/nodocker
```

Также чтобы избежать автоматического завершения процессов `postgres` при разлогинивании пользователя (если вы запускаете контейнеры в rootless режиме) то необходимо вклчить `linger` для юзера `redos`

```bash
sudo loginctl enable-linger $USER
```

Установка ADCM выполняется по [документации](https://docs.arenadata.io/ru/ADB/current/introduction/intro.html). Наиболее удобный способ - установка в контейнерах докер. Этот репозиторий содержит `docker-compose.yml` с уже настроенным `adcm` и `postgres` для хранения данных. Для развертывания `adcm` просто склонируйте репозиторий и выполните команду `docker compose up -d`.

### Шаг 2. Вход и настройка adcm
* Для запуска после установки воспользуйтесь [инструкцией](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D1%88%D0%B0%D0%B3-3-%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-adcm).
* Для входа используйте логин: `admin` и пароль: `admin`. Далее смените пароль как описано в [тут](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-web-%D0%B8%D0%BD%D1%82%D0%B5%D1%80%D1%84%D0%B5%D0%B9%D1%81%D0%B0-adcm)
* Вручную установите URL ADCM как описато в [инструкции](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#adcm-url)

### Шаг 3. Загрузить bundles
*Важно! Перед выполнением этого шага вам надо запросить у команды `Arenadata` бандлы и паки для установки всех необходимых программных продуктов. Для этого отправьте им заявку с указанием точной версии операционной системы на которую вы будете устанавливать  `ADB` и все вспомогательный программы, а также саму версию `ADB` (рекомендуется к установке наиболее свежая на данный момент). В данной примере установка ведется на `РЕД ОС 8.0 ФСТЭК` версии `ADB 6.30.0.1`*


* Для установки продуктов Arenadata нам постребуется 4 бандла:

| Название бандла                    | Название файла (может отличаться) | Назначение |
| ---------------------------------- | --------------------------------- | ---------- |
| SSH Hostprovider                   | adcm_host_ssh_v3.1.0-1_community.tgz | Для подключения хостов (физических или виртуальных) в кластерам (и сервисам) по ssh
| ADB Enterprise Tools               | adcm_cluster_et_v2026062900-1_community.tgz | Для `offline` установки потребуется локальный репозиторий для пакетного менеджера и docker registry для хранения образов. В этом бандле все что нужно для разворачивания кластера с этими сервисами. |
| ADB Enterprise Services            | adcm_cluster_adbes_v1.1.1_b1-1_enterprise.tgz | Для развертывания кластера со вспомогальными программами: ADB Control для управления кластером МРР СУБД, ADB Backup Manager и все необходимые для их работы службы |
| ADB                                | adcm_cluster_adb_v6.31.0_arenadata1_b2-1_enterprise.tgz | Непостредственно для разворачивания самой MPP СУБД Arenadata DB |

Перейдите в ADCM на вкладку `Bundles` и добавьте все 4. Файлы бандлов имеют расширение `.tgz`, так их легко отличить от файлов с установочными пакетами которые имеют расширение `.sh.xz`.

### Шаг 4. Подключить все хосты к ADB CM.
* Создать и настроить хостпровайдера по [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/get-started/install.html#%D1%88%D0%B0%D0%B3-3-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D1%85%D0%BE%D1%81%D1%82%D0%BF%D1%80%D0%BE%D0%B2%D0%B0%D0%B9%D0%B4%D0%B5%D1%80%D0%B0-%D0%BD%D0%B0-%D0%B1%D0%B0%D0%B7%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B6%D0%B5%D0%BD%D0%BD%D0%BE%D0%B3%D0%BE-%D0%B1%D0%B0%D0%BD%D0%B4%D0%BB%D0%B0). Про то что такое `hostprovider` и для чего он нужен можно прочитать [здесь](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/hostprovider/index.html)
* Создать и настроить хосты (по одному) согласно [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/how-to/create-hosts.html). Потребуется заполнить имя пользователя (в данном примере `redos`), ipv4 адрес и приватный ключ для SSH подключения. После настройки рекомендуется проверить подключение запустив джобу `Check connection` и установить `Statuschecker` запустив `Install statuschecker`

Для удобства предлагаю имена хостов в VK Cloud и имена хостов в ADB CM указывать одинаковые во избежании случайных ошибок: 

| Название экземпляра в VK Cloud  | Название хоста в ADB CM |     
| ------------------------------- | ----------------------- |
| dwh-adb-ent-tools               | dwh-adb-ent-tools       |
| dwh-adb-ent-services            | dwh-adb-ent-services    |
| dwh-adb-master                  | dwh-adb-master          |
| dwh-adb-standby                 | dwh-adb-standby         |
| dwh-adb-segment1                | dwh-adb-segment1        |
| dwh-adb-segment2                | dwh-adb-segment2        |

На всякий случай оговоримся, что хост `adb-cluster-manager` добавлять не нужно - он используется только для деплоя `ADB Cluster Manager`.

### Шаг 5. Установка ADB ET
Следующий по порядку этап - установка ADB Enterprise Tools. Этот кластер необходим если вы устанавливаете `ADB` методом `offline` и в **данном примере** используется только для локального хранения установочных пакетов и образов docker. Больше ни для чего не используется. Чтобы его создать выполните следующие шаги:

* Во вкладке `Clusters` создать новый кластер из бандла `ADB Enterprise Tools`, назовем его идентично - `ADB Enterprise Tools`
* Перейдите в созданный кластер, затем в раздел `Services` -> добавьте сервисы `Docker Registry` и `HTTP Mirror`
* Перейдите во владку `Hosts` -> добавьте хост `dwh-adb-ent-tools`
* Перейдите во вкладку `Mappings` -> привяжите к каждому сервису добавленный ранее хост `dwh-adb-ent-tools`
* Остальные настройки можно оставить по-умолчанию. Сохраните изменения -> выберите действие `Install`
* После завершения установки выберите действие `Start Service`

Дождитесь завершения установки кластера ADB Enterprise Tools.

### Шаг 6. Загрузка пакетов в ADB ET
Помимио бандлов в присланном вам дистрибутиве от команды `Arenadata` находятся файлы установочных пакетов для версии RedOS 8.0:

| Название файла                                                 | Назначение          |
| -------------------------------------------------------------- | ------------------- |
| `adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz`                         | Содержит установочные пакеты для ADB Control, Backup Manager, Мониторинга и других сервисов для MPP СУБД Arenadata
| `adb_6.31.0_arenadata1_ee_red_8.0_x86_64.sh.xz`                | Содержит установочные файлы самой МРР СУБД Arenadata
| `et_2026062900_ce_red_8_x86_64.sh.xz`                          | Содержит пакет для offline установки самого ADB ET. В данном примере не используется

Перед тем как загрузить их в репозиторий, необходимо разместить их на машине `dwh-adb-ent-tools` и поместить в каталог доступный юзеру `redos`. Для этого выполним следующие команды:

```bash
# Отправить каждый файл по сети на удаленный хост (имя файла и ip адрес будут отличаться)
scp adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz redos@10.0.0.145:~/adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz

# Распаковать архив на удаленной машине
ssh redos@10.0.0.145
cd ~
unxz adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz
```

Затем:
* в ADB Cluster Manager выберите перейдите в раздел `Clusters`
* Напротив `ADB Enterprise Services` выберите действие `Upload Pack`
* В конфигурции задания раскройте пункт `Offline Pack` и укажите путь к загруженному и распакованному файлу `/home/redos/adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz` -> нажмите `Apply`
* Кникните кнопку `Next` -> `Next` -> `Run`

Таким образом загрузите все необходимые файлы в репозиторий.
В разделе `Jobs` можно наблюдать за процессом задания.

### Шаг 7. Установка ADB ES
Кластер ADB ES (Enterprise Services) содержит вспомогательные сервисы для управления и администрирования МРР СУБД `Arenadata`:
* Сервис для мониторинга
* Отслеживания запросов в СУБД
* Аудита ролей и их прав доступов
* Управления конфигурационными параметрами
* Управления и настройки ресурсных групп
* Выполнения процедур резервного копирования

и много другое.

Для его установки выполните следущие действия:

* Создать клатер `ADB Enterprise Services` из одноименного бандла
* Добавить сервисы во вкладке `Services` которые вам потребуются в процессе работы. В данном примере были созданы:
    - ADB Control (вместе с зависимостями: Clickhouse & Database)
    - ADB Backup Manager
* Добавьте необходимые хосты: в нашем случае один хост - `dwh-adb-ent-services`
* Смаппить этот хост на все сервисы во вкладке `Mappings`
* Импортировать настройки `HTTP Mirror` & `Docker Registry`
* Также система постребует указать необходимые параметры (пароли) для создаваемых служебных юзеров в сервисах
* После завершения выполните сначала `Precheck`, а затем `Install`

### Шаг 8. Настроить хосты для работы ADB

На следующих хостах:

| Название экземпляра в VK Cloud  |
| ------------------------------- |
| dwh-adb-master                  |
| dwh-adb-standby                 |
| dwh-adb-segment1                |
| dwh-adb-segment2                |

Установите `Java 17` воспользовавшись [инструкцией](https://support.minehosting.ru/servers/java/java17)
Из под рутового пользователя выполнить команды:

```bash
sudo -i
wget https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.6%2B10/OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    tar xf OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    rm OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz -f && \
    rm /opt/jdk-17.0.6+10 -rf && \
    mv jdk-17.0.6+10 /opt

# Затем установите скачанную версию java как основную
ln -svf /opt/jdk-17.0.6+10/bin/java /usr/bin/java
```

Затем в параметрах загрузчика `Grub` установить `cgroup v1`

```bash
sudo -i
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0 systemd.legacy_systemd_cgroup_controller=1"
reboot

# Check cgroup version
stat -fc %T /sys/fs/cgroup/
```

Также чтобы избежать автоматического завершения процессов `postgres` при разлогинивании пользователя (если вы запускаете контейнеры в rootless режиме) то необходимо вклчить `linger` для юзера `redos`

```bash
sudo loginctl enable-linger $USER
```

### Шаг 9. Установка кластера ADB
* Создайте кластер `ADB` из одноименного бандла
* Добавьте сервисы:
    - ADB
    - ADBM Agent
    - ADBC Agent
* Смаппите сервисы на соответствующие хосты в разделе `Mapping`
* Сначала выполните `Precheck`
* Затем запустите `Install`

### Шаг 7. Подключение к ADB Control 
Выполняется с помощью [документации](https://docs.arenadata.io/ru/ADBES/current/connect.html)

* В браузере откройте страницу http://10.0.0.73:8890
* Введите логин и пароль по умолчанию, логин: `admin`, пароль: `1234`
* Установите новый надежный пароль при первом входе (система запросит автоматически)