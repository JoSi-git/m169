# 🚀 **Projektplan: Migration: Moodle auf Docker**

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
```

### Repository aktualisieren:
```bash
git pull
```

## 🛠️ 3 Troubleshooting

### Fehlende Berechtigung für `install.sh`  
Wenn beim Ausführen von `install.sh` ein Berechtigungsfehler auftritt, stelle sicher, dass die Datei ausführbar ist:
```bash
chmod +x install.sh
```

Danach kann das Skript wie folgt ausgeführt werden:
```bash
./install.sh
```
