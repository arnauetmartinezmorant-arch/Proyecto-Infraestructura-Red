# 02a-dc1-crear-dominio.ps1 — Crea el bosque corp.local en DC1. Ejecutar como Administrador en DC1.
# El equipo SE REINICIA solo al terminar. Despues ejecuta 02b-dc1-postconfig.ps1
$ErrorActionPreference = "Stop"
$dsrm = ConvertTo-SecureString "P@ssw0rd2025" -AsPlainText -Force   # contrasena modo restauracion
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment
Install-ADDSForest `
  -DomainName "corp.local" `
  -DomainNetbiosName "CORP" `
  -InstallDns `
  -SafeModeAdministratorPassword $dsrm `
  -Force
# (Install-ADDSForest reinicia el servidor automaticamente)
