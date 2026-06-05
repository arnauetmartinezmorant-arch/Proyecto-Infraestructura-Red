# 09-explotacion.ps1 — Metricas (PerfMon) + reenvio de logs (WEF). Ejecutar como Admin.
$ErrorActionPreference = "Continue"

# --- Metricas: Data Collector Set de PerfMon (recogida cada 15s a fichero .blg) ---
logman create counter PIM_Metricas -f bincirc -v mmddhhmm -max 200 -si 00:00:15 `
  -c "\Processor(_Total)\% Processor Time" "\Memory\Available MBytes" "\LogicalDisk(_Total)\% Free Space" "\Network Interface(*)\Bytes Total/sec" `
  -o "C:\PerfLogs\PIM_Metricas" 2>$null
logman start PIM_Metricas 2>$null
Write-Host "PerfMon: coleccion PIM_Metricas iniciada (C:\PerfLogs). EVIDENCIA: abre perfmon y captura."

# --- Logs: este equipo como ORIGEN que reenvia al colector (WinRM) ---
winrm quickconfig -quiet
Write-Host "WinRM activado. En el COLECTOR (p.ej. ADM o BACKUP01) ejecuta: wecutil qc /q  y crea una suscripcion."
Write-Host "Consulta de ejemplo de logs (EVIDENCIA):"
Write-Host '  Get-WinEvent -FilterHashtable @{LogName=''Security''; Id=4624} -MaxEvents 20 | Format-Table TimeCreated,Id'
