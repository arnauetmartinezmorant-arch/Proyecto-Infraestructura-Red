# 05-sql-instalar.ps1 — Instala SQL Server DESATENDIDO + habilita clustering/AlwaysOn.
# Ejecutar como Admin en SQL01 y SQL02. Necesitas el instalador de SQL (setup.exe) montado.
# Uso: .\05-sql-instalar.ps1 -SetupPath "D:\setup.exe"
param([string]$SetupPath = "D:\setup.exe")
$ErrorActionPreference = "Stop"

# Caracteristica de clusterizacion (para Always On)
Install-WindowsFeature Failover-Clustering -IncludeManagementTools

# Fichero de configuracion desatendida
$ini = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME=MSSQLSERVER
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
SQLSYSADMINACCOUNTS="CORP\Administrador"
AGTSVCSTARTUPTYPE="Automatic"
SQLSVCSTARTUPTYPE="Automatic"
TCPENABLED="1"
IACCEPTSQLSERVERLICENSETERMS="True"
QUIET="True"
"@
$iniPath = "$env:TEMP\SQLConfig.ini"
$ini | Out-File -FilePath $iniPath -Encoding ascii

Write-Host "Instalando SQL Server (desatendido)... esto tarda varios minutos."
& $SetupPath /ConfigurationFile=$iniPath /SAPWD="Sql!2025"

# Habilitar Always On (requiere que el clúster WSFC exista; ver paso siguiente)
Import-Module SqlServer -ErrorAction SilentlyContinue
Write-Host "SQL instalado. Crea el clúster WSFC desde SQL01:"
Write-Host '  New-Cluster -Name CLUSQL -Node SQL01,SQL02 -StaticAddress 10.10.10.35 -NoStorage'
Write-Host "Y luego en cada nodo: Enable-SqlAlwaysOn -ServerInstance \$env:COMPUTERNAME -Force"
