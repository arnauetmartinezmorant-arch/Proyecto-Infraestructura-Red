# 01-config-ip.ps1 — Nombre + IP fija + DNS. Ejecutar como Administrador.
# Uso: .\01-config-ip.ps1 -NewName DC1 -IP 10.10.10.11 -DNS 127.0.0.1
param(
  [Parameter(Mandatory=$true)][string]$NewName,
  [Parameter(Mandatory=$true)][string]$IP,
  [int]$Prefix = 24,
  [string]$GW  = "10.10.10.1",
  [string[]]$DNS = @("10.10.10.11")
)
$ErrorActionPreference = "Stop"
$ad = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name
Write-Host "Adaptador detectado: $ad"
Get-NetIPAddress -InterfaceAlias $ad -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceAlias $ad -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceAlias $ad -IPAddress $IP -PrefixLength $Prefix -DefaultGateway $GW | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $ad -ServerAddresses $DNS
Write-Host "IP $IP / DNS $($DNS -join ',') aplicados."
if ($env:COMPUTERNAME -ne $NewName) {
  Rename-Computer -NewName $NewName -Force
  Write-Host "Equipo renombrado a $NewName. Reiniciando en 5s..."
  Start-Sleep 5; Restart-Computer -Force
} else {
  Write-Host "El equipo ya se llama $NewName. Listo."
}
