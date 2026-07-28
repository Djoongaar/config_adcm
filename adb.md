# Установка и настройка кластера Arenadata DB
### Шаг 1. Установка ADCM (Arenadata cluster manager)
Установка ADCM выполняется по [документации](https://docs.arenadata.io/ru/ADB/current/introduction/intro.html). Наиболее удобный способ - установка в контейнерах докер. Этот репозиторий содержит `docker-compose.yml` с уже настроенным `adcm` и `postgres` для хранения данных. Для развертывания `adcm` просто склонируйте репозиторий и выполните команду `docker compose up -d`

### Шаг 2. Вход и настройка adcm
* Для запуска после установки воспользуйтесь [инструкцией](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D1%88%D0%B0%D0%B3-3-%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-adcm). В отличие от инструкции вместо 8000 используется порт: 80. 
* Для входа используйте логин: `admin` и пароль: `admin`. Далее смените пароль как описано в [тут](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-web-%D0%B8%D0%BD%D1%82%D0%B5%D1%80%D1%84%D0%B5%D0%B9%D1%81%D0%B0-adcm)
* Вручную установите URL ADCM как описато в [инструкции](https://docs.arenadata.io/ru/ADB/current/get-started/online-install/adcm-install.html#adcm-url)

### Шаг 3. Загрузить bundles
* Для установки продуктов Arenadata нам постребуется два бандла: SSH Hostprovider и ADB Cluster.
* Arenadata DB bundles можно скачать на [тут](https://network.arenadata.io/arenadata-db)
* SSH bundles можно скачать на [тут](https://network.arenadata.io/arenadata-cluster-manager/bundles)
* Бандл для установки Arenadata Cluster по этой [ссылке](https://network.arenadata.io/arenadata-db/downloads#7.4.1_arenadata1_b1)

### Шаг 4. Создать виртуальные машины в ВК Клауд
В конкретно моем примере я создал 5 виртуальных машин:
| Название экземпляра | IPv4   | Flavor   | OS       |
| ----------- | ------ | -------- | -------- |
| dwh-adb-control | 10.0.0.241 | STD3-2-8 | Ubuntu 22.04 |
| dwh-adb-master  | 10.0.0.251 | STD3-1-2 | Ubuntu 22.04 |
| dwh-adb-standby | 10.0.0.250 | STD3-1-2 | Ubuntu 22.04 |
| dwh-adb-segment1| 10.0.0.73  | STD3-2-8 | Ubuntu 22.04 |
| dwh-adb-segment2| 10.0.0.249 | STD3-2-8 | Ubuntu 22.04 |
Все они располагаются в одной подсети `arenadata_network` с выключенной функцией Private DNS.

### Шаг 5. Создать хосты для будущего развертывания `ADB`
* Создать и настроить хостпровайдера по [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/get-started/install.html#%D1%88%D0%B0%D0%B3-3-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D1%85%D0%BE%D1%81%D1%82%D0%BF%D1%80%D0%BE%D0%B2%D0%B0%D0%B9%D0%B4%D0%B5%D1%80%D0%B0-%D0%BD%D0%B0-%D0%B1%D0%B0%D0%B7%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B6%D0%B5%D0%BD%D0%BD%D0%BE%D0%B3%D0%BE-%D0%B1%D0%B0%D0%BD%D0%B4%D0%BB%D0%B0). Про то что такое `hostprovider` и для чего он нужен можно прочитать [здесь](https://docs.arenadata.io/ru/ADB/6.27.1.61/get-started/online-install/hostprovider/index.html)
* Создать и настроить хосты (по одному) согласно [инструкции](https://docs.arenadata.io/ru/hp-ssh/current/how-to/create-hosts.html). потребуется заполнить имя пользователя, ipv4 адрес и приватный ключ для SSH подключения. После настройки рекомендуется проверить подключение запустив джобу `Check connection` и/или `Install statuschecker`

### Шаг 6. Создать и настроить кластер `ADB`
* Создайте кластер воспользовавшесь этой [инструкцией](https://docs.arenadata.io/ru/ADB/6.27.1.61/get-started/online-install/adb-install/cluster-creation.html)
* Во вкладке `Services` добавьте в кластер два сервиса: `ADB` и `ADB Control`
* Во вкладке `Hosts` добавьте созданные на предыдущем шаге хосты
* Во вкладке `Mappings` сопоставьте хосты по их ролям в кластере

### Шаг 7. Установить java 17 на всех хостах кластера
На каждом из 5 хостов установите java 17 воспользовавшись [инструкцией](https://support.minehosting.ru/servers/java/java17)
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

Теперь напишите `java -version`, чтобы проверить установку.

### Шаг 8. Установить cgroup v1
```bash
sudo -i
nano /etc/default/grub.d/99-cgroup.cfg

# Edit file
# GRUB_CMDLINE_LINUX_DEFAULT="systemd.unified_cgroup_hierarchy=0 systemd.legacy_systemd_cgroup_controller=1"

# Update cgroup
update-grub
reboot

# Check cgroup version
stat -fc %T /sys/fs/cgroup/
```

### Шаг 9. Конфигурация кластера
* Выберите кластер кликнув на его название и перейдите во вкладку `Configuration`
* Переключите тумблер `Advanced` в режим включено
* Включите настройку `Use custom JAVA_HOME for cluster` и укажите параметр JAVA_HOME: `/opt/jdk-17.0.6+10`
* Сохраните изменения

### Шаг 10. Установка кластера
* Сначала выполните `Precheck` - этот шаг выполняется успешно
* Затем запустите `Install` - установка падает с ошибкой

