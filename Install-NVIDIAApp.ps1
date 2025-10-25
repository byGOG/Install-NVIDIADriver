<#
.SYNOPSIS
    NVIDIA App'i dinamik olarak indirip sessiz kuran PowerShell betiği.

.DESCRIPTION
    En güncel NVIDIA App indirme bağlantısını resmi NVIDIA sayfasından (nvidia.com) 
    dinamik olarak tespit eder, tercihen TR aynasından (tr.download.nvidia.com) indirir
    ve sessiz kurulum gerçekleştirir. Sürüm numarası otomatik bulunur.

.PARAMETER OutDir
    Kurulum dosyasının indirileceği klasör. Varsayılan: $env:TEMP

.PARAMETER SilentArgs
    Sessiz kurulum için argümanlar. Varsayılan: '/S' (NSIS uyumlu). Gerekirse değiştirin.

.PARAMETER Locale
    İndirme bağlantısını çıkarırken kullanılacak sayfa yereli. Varsayılan: 'tr-tr'.
    Fallback olarak 'en-us' denenir.

.PARAMETER ForceUsMirror
    TR aynası yerine orijinal bulduğu alan adını (örn. us.download.nvidia.com) zorla kullanır.

.PARAMETER DownloadOnly
    Sadece indirir, kurulum yapmaz.

.EXAMPLE
    ./Install-NVIDIAApp.ps1

.EXAMPLE
    ./Install-NVIDIAApp.ps1 -OutDir 'C:\Kurulumlar' -SilentArgs '/S' -Locale 'tr-tr'

.NOTES
    - Betik yönetici olarak çalıştırılmasa dahi kurulum aşamasında UAC yükseltmesi istenebilir.
    - Sessiz kurulum argümanı paketleyiciye göre değişebilir. Varsayılan olarak '/S' kullanılır.
#>

[CmdletBinding()]
param(
    [Parameter()][string]$OutDir = $env:TEMP,
    [Parameter()][string]$SilentArgs = '/S',
    [Parameter()][string]$Locale = 'tr-tr',
    [Parameter()][switch]$ForceUsMirror,
    [Parameter()][switch]$DownloadOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Warning $Message
}

function Get-LatestNvidiaAppLink {
    param(
        [Parameter(Mandatory)][string]$Locale
    )

    # NVIDIA App ürün sayfasından .exe indirme bağlantısını çıkar.
    $pages = @(
        "https://www.nvidia.com/$Locale/software/nvidia-app/",
        'https://www.nvidia.com/en-us/software/nvidia-app/'
    )

    # Regex: .../nvapp/client/<version>/NVIDIA_app_v<version>.exe
    $pattern = 'https?://[^"''\s]+/nvapp/client/([0-9\.]+)/NVIDIA_app_v[0-9\.]+\.exe'

    foreach ($page in $pages) {
        try {
            Write-Info "Sayfa aranıyor: $page"
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $page -TimeoutSec 40
            $matches = [regex]::Matches($resp.Content, $pattern)
            if ($matches.Count -gt 0) {
                # İlk benzersiz eşleşmeyi al
                $link = ($matches | ForEach-Object { $_.Value } | Select-Object -Unique | Select-Object -First 1)
                # Sürümü yakala
                $verMatch = [regex]::Match($link, '/nvapp/client/([0-9\.]+)/')
                $version = if ($verMatch.Success) { $verMatch.Groups[1].Value } else { '' }
                if ([string]::IsNullOrWhiteSpace($version)) {
                    throw "Sürüm numarası çıkarılamadı."
                }
                return [pscustomobject]@{
                    Page     = $page
                    Url      = $link
                    Version  = $version
                    FileName = "NVIDIA_app_v$version.exe"
                }
            }
        }
        catch {
            Write-Warn "Sayfa okunamadı: $page -> $($_.Exception.Message)"
        }
    }

    throw "NVIDIA App indirme bağlantısı bulunamadı."
}

function Select-MirrorUrl {
    param(
        [Parameter(Mandatory)][string]$OriginalUrl,
        [Parameter(Mandatory)][string]$PreferredHost # örn. 'tr.download.nvidia.com'
    )

    try {
        $u = [Uri]$OriginalUrl
        $trUrl = "https://$PreferredHost$($u.AbsolutePath)"

        # TR aynasında HEAD kontrolü
        try {
            $head = Invoke-WebRequest -UseBasicParsing -Method Head -Uri $trUrl -TimeoutSec 20 -ErrorAction Stop
            if ($head.StatusCode -eq 200) {
                return $trUrl
            }
        }
        catch {
            Write-Warn "TR aynası doğrulanamadı, orijinal bağlantı kullanılacak. ($($_.Exception.Message))"
        }

        return $OriginalUrl
    }
    catch {
        Write-Warn "Ayna seçimi başarısız: $($_.Exception.Message)"
        return $OriginalUrl
    }
}

function Download-File {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath (Split-Path -Parent $Destination))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    }

    Write-Info "İndiriliyor: $Url"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination -TimeoutSec 180
    Write-Info "İndirildi: $Destination"
}

function Install-Silently {
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string]$Args
    )

    Write-Info "Sessiz kurulum başlatılıyor..."
    $p = Start-Process -FilePath $InstallerPath -ArgumentList $Args -Wait -PassThru -WindowStyle Hidden
    $code = $p.ExitCode
    Write-Info "Kurulum çıkış kodu: $code"
    if ($code -ne 0) {
        Write-Warn "Kurulum başarı kodu dışı çıktı. Gerekirse -SilentArgs ile farklı parametre deneyin."
    }
}

# TLS 1.2 güvence altına al
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

try {
    $info = Get-LatestNvidiaAppLink -Locale $Locale
    Write-Info "Bulunan sürüm: $($info.Version)"

    $finalUrl = if ($ForceUsMirror) {
        $info.Url
    } else {
        Select-MirrorUrl -OriginalUrl $info.Url -PreferredHost 'tr.download.nvidia.com'
    }
    Write-Info "İndirme URL: $finalUrl"

    $dest = Join-Path $OutDir $info.FileName

    if (-not (Test-Path -LiteralPath $dest)) {
        Download-File -Url $finalUrl -Destination $dest
    } else {
        Write-Info "Dosya zaten mevcut: $dest"
    }

    if (-not $DownloadOnly) {
        Install-Silently -InstallerPath $dest -Args $SilentArgs
    } else {
        Write-Info "DownloadOnly seçildi, kurulum atlandı."
    }
}
catch {
    Write-Error $_
    exit 1
}

