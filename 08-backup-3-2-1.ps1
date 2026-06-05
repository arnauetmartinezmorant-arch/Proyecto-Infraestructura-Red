# 08-backup-3-2-1.ps1 — Copias 3-2-1 automatizadas (tareas programadas). Ejecutar como Admin.
$ErrorActionPreference = "Continue"
Install-WindowsFeature Windows-Server-Backup -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path C:\Backups -Force | Out-Null

# 1) Copia diaria de la BD (03:00) via sqlcmd contra el Listener
$accionDB = New-ScheduledTaskAction -Execute "sqlcmd.exe" -Argument "-S AG-Intranet -E -Q `"BACKUP DATABASE intranet_corporativa TO DISK='\\BACKUP01\Copias$\db.bak' WITH INIT, COMPRESSION, CHECKSUM`""
Register-ScheduledTask -TaskName "Copia_BD_Diaria" -Action $accionDB -Trigger (New-ScheduledTaskTrigger -Daily -At 3am) -User "SYSTEM" -RunLevel Highest -Force

# 2) Copia del estado del sistema (03:30)
$accionSys = New-ScheduledTaskAction -Execute "wbadmin.exe" -Argument "start systemstatebackup -backupTarget:\\BACKUP01\Copias$ -quiet"
Register-ScheduledTask -TaskName "Copia_EstadoSistema" -Action $accionSys -Trigger (New-ScheduledTaskTrigger -Daily -At 3:30am) -User "SYSTEM" -RunLevel Highest -Force

# 3) Copia de GPO (solo en DC1)
# Backup-GPO -All -Path "\\BACKUP01\Copias$\GPO"

# 4) Replica OFFSITE (04:00) -> 1 copia fuera de sitio
$accionOff = New-ScheduledTaskAction -Execute "robocopy.exe" -Argument "\\BACKUP01\Copias$ \\OFFSITE\Copias$ /MIR /Z /R:3 /W:5"
Register-ScheduledTask -TaskName "Copia_Offsite" -Action $accionOff -Trigger (New-ScheduledTaskTrigger -Daily -At 4am) -User "SYSTEM" -RunLevel Highest -Force

Write-Host "Tareas de copia 3-2-1 creadas. Prueba manual: sqlcmd ... BACKUP / RESTORE (EVIDENCIA TC-14)."
