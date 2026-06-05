# 02b-dc1-postconfig.ps1 — OUs, grupos, usuario, GPOs, DHCP y politica de claves.
# Ejecutar como Administrador en DC1 DESPUES de crear el dominio (02a) y reiniciar.
$ErrorActionPreference = "Continue"
Import-Module ActiveDirectory

# --- OUs ---
foreach($ou in "Administracion","Oficinas","Tecnicos","Servidores"){
  if(-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)){
    New-ADOrganizationalUnit -Name $ou -Path "DC=corp,DC=local"
  }
}
# --- Grupos ---
New-ADGroup GG_Administracion -GroupScope Global -Path "OU=Administracion,DC=corp,DC=local" -ErrorAction SilentlyContinue
New-ADGroup GG_Tecnicos       -GroupScope Global -Path "OU=Tecnicos,DC=corp,DC=local"       -ErrorAction SilentlyContinue
New-ADGroup GG_Oficinas       -GroupScope Global -Path "OU=Oficinas,DC=corp,DC=local"       -ErrorAction SilentlyContinue
# --- Usuario de ejemplo ---
New-ADUser -Name "Juan Lopez" -SamAccountName jlopez -UserPrincipalName jlopez@corp.local `
  -Path "OU=Oficinas,DC=corp,DC=local" `
  -AccountPassword (ConvertTo-SecureString "P@ssw0rd2025" -AsPlainText -Force) -Enabled $true -ErrorAction SilentlyContinue
Add-ADGroupMember GG_Oficinas jlopez -ErrorAction SilentlyContinue

# --- Politica de contrasenas (FR_04) ---
Set-ADDefaultDomainPasswordPolicy -Identity corp.local -MinPasswordLength 10 -ComplexityEnabled $true -LockoutThreshold 5

# --- GPOs por rol ---
Import-Module GroupPolicy
if(-not (Get-GPO -Name "GPO_Seguridad_Base" -ErrorAction SilentlyContinue)){ New-GPO -Name "GPO_Seguridad_Base" | New-GPLink -Target "DC=corp,DC=local" }
if(-not (Get-GPO -Name "GPO_Oficinas_Restrictiva" -ErrorAction SilentlyContinue)){ New-GPO -Name "GPO_Oficinas_Restrictiva" | New-GPLink -Target "OU=Oficinas,DC=corp,DC=local" }

# --- DHCP para la VLAN de usuarios ---
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName "dc1.corp.local" -IPAddress 10.10.10.11 -ErrorAction SilentlyContinue
Add-DhcpServerv4Scope -Name "VLAN20-Usuarios" -StartRange 10.10.20.100 -EndRange 10.10.20.200 -SubnetMask 255.255.255.0 -ErrorAction SilentlyContinue
Set-DhcpServerv4OptionValue -ScopeId 10.10.20.0 -Router 10.10.20.1 -DnsServer 10.10.10.11,10.10.10.12 -DnsDomain "corp.local" -ErrorAction SilentlyContinue
Restart-Service dhcpserver -ErrorAction SilentlyContinue

Write-Host "DC1 configurado: OUs, grupos, usuario, GPOs, politica y DHCP. EVIDENCIA: repadmin /replsummary"
