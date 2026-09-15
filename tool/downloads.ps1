<#
    tool\downloads.ps1 - عدّاد تنزيلات إصدارات GitHub

    يطبع كم مرة نُزّل كل ملف APK، ويحفظ سطراً مؤرَّخاً في ملف تاريخ
    ليظهر الفرق عن آخر مرة شُغِّل فيها. الاتجاه أهم من الرقم نفسه.

    أمثلة:
      tool\downloads.ps1                 # اطبع واحفظ
      tool\downloads.ps1 -NoSave         # اطبع بلا حفظ
      tool\downloads.ps1 -History        # اعرض كل ما حُفظ سابقاً

    عدد التنزيلات عام لا يحتاج تسجيل دخول. أرقام الزوار تحتاج `gh`
    مسجَّل الدخول بحساب المالك، وتُترك فارغة إن لم يتوفر.
#>
[CmdletBinding()]
param(
    [string] $Repo = 'sagheerys/metube-mobile',
    [string] $HistoryPath = 'Y:\MTF-Backup\stats\downloads.csv',
    [switch] $NoSave,
    [switch] $History
)

$ErrorActionPreference = 'Stop'
# ويندوز 11 يفاوض TLS 1.2 تلقائياً، وهذا السطر يحمي من إعداد نظام قديم.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Releases {
    param([string] $Repo)
    $headers = @{ 'User-Agent' = 'mtf-downloads'; 'Accept' = 'application/vnd.github+json' }
    try {
        return Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers $headers
    } catch {
        throw "تعذّر الوصول إلى GitHub: $($_.Exception.Message)"
    }
}

function Get-Traffic {
    param([string] $Repo)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $null }
    try {
        $viewsJson = & gh api "repos/$Repo/traffic/views" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $viewsJson) { return $null }
        $views = $viewsJson | ConvertFrom-Json
        $clones = $null
        $clonesJson = & gh api "repos/$Repo/traffic/clones" 2>$null
        if ($LASTEXITCODE -eq 0 -and $clonesJson) { $clones = $clonesJson | ConvertFrom-Json }
        return [pscustomobject]@{
            Views        = $views.count
            Uniques      = $views.uniques
            Clones       = if ($clones) { $clones.count } else { '' }
            CloneUniques = if ($clones) { $clones.uniques } else { '' }
        }
    } catch { return $null }
}

if ($History) {
    if (-not (Test-Path $HistoryPath)) { Write-Host "لا يوجد تاريخ محفوظ بعد: $HistoryPath"; return }
    Import-Csv $HistoryPath | Format-Table -AutoSize
    return
}

$releases = Get-Releases -Repo $Repo
if (-not $releases) { Write-Host "لا توجد إصدارات في $Repo"; return }

$total = 0; $lite = 0; $super = 0
$latestTag = ''; $latestTotal = 0

Write-Host ""
Write-Host "تنزيلات $Repo" -ForegroundColor Cyan
Write-Host ("-" * 52)

foreach ($release in $releases) {
    $assets = @($release.assets)
    if ($assets.Count -eq 0) { continue }
    $releaseTotal = 0
    Write-Host ""
    Write-Host ("{0}  ({1})" -f $release.tag_name, $release.published_at.Substring(0, 10)) -ForegroundColor Yellow
    foreach ($asset in $assets) {
        $count = [int] $asset.download_count
        Write-Host ("   {0,-32} {1,6}" -f $asset.name, $count)
        $releaseTotal += $count
        $total += $count
        if ($asset.name -match 'Lite') { $lite += $count }
        if ($asset.name -match 'Super') { $super += $count }
    }
    if (-not $latestTag) { $latestTag = $release.tag_name; $latestTotal = $releaseTotal }
}

$traffic = Get-Traffic -Repo $Repo

Write-Host ""
Write-Host ("-" * 52)
Write-Host ("المجموع الكلي: {0}   (Lite {1} · Super {2})" -f $total, $lite, $super) -ForegroundColor Green
Write-Host ("آخر إصدار {0}: {1}" -f $latestTag, $latestTotal)
if ($traffic) {
    Write-Host ("زوار آخر 14 يوماً: {0} زيارة · {1} زائراً مختلفاً" -f $traffic.Views, $traffic.Uniques)
} else {
    Write-Host "أرقام الزوار غير متاحة (يلزم gh مسجَّل الدخول)." -ForegroundColor DarkGray
}

if ($NoSave) { Write-Host ""; return }

# الحفظ: سطر واحد لكل تشغيل، والفرق يُقاس عن آخر سطر محفوظ.
$previous = $null
if (Test-Path $HistoryPath) {
    $rows = @(Import-Csv $HistoryPath)
    if ($rows.Count -gt 0) { $previous = $rows[-1] }
} else {
    $folder = Split-Path $HistoryPath -Parent
    if ($folder -and -not (Test-Path $folder)) { New-Item -ItemType Directory -Force $folder | Out-Null }
}

$row = [pscustomobject]@{
    date         = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    total        = $total
    lite         = $lite
    super        = $super
    latest_tag   = $latestTag
    latest_total = $latestTotal
    views_14d    = if ($traffic) { $traffic.Views } else { '' }
    uniques_14d  = if ($traffic) { $traffic.Uniques } else { '' }
    clones_14d   = if ($traffic) { $traffic.Clones } else { '' }
}
$row | Export-Csv -Path $HistoryPath -NoTypeInformation -Append -Encoding UTF8

Write-Host ""
if ($previous) {
    $delta = $total - [int] $previous.total
    $sign = if ($delta -gt 0) { "+$delta" } else { "$delta" }
    Write-Host ("منذ آخر قياس ({0}): {1} تنزيلاً" -f $previous.date, $sign) -ForegroundColor Cyan
} else {
    Write-Host "هذا أول قياس محفوظ - شغّل السكربت أسبوعياً ليظهر الاتجاه." -ForegroundColor Cyan
}
Write-Host ("التاريخ في: {0}" -f $HistoryPath) -ForegroundColor DarkGray
Write-Host ""
