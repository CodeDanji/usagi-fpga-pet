param(
    [ValidateSet('all','card','display','conditioning','board','camera','synth-card','synth-conditioning')]
    [string]$Task='all',
    [string]$Vivado='C:\Xilinx\Vivado\2024.2\bin\vivado.bat',
    [string]$Python='C:\Users\sodas\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
)
$ErrorActionPreference='Stop'
$experimentRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspaceRoot=(Resolve-Path (Join-Path $experimentRoot '..')).Path
if (!(Test-Path -LiteralPath $Vivado)) { throw "Vivado not found: $Vivado" }
if (!(Test-Path -LiteralPath $Python)) { throw 'Pass -Python with a Python 3 executable.' }
# Vivado 2024.2 Tcl on this host drops hidden directory components from pwd.
# Map ONLY this workspace, without changing directory attributes or installation.
$taskDrive=$null
foreach($letter in @('U','V','W','X','Y','Z')) {
    if (!(Test-Path "${letter}:\")) {
        & subst "${letter}:" $workspaceRoot
        if($LASTEXITCODE -eq 0) { $taskDrive=$letter; break }
    }
}
if (!$taskDrive) { throw 'No free temporary drive letter.' }
Push-Location "${taskDrive}:\"
try {
    if (!(Test-Path final.srcs/sources_1/rom/usagi_128x128.mem)) {
        & $Python -X utf8 experiments/assets/generate_sprite.py
        if($LASTEXITCODE) { throw 'Sprite generation failed' }
    }
    if($Task -in @('all','conditioning')) {
        & $Python -X utf8 experiments/model/reference.py
        if($LASTEXITCODE) { throw 'Reference model failed' }
    }
    $jobs=if($Task -eq 'all') {@('camera','board','card','display','conditioning','synth-card','synth-conditioning')} else {@($Task)}
    foreach($job in $jobs) {
        $synthesis=$job.StartsWith('synth-')
        $name=if($synthesis) {$job.Substring(6)} else {$job}
        $script=if($synthesis) {'synthesize.tcl'} else {'run_sim.tcl'}
        $log="experiments/results/${job}_run.log"
        & $Vivado -mode batch -log $log -journal "experiments/results/${job}_run.jou" -source "experiments/scripts/$script" -tclargs $name
        if($LASTEXITCODE) { throw "Vivado failed: $job" }
        $contents=Get-Content -LiteralPath $log -Raw
        if($contents -match '(?m)^\s*(ERROR:|FATAL_ERROR:|Fatal:)') { throw "Vivado log contains error: $log" }
        if(!$synthesis -and $contents -notmatch "PASS $name") { throw "Missing simulation success marker: $log" }
        if($synthesis -and $contents -notmatch 'Out-of-context synthesis completed;') { throw "Missing synthesis success marker: $log" }
        if($synthesis) {
            $timingReport=Get-Content -LiteralPath "experiments/results/${name}_synth_timing.rpt" -Raw
            if($timingReport -notmatch 'All user specified timing constraints are met\.') {
                throw "Pre-route timing target failed: experiments/results/${name}_synth_timing.rpt"
            }
        }
        if($job -eq 'conditioning') {
            & $Python -X utf8 experiments/model/reference.py --compare experiments/results/conditioning_rtl.csv
            if($LASTEXITCODE) { throw 'RTL/reference mismatch' }
        }
        if($job -eq 'display') {
            & $Python -X utf8 experiments/scripts/render_previews.py
            if($LASTEXITCODE) { throw 'Display preview conversion failed' }
        }
    }
} finally {
    Pop-Location
    & subst "${taskDrive}:" /d
}
