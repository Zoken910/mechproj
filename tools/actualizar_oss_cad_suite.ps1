# actualizar_oss_cad_suite.ps1: instala o actualiza OSS CAD Suite en Windows (yosys, iverilog, vvp,
# gtkwave, openFPGALoader...). Lo pidio el profe en la reunion del 17.11.2026.
# Por defecto en C:\oss-cad-suite (sin espacios en la ruta: lo recomienda YosysHQ).
#
# Uso (PowerShell, desde la carpeta del repo):
#   powershell -ExecutionPolicy Bypass -File tools\actualizar_oss_cad_suite.ps1
#   powershell -ExecutionPolicy Bypass -File tools\actualizar_oss_cad_suite.ps1 -Fecha 2026-11-17
#   powershell -ExecutionPolicy Bypass -File tools\actualizar_oss_cad_suite.ps1 -Destino D:\oss-cad-suite
# Despues, en cada terminal nueva:
#   PowerShell:  . C:\oss-cad-suite\environment.ps1
#   CMD:         C:\oss-cad-suite\environment.bat      (o abrir C:\oss-cad-suite\start.bat)
# y para probar el repo:  python tools\correr_pruebas.py --sintesis
#
# El archivo de Windows es un .exe que se descomprime solo (7-Zip). Windows puede avisar que es un
# programa descargado de internet: viene de github.com/YosysHQ/oss-cad-suite-build.
# Si compilas con apio (hacer_bit.py), apio tiene su propia copia: actualizala con
#   apio packages update
# La version anterior queda en <Destino>.anterior por si algo deja de funcionar.
param(
    [string]$Fecha = "",
    [string]$Destino = "C:\oss-cad-suite"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"          # sin la barra, Invoke-WebRequest es mucho mas rapido

if ($Destino -match " ") { throw "La ruta '$Destino' tiene espacios: elige otra (por ejemplo C:\oss-cad-suite)" }
$api = "https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/" + $(if ($Fecha) { "tags/$Fecha" } else { "latest" })
Write-Host "Buscando OSS CAD Suite $(if ($Fecha) { $Fecha } else { '(la mas nueva)' }) para windows-x64 ..."
$rel = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "mechproj" }
$asset = $rel.assets | Where-Object { $_.name -like "oss-cad-suite-windows-x64-*.exe" } | Select-Object -First 1
if (-not $asset) { throw "No encontre oss-cad-suite-windows-x64-*.exe en $api" }

$yosysViejo = Join-Path $Destino "bin\yosys.exe"
if (Test-Path $yosysViejo) { Write-Host "Instalada ahora: $(& $yosysViejo -V)" }
Write-Host "Nueva: $($rel.tag_name) ($([math]::Round($asset.size / 1MB)) MB comprimida)"

$exe = Join-Path $env:TEMP $asset.name
Write-Host "Descargando $($asset.name) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe

$padre = Split-Path $Destino -Parent
$tmp = Join-Path $padre "oss-cad-suite-nueva"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Write-Host "Descomprimiendo en $tmp (tarda unos minutos) ..."
# -y: sin preguntas; -o<carpeta>: donde descomprimir (opciones del autoextraible de 7-Zip)
$p = Start-Process -FilePath $exe -ArgumentList @("-y", "-o$tmp") -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "El autoextraible termino con codigo $($p.ExitCode)" }
$nueva = Join-Path $tmp "oss-cad-suite"
if (-not (Test-Path (Join-Path $nueva "bin\yosys.exe"))) { throw "No aparecio $nueva\bin\yosys.exe" }

if (Test-Path $Destino) {
    $anterior = "$Destino.anterior"
    if (Test-Path $anterior) { Remove-Item $anterior -Recurse -Force }
    Rename-Item $Destino (Split-Path $anterior -Leaf)
    Write-Host "La version anterior quedo en $anterior"
}
Move-Item $nueva $Destino
Remove-Item $tmp -Recurse -Force
Remove-Item $exe -Force

Write-Host ""
Write-Host "LISTO: OSS CAD Suite $($rel.tag_name) en $Destino"
foreach ($c in @(@("yosys", "-V"), @("iverilog", "-V"), @("openFPGALoader", "--Version"))) {
    $bin = Join-Path $Destino ("bin\" + $c[0] + ".exe")
    if (Test-Path $bin) { Write-Host ("  {0,-15} {1}" -f $c[0], ((& $bin $c[1] 2>&1 | Select-Object -First 1) -join "")) }
}
Write-Host ""
Write-Host "Para usarla en esta terminal:  . $Destino\environment.ps1"
Write-Host "Probar el repo:                python tools\correr_pruebas.py --sintesis"
