# Scripts de automatización del proyecto (casi "un clic")

Estos scripts **configuran el proyecto solos**. Permitiendo ahorrar tiempo y automatizar nuestro proyecto: crear las VMs Windows en
VirtualBox/GNS3, copiar la carpeta `scripts/` dentro de cada VM y ejecutar el script que toca
**como Administrador** (PowerShell: clic derecho → "Ejecutar como administrador").

> Si PowerShell bloquea la ejecución, ejecuta una vez:
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force`

## Orden de ejecución
| Paso | VM | Script | Qué hace |
|------|----|--------|----------|
| 1 | todas | `01-config-ip.ps1` | Pone nombre + IP fija + DNS (reinicia) |
| 2 | DC1 | `02a-dc1-crear-dominio.ps1` | Crea el dominio corp.local (reinicia solo) |
| 3 | DC1 | `02b-dc1-postconfig.ps1` | OUs, grupos, usuario, GPOs, DHCP, política de claves |
| 4 | DC2 | `03-dc2-replica.ps1` | Promueve DC2 como réplica de AD/DNS |
| 5 | WEB01,WEB02,SQL01,SQL02,BACKUP01 | `04-unir-al-dominio.ps1` | Une la máquina al dominio (reinicia) |
| 6 | SQL01 y SQL02 | `05-sql-instalar.ps1` | Instala SQL Server desatendido |
| 7 | SQL01 | `06-sql-bd-y-alwayson.sql` | Crea BD, TDE, logins, esquema y Always On (en SSMS) |
| 8 | WEB01 y WEB02 | `07-web-iis-nlb.ps1` | Instala IIS + crea/une el clúster NLB |
| 9 | BACKUP01/SQL01 | `08-backup-3-2-1.ps1` | Tareas programadas de copia 3-2-1 |
| 10 | servidores | `09-explotacion.ps1` | Métricas (PerfMon) + reenvío de logs (WEF) |
