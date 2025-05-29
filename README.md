<div align="left">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/m169-title.png" />
</div>

[![](https://img.shields.io/badge/Silas_Gubler-FF7F50?style=for-the-badge)](https://github.com/arkaizn)
[![](https://img.shields.io/badge/David_Kästli-00FA9A?style=for-the-badge)](https://github.com/dka-git)
[![](https://img.shields.io/badge/Jonas_Sieber-4682B4?style=for-the-badge)](https://github.com/josi-git)
[![](https://img.shields.io/badge/Lizenz-DAA520?style=for-the-badge)](https://github.com/JoSi-git/m346/blob/main/LICENSE)


## 🔍 1 Ausgangslage

Eine ältere Moodle-Instanz muss auf die aktuelle Version als Docker-Container migriert werden, inklusive aller Daten. Dies erfolgt im Rahmen des Modulprojekts und wird in mehreren Schritten durchgeführt.

## 📦 2 Anforderungen

### Git installieren

Sicherstellen, dass Git auf dem System installiert ist:

```bash
sudo apt update
sudo apt install git
```

### Git-Repository klonen

Klonen des Repositories:

```bash
git clone https://github.com/JoSi-git/m169
cd m169
```

### Skript ausführbar machen (falls nötig)

Falls das Skript nicht ausführbar ist, kann es wie folgt freigegeben werden:

```bash
chmod +x install.sh
```

### Skript ausführen

Anschliessend kann das Installationsskript gestartet werden:

```bash
./install.sh
```
<div align="center">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/demo-moodle-install.png" />
</div>

## 📁 3 Repository Struktur

```bash
├── docker
│   ├── config.php
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── php.ini
├── img
│   ├── demo-moodle-backup.png
│   ├── demo-moodle-cronjob.png
│   ├── demo-moodle-install.png
│   ├── demo-moodle-restore.png
│   ├── demo-moodle-status.png
│   └── m169-title.png
├── install.sh
├── LICENSE
├── moodle-backup
│   ├── moodle-backup-schedule.json
│   ├── moodle-backup.sh
│   ├── moodle-cronjob.sh
│   └── moodle-restore.sh
├── moodle-migration
│   ├── config.php
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── php.ini
├── moodle-status
│   └── moodle-status.sh
└── README.md
```

Im Verlauf der Ausführung des `install.sh`-Skripts werden sämtliche Ordner in ein projektspezifisches Verzeichnis kopiert (standardmässig nach `/opt/moodle/docker`). Anschliessend wird diese Struktur um zusätzliche Verzeichnisse und ergänzt, die nicht im Git-Repository enthalten sind. Nach erfolgreichem Abschluss des Skripts ergibt 
sich im Zielverzeichnis die vollständige Projektstruktur:

```bash
├── config.php
├── docker-compose.yml
├── Dockerfile
├── dumps
│   ├── 5.0_20250529-1634_FULL.tar.gz
│   └── migration
│       ├── 3.10.11-2025.05.29-15.52.sql
│       └── 3.10.11-2025.05.29-17.18.sql
├── logs
│   ├── apache
│   ├── install.log
│   ├── mariadb
│   ├── moodle
│   └── moodle-backup
│       └── 5.0_20250529-1634_FULL.tar.gz.log
├── moodle-backup-schedule.json
├── php.ini
└── tools
    ├── moodle-backup
    │   ├── moodle-backup-schedule.json
    │   ├── moodle-backup.sh
    │   ├── moodle-cronjob.sh
    │   └── moodle-restore.sh
    ├── moodle-migration
    │   ├── config.php
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   └── php.ini
    └── moodle-status
        └── moodle-status.sh
```
## ⚙️ 4 Konfiguration (.env)

Alle anpassbaren Variablen wie **Installationspfade**, **Datenbank-Zugangsdaten** und **PHP-Einstellungen** befinden sich zentral in der Datei `.env`.  
Diese Datei ermöglicht eine flexible Anpassung ohne direkte Änderungen am Skript.

### Beispielhafte `.env`-Werte:

```env
INSTALL_DIR=/opt/moodle-docker
LOG_DIR=/opt/moodle-docker/logs
BACKUP_DIR=/opt/moodle-docker/dumps
RESTORE_DIR=/opt/tools/moodle-restore

MYSQL_ROOT_PASSWORD='Riethuesli>12345'
MYSQL_ROOT_PASSWORD_OLD='Riethuesli>12345'
MYSQL_DATABASE=moodle
MYSQL_ROOT_USER=root
MYSQL_USER=vmadmin
MYSQL_PASSWORD="Riethuesli>12345"
CONTAINER_MOODLE="moodle-web"
CONTAINER_DB="moodle-db"

MOODLE_LOGSTORE=file
MOODLE_FILELOG_LOCATION=/var/moodledata/logs/moodle.log
```

> ⚠️ **Wichtig:**  
> Die Datei `.env` enthält sensible Informationen und sollte **niemals öffentlich geteilt** werden. Sie sollte weiterhin in `.gitignore` eingetragen sein.

## 🔐 5 Zugangsdaten der Moodle-Weboberfläche

Die Benutzer und Passwörter für die Moodle-Instanz selbst (nicht die Datenbank) befinden sich **nicht** in der `.env`, sondern müssen direkt in den jeweiligen `config.php`-Dateien der Moodle-Installation geändert werden.

```bash
# default path
/opt/moodle-docker/config.php
/opt/moodle-docker/tools/moodle-migration/config.php
```

## 🔧 6 Moodle-Status

Die gesamten Zusatztools, darunter eine Übersicht, Backup, Restore und der Crontab-Manager, können mit folgendem Befehl abgerufen werden. Innerhalb dieses Befehls steht ein Untermenü zur Verfügung, in dem zwischen weiteren Funktionen ausgewählt werden kann.
#### Alias für das interaktive Menü:

```bash
moodle-status
```

<div align="center">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/demo-moodle-status.png" />
</div>

## 🏗️ 7 Backup und Restore

> ⚠️ **Wichtig:**  
> Die Moodle Instanz muss während dem Backup und dem Restore Prozess gestartet sein.

### Backup durchführen

Es besteht ein integriertes Backup-Tool, das sowohl über ein TUI (Text User Interface) als auch per Parametersteuerung genutzt werden kann. Innerhalb des Tools gibt es die Möglichkeit, ein Backup der Datenbank, des Moodle-Datenverzeichnisses (moodledata) oder beides durchzuführen.

Alle relevanten Daten und die Hauptstruktur liegen in der Datenbank. Bilder, Logs und sonstige Zusatzdateien befinden sich im Moodle-Datenverzeichnis (`moodledata`). Dieses Verzeichnis ist deshalb deutlich grösser.

Die Backup-Funktion wurde so gestaltet, dass Backups mit einem kleinen Footprint im Halbtagesschichtzyklus möglich sind. Bilder und weitere grosse Dateien können dann in einem kleineren Zyklus separat gesichert werden.
#### Alias für das interaktive Menü:

```bash
moodle-backup
```
<div align="center">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/demo-moodle-backup.png" />
</div>

#### Parameter für die Automatisierung

- `moodle-backup --full`  
    Führt ein komplettes Backup (Datenbank + Moodledata) durch.
    
- `moodle-backup --db-only`  
    Sichert nur die Datenbank.
    
- `moodle-backup --moodle-only`  
    Sichert nur das Moodle-Datenverzeichnis.

### Restore durchführen

Für den Restore steht nur ein interaktives Menü zur Verfügung. Dieses listet alle vorhandenen Backups auf und bietet die Möglichkeit, eines davon auszuwählen. Das gewählte Backup wird danach automatisch wiederhergestellt.

>⚠️ **Wichtig:**  
 Nach dem Restore ist ein Neustart der Container notwendig.

#### Alias für das interaktive Menü:

```bash
moodle-restore
```
<div align="center">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/demo-moodle-restore.png" />
</div>

### Cronjobs erstellen

Backups können ausserdem mithilfe des Linux-Tools `cron` automatisiert werden. Dafür steht ebenfalls ein interaktives Menü zur Verfügung, mit dem der Typ (z. B. täglich) sowie die Uhrzeit konfiguriert werden können. Dieses Tool erleichtert die Einrichtung der automatischen Backups.
#### Alias für das interaktive Menü:

```bash
moodle-cronjob
```

<div align="center">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/demo-moodle-cronjob.png" />
</div>


##  📜 8 Funktion und Aufgaben des Scripts

-

## ❓ FAQ – Häufige Probleme und Lösungen

#### Probleme mit dem Speicherplatz der VM  
Der Speicherplatz der VM ist oft knapp bemessen. Um mehr Platz zu schaffen, solltest du zunächst in den VM-Einstellungen unter **Harddisk** die Festplatte von z.B. 25 GB auf 35 GB erweitern.  
Anschliessend kannst du nach dem Neustart von Ubuntu mit der vorinstallierten GNOME-App **Disks** den zusätzlichen Speicherplatz innerhalb der VM vergrössern.

#### Netzwerkprobleme der VM  
Die Netzwerkkonfiguration bei VMs kann etwas kompliziert sein, insbesondere bei mehreren Netzwerkadaptern.  
Es wird grundsätzlich empfohlen, als Netzwerktyp **NAT** oder **Bridged** auszuwählen. Innerhalb der VM sollte die Netzwerkkonfiguration auf **DHCP** gesetzt sein (wichtig auch für die DNS-Auflösung).  
Falls die VM keine IP-Adresse erhält, hilft meist ein erneutes Anfordern der IP mit dem Befehl:

```bash
sudo dhclient -r
````

#### Probleme mit der DNS-Auflösung im Docker-Container

Manchmal können Host- oder DHCP-Konfigurationen dazu führen, dass Docker-Container keine DNS-Auflösung durchführen können.  
Diese Probleme hängen häufig mit der VM-Netzwerk- und DNS-Einstellung zusammen. Es empfiehlt sich, die Netzwerk- und DNS-Konfiguration der VM gründlich zu prüfen und gegebenenfalls anzupassen.

####  Upgrade-Prozess kann nicht durchgeführt werden

Ubuntu blockiert den Upgrade-Prozess oft, weil im Hintergrund ein anderer Prozess läuft, der dieselben Ressourcen nutzt.  
In den meisten Fällen wird das Problem durch einfaches Abwarten gelöst.  
Falls das nicht hilft, kann ein Neustart der VM das Problem beheben. Danach sollte das Upgrade-Script erneut ausgeführt werden.
