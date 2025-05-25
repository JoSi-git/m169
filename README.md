<div align="left">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/m169-title.png" />
</div>

[![Silas Gubler](https://img.shields.io/badge/Silas_Gubler-FF7F50?style=for-the-badge)](https://github.com/arkaizn)
[![David Kästli](https://img.shields.io/badge/David_Kästli-00FA9A?style=for-the-badge)](https://github.com/dka-git)
[![Jonas Sieber](https://img.shields.io/badge/Jonas_Sieber-4682B4?style=for-the-badge)](https://github.com/josi-git)
[![Lizenz](https://img.shields.io/badge/Lizenz-DAA520?style=for-the-badge)](https://github.com/JoSi-git/m346/blob/main/LICENSE)  
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

Anschließend kann das Installationsskript gestartet werden:

```bash
./install.sh
```

## ⚙️ 3 Konfiguration (.env)

Alle anpassbaren Variablen wie **Installationspfade**, **Datenbank-Zugangsdaten** und **PHP-Einstellungen** befinden sich zentral in der Datei `.env`.  
Diese Datei ermöglicht eine flexible Anpassung ohne direkte Änderungen am Skript.

### Beispielhafte `.env`-Werte:

```env
INSTALL_DIR=/opt/moodle-docker
BACKUP_DIR=/opt/moodle-docker/dumps
RESTORE_DIR=opt/tools/moodle-restore

MYSQL_ROOT_PASSWORD="Riethuesli>12345"
MYSQL_ROOT_PASSWORD_OLD="Riethuesli>12345"
MYSQL_DATABASE=moodle
MYSQL_USER=vmadmin
MYSQL_PASSWORD="Riethuesli>12345"

CONTAINER_MOODLE="moodle-web"
CONTAINER_DB="moodle-db"

PHP_INI-upload_max_filesize=200M
PHP_INI-post_max_size=210M
MOODLE_LOGSTORE=file
MOODLE_FILELOG_LOCATION=/var/moodledata/logs/moodle.log
```

> ⚠️ **Wichtig:**  
> Die Datei `.env` enthält sensible Informationen und sollte **niemals öffentlich geteilt** werden. Sie sollte weiterhin in `.gitignore` eingetragen sein.

## 🔐 4 Zugangsdaten der Moodle-Weboberfläche

Die Benutzer und Passwörter für die Moodle-Instanz selbst (nicht die Datenbank) befinden sich **nicht** in der `.env`, sondern müssen direkt in den jeweiligen `config.php`-Dateien der Moodle-Installation geändert werden.

Typische Pfade:

```bash
/opt/moodle-docker/moodle/config.php
/opt/moodle-docker/moodledata/config.php (falls vorhanden)
```

