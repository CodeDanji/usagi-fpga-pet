param(
    [ValidateSet('inspect','setup','build','implement','simulate','hardware')][string]$Action='setup',
    [string]$Vivado='C:\Xilinx\Vivado\2024.2\bin\vivado.bat'
)
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mappedDrive=$null
foreach($letter in @('U','V','W','X','Y','Z')) {
    if(!(Test-Path "${letter}:\")) {
        & subst "${letter}:" $workspace
        if($LASTEXITCODE -eq 0) {$mappedDrive=$letter;break}
    }
}
if(!$mappedDrive) {throw 'No free temporary drive letter'}
Push-Location "${mappedDrive}:\"
try {
    $script=if($Action -eq 'inspect') {'inspect_pins.tcl'} elseif($Action -eq 'hardware') {'check_hardware.tcl'} else {'project.tcl'}
    & $Vivado -mode batch -log "board/results/${Action}.log" -journal "board/results/${Action}.jou" -source "scripts/$script" -tclargs $Action
    if($LASTEXITCODE) {throw "Vivado $Action failed"}
    $log=Get-Content -LiteralPath "board/results/${Action}.log" -Raw
    if($log -match '(?m)^\s*(ERROR:|Fatal:|FATAL_ERROR:)') {throw "Vivado $Action log reports failure"}
    $marker=if($Action -eq 'inspect') {'PIN INSPECTION COMPLETE'} elseif($Action -eq 'hardware') {'HARDWARE CHECK PASSED'} else {"BOARD $($Action.ToUpper()) COMPLETE"}
    if(!$log.Contains($marker)) {throw "Vivado $Action did not complete"}
} finally {
    Pop-Location
    # Keep the project header portable after the temporary alias disappears.
    $projectPath=Join-Path $workspace 'final.xpr'
    if(Test-Path -LiteralPath $projectPath) {
        $xml=[IO.File]::ReadAllText($projectPath)
        $canonical=($workspace.Replace('\','/'))+'/final.xpr'
        $portableXml=$xml.Replace("Path=`"${mappedDrive}:/final.xpr`"","Path=`"$canonical`"")
        if($portableXml -ne $xml) {[IO.File]::WriteAllText($projectPath,$portableXml,[Text.UTF8Encoding]::new($false))}
    }
    & subst "${mappedDrive}:" /d
}
