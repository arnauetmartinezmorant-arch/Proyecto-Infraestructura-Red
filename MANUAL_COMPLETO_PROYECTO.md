# MANUAL COMPLETO DEL PROYECTO (todo, de principio a fin)


## Estrategia de RAM con 16 GB (importante)
No arranquemos las 8 VMs a la vez. **DC1 siempre encendido** (es DNS y dominio) y levanta por bloques:
- **Bloque dominio:** DC1 + DC2  -> replicación AD.
- **Bloque datos:** DC1 + SQL01 + SQL02  -> Always On.
- **Bloque web:** DC1 + WEB01 + WEB02  -> IIS + NLB.
- **Bloque copias/explotación:** DC1 + BACKUP01 + ADM (+ la pareja que toque).

Pon cada VM a **2 GB** (DC puede ir a 1,5 GB). En GNS3 arranca/para nodos con clic derecho -> Start/Stop.

## Inventario de máquinas y direccionamiento
| Nodo | VLAN | IP | Rol |
|------|------|----|-----|
| FW-RRAS | perímetro | WAN + 10.10.x.1 | Cortafuegos + NAT + VPN (RRAS) |
| SW-CORE | - | - | Switch L3 (VLAN 10/20/30) |
| DC1 | 10 | 10.10.10.11 | AD DS + DNS + DHCP |
| DC2 | 10 | 10.10.10.12 | AD DS + DNS (réplica) |
| WEB01 | 10 | 10.10.10.22 | IIS (nodo 1 NLB) |
| WEB02 | 10 | 10.10.10.23 | IIS (nodo 2 NLB) |
| **VIP NLB** | 10 | **10.10.10.20** | Web balanceada (443) |
| SQL01 | 10 | 10.10.10.31 | SQL Server (réplica 1) |
| SQL02 | 10 | 10.10.10.32 | SQL Server (réplica 2) |
| **Clúster WSFC** | 10 | 10.10.10.35 | IP del clúster |
| **Listener AG** | 10 | **10.10.10.30** | SQL Always On (1433) |
| BACKUP01 | 30 | 10.10.30.41 | Copias 3-2-1 |
| ADM | 30 | 10.10.30.40 | Gestión + explotación (WAC/PRTG) |

---

# FASE 1 - RED en GNS3 (RN01)
1. Importa las VMs a GNS3 y monta la topología (ver `GUIA_PRINCIPIANTE_PASO_A_PASO.md` Partes 4-5). Usa un **switch L3** con VLAN 10/20/30 y un **FW-RRAS** entre el switch y la **NAT/Cloud** (Internet).
2. **IPs** (PowerShell admin en cada VM, ajusta IP/VLAN):
```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.10.10.11 -PrefixLength 24 -DefaultGateway 10.10.10.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1   # solo DC1; el resto -> 10.10.10.11
```
3. **DHCP** de usuarios (en DC1, tras crear el dominio):
```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerv4Scope -Name "VLAN20-Usuarios" -StartRange 10.10.20.100 -EndRange 10.10.20.200 -SubnetMask 255.255.255.0
Set-DhcpServerv4OptionValue -ScopeId 10.10.20.0 -Router 10.10.20.1 -DnsServer 10.10.10.11,10.10.10.12 -DnsDomain corp.local
```
4. **Cortafuegos perimetral (FW-RRAS):** instala el rol y activa NAT + VPN:
```powershell
Install-WindowsFeature RemoteAccess, Routing -IncludeManagementTools
Install-RemoteAccess -VpnType VpnS2S    # luego en consola RRAS: NAT + SSTP
```
5. **Segmentación (Windows Defender Firewall)** - ejemplo en SQL01 para aislar la BD (TC-12):
```powershell
New-NetFirewallRule -DisplayName "SQL solo desde WEB" -Direction Inbound -Protocol TCP -LocalPort 1433 -RemoteAddress 10.10.10.22,10.10.10.23,10.10.30.0/24 -Action Allow
New-NetFirewallRule -DisplayName "SQL deny resto 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Block
```
> 📸 **Evidencias FASE 1:** topología GNS3 en verde - configs de SW-CORE/FW - `ping` entre VLANs permitidas - cliente de VLAN20 recibe IP por DHCP. -> `evidencias/01_red/`

---

# FASE 2 - DOMINIO Active Directory (RN01, US_01/02/03, FR_01/02/03)
**DC1** (crear el bosque):
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName corp.local -DomainNetbiosName CORP -InstallDns -Force
```
**DC2** (DNS apuntando a DC1; luego promover como DC adicional):
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSDomainController -DomainName corp.local -InstallDns -Credential (Get-Credential) -Force
```
**Unir miembros** (en WEB01/WEB02/SQL01/SQL02/BACKUP01):
```powershell
Add-Computer -DomainName corp.local -Credential (Get-Credential) -Restart   # usuario CORP\Administrador
```
**OUs, grupos, usuario y GPOs** (en DC1):
```powershell
foreach($ou in "Administracion","Oficinas","Tecnicos","Servidores"){ New-ADOrganizationalUnit -Name $ou -Path "DC=corp,DC=local" }
New-ADGroup -Name GG_Administracion -GroupScope Global -Path "OU=Administracion,DC=corp,DC=local"
New-ADGroup -Name GG_Tecnicos       -GroupScope Global -Path "OU=Tecnicos,DC=corp,DC=local"
New-ADGroup -Name GG_Oficinas       -GroupScope Global -Path "OU=Oficinas,DC=corp,DC=local"
New-ADUser -Name "Juan Lopez" -SamAccountName jlopez -UserPrincipalName jlopez@corp.local `
  -Path "OU=Oficinas,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "P@ssw0rd2025" -AsPlainText -Force) -Enabled $true
Add-ADGroupMember GG_Oficinas jlopez
New-GPO -Name "GPO_Seguridad_Base"        | New-GPLink -Target "DC=corp,DC=local"
New-GPO -Name "GPO_Oficinas_Restrictiva"  | New-GPLink -Target "OU=Oficinas,DC=corp,DC=local"
```
**Política de contraseñas** (FR_04):
```powershell
Set-ADDefaultDomainPasswordPolicy -Identity corp.local -MinPasswordLength 10 -ComplexityEnabled $true -LockoutThreshold 5
```
> 📸 **Evidencias FASE 2:** `repadmin /replsummary` OK - árbol de OUs/grupos - GPO aplicada (TC-11) - alta de usuario (TC-15). -> `evidencias/02_dominio/`

---

# FASE 3 - DATOS: SQL Server Always On (RN02, RN04, US_04, NFR_02)
1. Instala **SQL Server** en SQL01 y SQL02 + **SSMS**.
2. **Clúster de conmutación (WSFC)** y Always On:
```powershell
# en SQL01 y SQL02
Install-WindowsFeature Failover-Clustering -IncludeManagementTools
# crear el cluster (desde SQL01)
New-Cluster -Name CLUSQL -Node SQL01,SQL02 -StaticAddress 10.10.10.35 -NoStorage
Enable-SqlAlwaysOn -ServerInstance SQL01 -Force
Enable-SqlAlwaysOn -ServerInstance SQL02 -Force
```
3. **BD, TDE y logins** (SSMS en SQL01):
```sql
CREATE DATABASE intranet_corporativa;
GO
USE master; CREATE MASTER KEY ENCRYPTION BY PASSWORD='Str0ng!Master';
CREATE CERTIFICATE TDECert WITH SUBJECT='TDE';
USE intranet_corporativa;
CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM=AES_256 ENCRYPTION BY SERVER CERTIFICATE TDECert;
ALTER DATABASE intranet_corporativa SET ENCRYPTION ON;
CREATE LOGIN app_user    WITH PASSWORD='App!2025';
CREATE LOGIN backup_user WITH PASSWORD='Bkp!2025';
CREATE LOGIN admin_db    WITH PASSWORD='Adm!2025';
USE intranet_corporativa;
CREATE USER app_user FOR LOGIN app_user;       EXEC sp_addrolemember 'db_datareader','app_user'; EXEC sp_addrolemember 'db_datawriter','app_user';
CREATE USER backup_user FOR LOGIN backup_user; EXEC sp_addrolemember 'db_datareader','backup_user';
ALTER SERVER ROLE sysadmin ADD MEMBER admin_db;
```
4. **Esquema de incidencias** + datos de ejemplo: ejecuta el bloque del apartado 7C de `RUTA_RAPIDA_16GB_5H.md` (o tu modelo completo de los apartados 15-17).
5. **Availability Group + Listener** (SSMS en SQL01):
```sql
ALTER DATABASE intranet_corporativa SET RECOVERY FULL;
BACKUP DATABASE intranet_corporativa TO DISK='C:\Backups\full.bak';
BACKUP LOG intranet_corporativa TO DISK='C:\Backups\log.trn';
CREATE AVAILABILITY GROUP AG_Intranet FOR DATABASE intranet_corporativa
 REPLICA ON 'SQL01' WITH (ENDPOINT_URL='TCP://SQL01.corp.local:5022', AVAILABILITY_MODE=SYNCHRONOUS_COMMIT, FAILOVER_MODE=AUTOMATIC),
            'SQL02' WITH (ENDPOINT_URL='TCP://SQL02.corp.local:5022', AVAILABILITY_MODE=SYNCHRONOUS_COMMIT, FAILOVER_MODE=AUTOMATIC);
ALTER AVAILABILITY GROUP AG_Intranet ADD LISTENER 'AG-Intranet' (WITH IP (('10.10.10.30','255.255.255.0')), PORT=1433);
```
> 📸 **Evidencias FASE 3:** *Availability Group Dashboard* en *Synchronized/Healthy* - prueba de failover (FASE 8). -> `evidencias/03_datos/`

---

# FASE 4 - WEB: IIS + balanceo NLB (RN02, balanceo de carga)
**WEB01 y WEB02:**
```powershell
Install-WindowsFeature Web-Server, NLB -IncludeManagementTools
Set-Content C:\inetpub\wwwroot\iisstart.htm "<h1>Servidor WEBxx</h1>"   # pon WEB01 / WEB02
```
**Clúster NLB (en WEB01):**
```powershell
New-NlbCluster -InterfaceName "Ethernet" -ClusterName WEB-NLB -ClusterPrimaryIP 10.10.10.20 -SubnetMask 255.255.255.0 -OperationMode Multicast
Add-NlbClusterPortRule -StartPort 443 -EndPort 443 -Protocol Tcp -Affinity Single
Add-NlbClusterNode -NewNodeName WEB02 -NewNodeInterface "Ethernet"
Get-NlbClusterNode | ft Name,State    # -> Converged
```
**Sincronizar contenido WEB01->WEB02:** `robocopy C:\inetpub\wwwroot \\WEB02\c$\inetpub\wwwroot /MIR`
> En VirtualBox: adaptadores de WEB01/WEB02 en **modo promiscuo: Permitir todo** (para NLB).
> 📸 **Evidencias FASE 4:** NLB *Converged* - web servida por la VIP. -> `evidencias/04_web/`

---

# FASE 5 - COPIAS 3-2-1 (RN04, US_04)
```powershell
Install-WindowsFeature Windows-Server-Backup    # en BACKUP01 y servidores
wbadmin start backup -backupTarget:\\BACKUP01\Copias$ -include:C: -systemState -quiet
sqlcmd -S AG-Intranet -E -Q "BACKUP DATABASE intranet_corporativa TO DISK='\\BACKUP01\Copias$\db.bak' WITH COMPRESSION, CHECKSUM"
Backup-GPO -All -Path "\\BACKUP01\Copias$\GPO"
robocopy \\BACKUP01\Copias$ \\OFFSITE\Copias$ /MIR /Z    # 1 copia OFFSITE
```
**Prueba de restauración (TC-14):** `RESTORE DATABASE ... WITH MOVE ... RECOVERY;` (ver `windows/alta-disponibilidad.md`).
> 📸 **Evidencias FASE 5:** log de copia correcta - captura de restauración. -> `evidencias/05_backup/`

---

# FASE 6 - EXPLOTACIÓN DE LA INFORMACIÓN (RN05, US_07, NFR auditoría)
1. **Métricas (PerfMon):** Data Collector Sets (CPU/RAM/disco/red/IIS/SQL) - ver `observabilidad/metricas-logs-y-alertas.md`.
2. **Cuadros de mando:** **Windows Admin Center** (panel de servidores) y **PRTG** (sensores: Ping, HTTP de la VIP, Disk Free, servicios, contadores).
3. **Alertas:** en PRTG, aviso si **disponibilidad < 99 %** o disco < 5 %.
4. **Logs (WEF):** centraliza eventos en un colector y consulta con `Get-WinEvent`.
5. **Consultas/informes T-SQL:** ejecuta `observabilidad/informes-sql.sql` en SSMS.
> 📸 **Evidencias FASE 6:** capturas de PerfMon, WAC y PRTG - `ForwardedEvents` - resultados de los informes SQL. -> `evidencias/06_explotacion/`

---

# FASE 7 - ACCESO REMOTO VPN (RN01 / US_09 / FR_09)
En FW-RRAS: consola **Enrutamiento y acceso remoto** -> configurar **VPN SSTP**, dar permiso de marcado al grupo `GG_Tecnicos` y abrir el puerto 443 (SSTP).
> 📸 **Evidencia:** conexión VPN establecida desde un cliente externo. -> `evidencias/01_red/`

---

# FASE 8 - PRUEBAS DE ACEPTACIÓN (TC-11 a TC-15 + failovers)
| Prueba | Acción | Evidencia |
|--------|--------|-----------|
| TC-11 GPO por rol | Iniciar sesión como usuario de "Oficinas" e intentar abrir Panel de control | Bloqueo por GPO |
| TC-12 Aislamiento BD | `telnet 10.10.10.30 1433` desde VLAN20 | Falla (firewall) |
| TC-13 Failover web | Apagar WEB01, recargar la VIP | Responde WEB02 |
| Failover BD | `Stop-Service MSSQLSERVER` en SQL01 | SQL02 pasa a primaria |
| TC-14 Restauración | Restaurar BD/archivo desde backup | Restauración OK |
| TC-15 Alta usuario | Crear usuario y verificar OU/grupo | Usuario creado |
> 📸 Todo en -> `evidencias/07_pruebas/`

---

# Mapa de cumplimiento (requisito -> cómo se cumple)
| Requisito | Cómo se cumple |
|-----------|----------------|
| RN01 Acceso seguro / segmentación | VLANs + ACLs firewall + VPN RRAS + permisos AD |
| RN02 Alta disponibilidad | DC1/DC2, SQL Always On, IIS+NLB, failover automático |
| RN03 Mantenimiento programado | Ventanas de mantenimiento + actualizaciones (doc) |
| RN04 Backup y recuperación | Copias 3-2-1 + prueba de restauración |
| RN05 Soporte/escalado | Sistema de incidencias + informes T-SQL |
| RN06 Actualización/seguridad | TDE, BitLocker, hardening, parches |
| US/FR/NFR | OUs, grupos, GPOs, DHCP, DNS, monitorización, disponibilidad 99% |
