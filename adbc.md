# Установка и настройка ADB Control
Для online установки ADB Control прежде всего необходимо загрузить в ADCM его bundle. Начиная с версии ADB 6.30.0.1 ADBControl устанавливается в отдельном кластере с помощью отдельного bundle ADB ES (ADB Enterprise Services). 
Компанией Arenadata был предоставлен следующий bundle для ее установки: adb_es_1.1.1_ee_astralinux_1.8_x86_64.sh.xz под дистрибутив Astra Linux 1.8. У меня успешно установился на Ubuntu 22.04.

### Шаг 1. Загрузка бандла ADB ES
Загрузите бандл из файла adb_es_1.1.1_ee_astralinux_1.8_x86_64.sh.xz

### Шаг 2. Сздайте ВМ в VK Cloud
Была создана ВМ со следующими характеристиками:
| Название экземпляра | IPv4       | Flavor   | Disk Space | OS           |
| ------------------- | ---------- | -------- | ---------- |------------- |
| dwh-adb-control     | 10.0.0.241 | STD3-2-8 | 80 GB      | Ubuntu 22.04 |

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

# Подключение к ADB Control 
Выполняется с помощью [документации](https://docs.arenadata.io/ru/ADBES/current/connect.html)
