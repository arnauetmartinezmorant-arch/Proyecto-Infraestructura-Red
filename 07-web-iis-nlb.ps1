# 07-web-iis-nlb.ps1 — Instala IIS y crea/une el clúster NLB.
# Ejecutar como Admin. En WEB01:  .\07-web-iis-nlb.ps1 -Rol primero
#                     En WEB02:  .\07-web-iis-nlb.ps1 -Rol segundo
param([ValidateSet("primero","segundo")][string]$Rol = "primero")
$ErrorActionPreference = "Stop"

Install-WindowsFeature Web-Server, NLB -IncludeManagementTools
# Pagina distinta en cada nodo para "ver" el balanceo
Set-Content C:\inetpub\wwwroot\iisstart.htm "<html><body style='font-family:sans-serif'><h1>Servidor $env:COMPUTERNAME</h1><p>Intranet corporativa - corp.local</p></body></html>"

if ($Rol -eq "primero") {
  Write-Host "Creando clúster NLB con VIP 10.10.10.20 ..."
  New-NlbCluster -InterfaceName "Ethernet" -ClusterName "WEB-NLB" -ClusterPrimaryIP 10.10.10.20 -SubnetMask 255.255.255.0 -OperationMode Multicast
  Get-NlbCluster | Get-NlbClusterPortRule | Remove-NlbClusterPortRule -Force -ErrorAction SilentlyContinue
  Add-NlbClusterPortRule -StartPort 443 -EndPort 443 -Protocol Tcp -Affinity Single
  Add-NlbClusterPortRule -StartPort 80  -EndPort 80  -Protocol Tcp -Affinity Single
  Write-Host "Clúster creado. Ahora ejecuta este script en WEB02 con -Rol segundo, o anadelo desde aqui:"
  Write-Host '  Add-NlbClusterNode -NewNodeName WEB02 -NewNodeInterface "Ethernet"'
} else {
  Write-Host "Uniendo WEB02 al clúster WEB-NLB ..."
  Get-NlbCluster -HostName WEB01 | Add-NlbClusterNode -NewNodeName $env:COMPUTERNAME -NewNodeInterface "Ethernet"
}
Get-NlbClusterNode | Format-Table Name, State   # -> Converged (EVIDENCIA)
