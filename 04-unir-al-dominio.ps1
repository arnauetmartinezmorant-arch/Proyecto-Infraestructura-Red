# 04-unir-al-dominio.ps1 — Une la maquina al dominio corp.local. Ejecutar como Admin.
# Requisito: 01-config-ip.ps1 ya ejecutado con -DNS 10.10.10.11
$ErrorActionPreference = "Stop"
$cred = Get-Credential -Message "Credenciales del dominio" -UserName "CORP\Administrador"
Add-Computer -DomainName "corp.local" -Credential $cred -Restart
