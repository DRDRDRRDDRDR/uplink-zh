# Uplink 1.5.5 简体中文补丁安装 / 回滚 / 校验（PowerShell 5.1+）
param(
    [ValidateSet('install','rollback','verify')]
    [string]$Action='install',
    [string]$GameDir='C:\Program Files (x86)\Steam\steamapps\common\Uplink'
)
$ErrorActionPreference='Stop'
$Here=Split-Path -Parent $MyInvocation.MyCommand.Path
$Backup=Join-Path $GameDir '_zh_backup'
$ManifestPath=Join-Path $Backup 'manifest.json'
$Files=@(
    [pscustomobject]@{Name='Uplink.exe';Sha='45A4C3D205331896DBA7D2168441AD461BCE4EA902D5F28DD6BE0AD1F8941CA3'},
    [pscustomobject]@{Name='fonts.dat';Sha='657A164775A46CBD6F9A04FD766BCC495A8FEB841AC09420D362920E0694998A'}
)
function Get-Sha256([string]$p) {(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
function Leaf([string]$p) {if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {throw "缺少文件：$p"}; if ((Get-Item -LiteralPath $p).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "拒绝重解析路径：$p"}}
function Plain([string]$p) {$p=[IO.Path]::GetFullPath($p); while ($p) {$item=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw "拒绝重解析路径：$p"}; $next=Split-Path -Parent $p; if ($next -eq $p) {break}; $p=$next}}
$GameDir=[IO.Path]::GetFullPath($GameDir)

switch ($Action) {
'install' {
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {throw "找不到游戏目录：$GameDir"}
    Plain $GameDir; Plain $Backup
    foreach ($f in $Files) {Leaf (Join-Path $Here $f.Name); Leaf (Join-Path $GameDir $f.Name); if ((Get-Sha256 (Join-Path $Here $f.Name)) -ne $f.Sha) {throw "补丁工件哈希不匹配：$($f.Name)"}; if ([IO.Path]::GetFullPath($Here) -eq $GameDir) {throw '补丁包目录不能作为游戏目录'}}
    if (Test-Path -LiteralPath $ManifestPath) {
        Leaf $ManifestPath; $m=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        if ($m.Version -ne 1 -or @($m.Files).Count -ne 2) {throw '安装清单无效'}
        foreach ($f in $Files) {$r=@($m.Files | Where-Object {$_.Name -ceq $f.Name}); if ($r.Count -ne 1 -or (Get-Sha256 (Join-Path $Backup ($f.Name+'.orig'))) -ne $r[0].OriginalSha -or (Get-Sha256 (Join-Path $GameDir $f.Name)) -ne $f.Sha) {throw '现有安装不匹配，未修改文件'} }
        Write-Host '中文版已安装且校验通过。'; break
    }
    if (Test-Path -LiteralPath $Backup) {throw "存在无清单备份目录，拒绝覆盖：$Backup"}
    New-Item -ItemType Directory -Path $Backup | Out-Null
    $records=@(); $changed=@()
    try {
        foreach ($f in $Files) {$dst=Join-Path $GameDir $f.Name; $bak=Join-Path $Backup ($f.Name+'.orig'); Copy-Item -LiteralPath $dst -Destination $bak; if ((Get-Sha256 $dst) -ne (Get-Sha256 $bak)) {throw "备份校验失败：$($f.Name)"}; $records += [pscustomobject]@{Name=$f.Name;OriginalSha=(Get-Sha256 $bak);PatchSha=$f.Sha}}
        [pscustomobject]@{Version=1;Files=$records} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
        foreach ($f in $Files) {$dst=Join-Path $GameDir $f.Name; $changed += $f.Name; Copy-Item -LiteralPath (Join-Path $Here $f.Name) -Destination $dst -Force; if ((Get-Sha256 $dst) -ne $f.Sha) {throw "安装校验失败：$($f.Name)"}}
        Write-Host '安装完成，原版备份与校验清单已保留。'
    } catch {
        $failure=$_; $errors=@()
        foreach ($name in $changed) {try {$bak=Join-Path $Backup ($name+'.orig'); Copy-Item -LiteralPath $bak -Destination (Join-Path $GameDir $name) -Force; if ((Get-Sha256 (Join-Path $GameDir $name)) -ne (Get-Sha256 $bak)) {throw '恢复校验失败'}} catch {$errors += "$name : $_"}}
        if ($errors.Count) {throw "安装失败且回滚未完成：$($errors -join '; ')。备份保留。原错误：$failure"}
        throw "安装失败，已还原已修改目标；备份保留。原错误：$failure"
    }
}
'rollback' {
    Leaf $ManifestPath; $m=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($m.Version -ne 1 -or @($m.Files).Count -ne 2) {throw '安装清单无效'}
    Plain $GameDir; Plain $Backup; Plain $ManifestPath
    foreach ($f in $Files) {if (@($m.Files | Where-Object {$_.Name -ceq $f.Name}).Count -ne 1) {throw '清单文件名或重复记录无效'}}
    foreach ($r in $m.Files) {if ($r.Name -cnotin @('Uplink.exe','fonts.dat')) {throw '清单文件名无效'}; Plain (Join-Path $Backup ($r.Name+'.orig')); Plain (Join-Path $GameDir $r.Name); if ($r.OriginalSha -notmatch '^[A-Fa-f0-9]{64}$' -or $r.PatchSha -notmatch '^[A-Fa-f0-9]{64}$') {throw '清单哈希无效'}; $bak=Join-Path $Backup ($r.Name+'.orig'); $dst=Join-Path $GameDir $r.Name; Leaf $bak; Leaf $dst; if ((Get-Sha256 $bak) -ne $r.OriginalSha) {throw "备份已变化：$($r.Name)"}; $h=Get-Sha256 $dst; if ($h -ne $r.PatchSha -and $h -ne $r.OriginalSha) {throw "目标不属于本安装器，拒绝覆盖：$($r.Name)"}}
    foreach ($r in $m.Files) {if ($r.Name -notin @('Uplink.exe','fonts.dat')) {throw "清单文件名无效：$($r.Name)"}; $dst=Join-Path $GameDir $r.Name; Copy-Item -LiteralPath (Join-Path $Backup ($r.Name+'.orig')) -Destination $dst -Force; if ((Get-Sha256 $dst) -ne $r.OriginalSha) {throw "还原失败；清单与备份保留以供重试：$($r.Name)"}}
    Write-Host '已还原原版并完成校验。'
}
'verify' {
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {throw "找不到游戏目录：$GameDir"}
    $valid=$true
    foreach ($f in $Files) {$dst=Join-Path $GameDir $f.Name; if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) {Write-Host "$($f.Name)：文件缺失"; $valid=$false} elseif ((Get-Sha256 $dst) -eq $f.Sha) {Write-Host "$($f.Name)：中文版哈希匹配"} else {Write-Host "$($f.Name)：哈希不匹配"; $valid=$false}}
    if (-not $valid) {exit 1}
}
}
