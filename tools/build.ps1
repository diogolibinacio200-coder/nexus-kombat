param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$WindowsReleaseTemplate = '',
    [string]$Output = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
if (-not $Output) { $Output = Join-Path (Split-Path -Parent $projectRoot) 'Windows\NexusKombat.exe' }
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath) | Out-Null
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$originalPreset = [IO.File]::ReadAllText($presetPath)
try {
    if ($WindowsReleaseTemplate) {
        $templatePath = (Resolve-Path -LiteralPath $WindowsReleaseTemplate).Path.Replace('\','/')
        $customPreset = $originalPreset.Replace('custom_template/release=""', 'custom_template/release="' + $templatePath + '"')
        [IO.File]::WriteAllText($presetPath, $customPreset, [Text.UTF8Encoding]::new($false))
    }
    & $enginePath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Falha na importação do projeto.' }
    & $enginePath --headless --path $projectRoot --export-release 'Windows Desktop' $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'Falha na exportação Windows.' }
    if (-not (Test-Path -LiteralPath $outputPath)) { throw 'Executável não encontrado.' }
    Write-Host "Build criada: $outputPath"
} finally {
    [IO.File]::WriteAllText($presetPath, $originalPreset, [Text.UTF8Encoding]::new($false))
}
