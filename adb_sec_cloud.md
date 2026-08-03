#  Установка и настройка кластера Arenadata в secure_cloud

### Шаг 1. Создать ВМ в облаке  Secure Cloud
* Создать все машины в одной подсети например 10.0.0.0/24
* При создании экземпляров, настроить доступ по `ssh`

В данном примере были созданы ВМ со следующими характеристиками:
| Название экземпляра  | Open Ports |          Flavor          |  AZ  | Disk   |    Subnet    |      OS     | Назначение
| -------------------- | ---------- | -----------------------  | ---- | ------ | ------------ |------------ | --------------
| adb-cluster-manager  | 22,8000    | HYSTAX_(ratio_1-10)-4-8  |  AZ1 | 20 GB  |  10.0.0.0/24 | Red Os 8.0c | ADB Cluster Manager
| adb-enterprise-tools | 22,81      | HYSTAX_(ratio_1-10)-4-8  |  AZ1 | 100 GB |  10.0.0.0/24 | Red Os 8.0c | local reposutory & docker registry
| adb-enterprise-services | 22,8890  | HYSTAX_(ratio_1-10)-4-8 |  AZ1 | 100 GB |  10.0.0.0/24 | Red Os 8.0c | ADB Control, ADB Backup Manager
| dwh-adb-master       | 22,5432    | HYSTAX_(ratio_1-10)-2-4  |  AZ1 | 20 GB  |  10.0.0.0/24 | Red Os 8.0c | Master of Cluster
| dwh-adb-standby      | 22         | HYSTAX_(ratio_1-10)-2-4  |  AZ1 | 20 GB  |  10.0.0.0/24 | Red Os 8.0c | Standby of Cluster
| dwh-adb-segment1     | 22         | HYSTAX_(ratio_1-10)-8-16 |  AZ1 | 100 GB |  10.0.0.0/24 | Red Os 8.0c | First segment of Cluster
| dwh-adb-segment2     | 22         | HYSTAX_(ratio_1-10)-8-16 |  AZ1 | 100 GB |  10.0.0.0/24 | Red Os 8.0c | Second segment of Cluster

### Шаг 2. Настроить vpn туннель в подсеть
* Туннелировать все соединения с подсетью 10.0.0.0/24

### Шаг 3. Установить на хостах Java Version 17
```bash
# На localhost звагрузите Java 17
wget https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.6%2B10/OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz

# Отправьте на удаленный хост по ssh
scp OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz redos@10.0.0.27:~/

# Подключитесь к удаленному хосту
ssh redos@10.0.0.27
cd ~

# Разархивировать файл и установить как Java по-умолчанию
sudo su
tar xf OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz && \
    rm OpenJDK17U-jdk_x64_linux_hotspot_17.0.6_10.tar.gz -f && \
    rm /opt/jdk-17.0.6+10 -rf && \
    mv jdk-17.0.6+10 /opt && \
    ln -svf /opt/jdk-17.0.6+10/bin/java /usr/bin/java

# Проверить версию Java по-умолчанию
java -version
```

### Шаг 4. Настроить и запустить прокси-сервер на локальной машине
```bash
mkdir proxy_server
cd proxy_server
python3 -m env venv
source env/bin/activate
python3 -m pip install proxy.py
python3 -m proxy --port 8080
```

### Шаг 5. Установить Arenadata Cluster Manager
Опция `offline` установки ADCM доступна только в `Enterprise` версии продукта. Для этого потребуется запросить у команды `Arenadata` пак для установки программ. В данном примере для устновки ADCM был получен файл `adcm_2.12.0.sh.xz`. Для получения подробной информации по установке перейдите на страницу [документации](https://docs.arenadata.io/en/ADCM/current/get-started/install.html#offline-installation-available-in-the-enterprise-edition)

Краткий гайд по установке:
```bash
# Отправить файл на хост для установки ADCM
scp adcm_2.12.0.sh.xz redos@10.0.0.15:~/adcm_2.12.0.sh.xz

# Подключиться к удаленному хосту adb-cluster-manager и прокинуть порт для прокси сервера 
ssh -R 8080:127.0.0.1:8080 redos@10.0.0.26
cd ~

# Разархивировать файл
unxz adcm_2.12.0.sh.xz

# Настроить proxy для пакетного менеджера dnf
sudo -i
echo "proxy=http://127.0.0.1:8080" >> /etc/dnf/dnf.conf  # execute by root
exit
sudo dnf check-update

# Установить docker на RED OS 8.0
sudo dnf update -y
sudo dnf install docker-ce docker-ce-cli -y
sudo systemctl enable docker --now
sudo usermod -aG docker $USER

# Установить PostgreSQL-16
sudo dnf install postgresql-server -y

# Инициализировать базу данных
sudo su postgres
initdb -D /var/lib/pgsql/data
exit # Переключиться на юзера redos

# Запустить сервер PostgreSQL
sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service

# Установить пароль для суперюзера postgres
sudo su postgres
psql -c 'ALTER ROLE postgres PASSWORD "<password>";'
\q # Выйти из консоли psql
exit # Переключиться на юзера redos

# Загрузить образ docker adcm
sudo bash adcm_2.12.0.sh unpack_adcm

# Запустить службу ADCM
sudo docker run -d \
    --name adcm \
    --network host \
    -p 8000:8000 \
    -v /opt/adcm:/adcm/data \
    -e DB_HOST="127.0.0.1" \
    -e DB_PORT="5432" \
    -e DB_USER="postgres" \
    -e DB_NAME="postgres" \
    -e DB_PASS="Ws3iysiw" \
    hub.arenadata.io/adcm/adcm:2.12.0
```

### Шаг 6. Вход и настройка adcm
* Для запуска после установки воспользуйтесь [инструкцией](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D1%88%D0%B0%D0%B3-3-%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-adcm).
* Для входа используйте логин: `admin` и пароль: `admin`. Далее смените пароль как описано в [тут](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-web-%D0%B8%D0%BD%D1%82%D0%B5%D1%80%D1%84%D0%B5%D0%B9%D1%81%D0%B0-adcm)
* Вручную установите URL ADCM как описато в [инструкции](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#adcm-url)

### Шаг 7. Загрузить bundles
*Важно! Перед выполнением этого шага вам надо запросить у команды `Arenadata` бандлы и паки для установки всех необходимых программных продуктов. Для этого отправьте им заявку с указанием точной версии операционной системы на которую вы будете устанавливать  `ADB` и все вспомогательный программы, а также саму версию `ADB` (рекомендуется к установке наиболее свежая на данный момент). В данной примере установка ведется на `Red Os 8.0c Сертифицированная` версии `ADB 6.30.0.1`*


* Для установки продуктов Arenadata нам постребуется 4 бандла:

| Название бандла                    | Название файла (может отличаться) | Назначение |
| ---------------------------------- | --------------------------------- | ---------- |
| SSH Hostprovider                   | adcm_host_ssh_v3.1.0-1_community.tgz | Для подключения хостов (физических или виртуальных) в кластерам (и сервисам) по ssh
| ADB Enterprise Tools               | adcm_cluster_et_v2026062900-1_community.tgz | Для `offline` установки потребуется локальный репозиторий для пакетного менеджера и docker registry для хранения образов. В этом бандле все что нужно для разворачивания кластера с этими сервисами. |
| ADB Enterprise Services            | adcm_cluster_adbes_v1.1.1_b1-1_enterprise.tgz | Для развертывания кластера со вспомогальными программами: ADB Control для управления кластером МРР СУБД, ADB Backup Manager и все необходимые для их работы службы |
| ADB                                | adcm_cluster_adb_v6.31.0_arenadata1_b2-1_enterprise.tgz | Непостредственно для разворачивания самой MPP СУБД Arenadata DB |

Перейдите в ADCM на вкладку `Bundles` и добавьте все 4. Файлы бандлов имеют расширение `.tgz`, так их легко отличить от файлов с установочными пакетами которые имеют расширение `.sh.xz`.

### Шаг 8. Подключить все хосты к ADB CM.
* Создать и настроить хостпровайдера по [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/get-started/install.html#%D1%88%D0%B0%D0%B3-3-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D1%85%D0%BE%D1%81%D1%82%D0%BF%D1%80%D0%BE%D0%B2%D0%B0%D0%B9%D0%B4%D0%B5%D1%80%D0%B0-%D0%BD%D0%B0-%D0%B1%D0%B0%D0%B7%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B6%D0%B5%D0%BD%D0%BD%D0%BE%D0%B3%D0%BE-%D0%B1%D0%B0%D0%BD%D0%B4%D0%BB%D0%B0). Про то что такое `hostprovider` и для чего он нужен можно прочитать [здесь](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/hostprovider/index.html)
* Создать и настроить хосты (по одному) согласно [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/how-to/create-hosts.html). Потребуется заполнить имя пользователя (в данном примере `redos`), ipv4 адрес и приватный ключ для SSH подключения. После настройки рекомендуется проверить подключение запустив джобу `Check connection` и установить `Statuschecker` запустив `Install statuschecker`.

Для удобства предлагаю имена хостов в VK Cloud и имена хостов в ADB CM указывать одинаковые во избежании случайных ошибок: 

| Название экземпляра в VK Cloud  | Название хоста в ADB CM |     
| ------------------------------- | ----------------------- |
| adb-enterprise-tools            | adb-enterprise-tools    |
| adb-enterprise-services         | adb-enterprise-services |
| dwh-adb-master                  | dwh-adb-master          |
| dwh-adb-standby                 | dwh-adb-standby         |
| dwh-adb-segment1                | dwh-adb-segment1        |
| dwh-adb-segment2                | dwh-adb-segment2        |

На всякий случай оговоримся, что хост `adb-cluster-manager` добавлять не нужно - он используется только для деплоя `ADB Cluster Manager`.

Установка `Statuschecker` также требует доступ в интернет пакетного менеджера `dnf`, поэтому для успешной инсталляции надо прописать на хосте `"proxy=http://127.0.0.1:8080"` в файле `/etc/dnf/dnf.conf`, а затем запустите установку `Statuschecker`.

### Шаг 9. Установить ADB Enterprise Tools offline
Для установки заранее прокинуть на сервер `adb-enterprise-tools` файл для установки
```bash
scp et_2026062900_ce_red_8_x86_64.sh.xz redos@10.0.0.15:~/

ssh redos@10.0.0.15
cd ~

# затем разархивировать его
unxz et_2026062900_ce_red_8_x86_64.sh.xz
```
и указать полный путь к нему в параметре при запуске установки. Шаги установки:

* Во вкладке `Clusters` создать новый кластер из бандла `ADB Enterprise Tools`, назовем его идентично - `ADB Enterprise Tools`
* Перейдите в созданный кластер, затем в раздел `Services` -> добавьте сервисы `Docker Registry` и `HTTP Mirror`
* Перейдите во владку `Hosts` -> добавьте хост `dwh-adb-ent-tools`
* Перейдите во вкладку `Mappings` -> привяжите к каждому сервису добавленный ранее хост `dwh-adb-ent-tools`
* Остальные настройки можно оставить по-умолчанию. Сохраните изменения -> выберите действие `Install`
* После завершения установки выберите действие `Start Service`

Дождитесь завершения установки кластера ADB Enterprise Tools.

### Шаг 10. Загрузка пакетов в ADB ET
Помимио бандлов в присланном вам дистрибутиве от команды `Arenadata` находятся файлы установочных пакетов для версии RedOS 8.0:

| Название файла                                                 | Назначение          |
| -------------------------------------------------------------- | ------------------- |
| `adb_es_1.1.1_ee_red_8.0_x86_64.sh.xz`                         | Содержит установочные пакеты для ADB Control, Backup Manager, Мониторинга и других сервисов для MPP СУБД Arenadata
| `adb_6.31.0_arenadata1_ee_red_8.0_x86_64.sh.xz`                | Содержит установочные файлы самой МРР СУБД Arenadata

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

### Шаг 11. Установить ADB Enterprise Services
Перед установкой `ADB Enterprise Services` на хост `adb-enterprise-services` требуется:
```bash
# Установить параметр proxy для пакетного менеджера dnf
echo "proxy=http://127.0.0.1:8080" >> /etc/dnf/dnf.conf # by root

# Затем установить ssh соединение с прокинутым портом
ssh -R 8080:127.0.0.1:8080 redos@10.0.0.13

# После этого запускать установку
```

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

### Шаг 11. Установка и настройка ADB 
Подготовка: смена cgroup
