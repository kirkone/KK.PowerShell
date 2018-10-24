# Build Agents

## Agent herunterladen

Den aktuell vewendeten Agent kann man sich hier herunter laden: [Azure Pipelines Agent](https://github.com/Microsoft/azure-pipelines-agent/releases)  
Man erhält eine .zip Datei welche man neben `Setup-Agents.ps1` ablegt.

## Konfigurieren

In der Datei `config.json` müssen alle Parameter eingetragen welche für die Einrichtung nötig sind.

| Variable | Wert | Bemerkungen |
| --- | --- | --- |
| accounturl | https://dev.azure.com/ACCOUNTNAME/ |
| pool | Awesome-Pool | |
| agentprefix | Awesome-Agent | Der Agent Name ergibt sich aus `agentprefix`+`agent`. Wobei `agent` einem element aus `agents` entspricht. |
| agents | [ "01","02" ] | Eine Liste der anzulegenden Agents |
| workfolder | C:\\W | In diesem Ordner werden die Build Jobs abgelegt. Es ist ein sehr kurzer Pfad zu empfehlen |
| agentsfolder | C:\\Agents | In diesem Ordner werden die Programmdateien der Agents abgelegt |
| windowslogonaccount | DOMAIN\\AgentUser | Der Nutzer als welcher der Dienst ausgeführt wird |

## Agents anlegen

Das Skript `Setup-Agents.ps1` legt die in der config.json angegebenen Agents an und registriert diese in der Agent-Queue.

**Das Skript muss als Administrator ausgeführt werden**

## Agents entfernen

Das Skript `Cleanup-Agents.ps1` entfernt die in der config.json angegebenen Agents.

**Das Skript muss als Administrator ausgeführt werden**

