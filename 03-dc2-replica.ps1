# 03-dc2-replica.ps1 — Promueve DC2 como controlador adicional (replica de AD + DNS).
# Requisito: 01-config-ip.ps1 con -DNS 10.10.10.11 (que apunte al DC1). Ejecutar como Admin en DC2.
$ErrorActionPreference = "Stop"
$dsrm = ConvertTo-SecureString "P@ssw0rd2025" -AsPlainText -Force
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment
$cred = Get-Credential -Message "Credenciales del dominio" -UserName "CORP\Administrador"
Install-ADDSDomainController `
  -DomainName "corp.local" `
  -InstallDns `
  -Credential $cred `
  -SafeModeAdministratorPassword $dsrm `
  -Force
# (reinicia automaticamente). Luego en DC1: repadmin /replsummary  -> EVIDENCIA
