Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$seriesRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (& git -C $seriesRoot rev-parse --show-toplevel).Trim()
$source = Join-Path $repositoryRoot 'pdf\china-chronicle'
$account = 'szydownloads'
$container = 'downloads'
$destinationPath = 'books/china-chronicle'
$webContainer = '$web'
$indexBlob = 'index.html'
$temporaryIndex = Join-Path ([System.IO.Path]::GetTempPath()) 'szydownloads-index.html'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Chronicle PDF directory does not exist: $source"
}

try {
    az storage blob upload-batch `
        --account-name $account `
        --auth-mode key `
        --destination $container `
        --destination-path $destinationPath `
        --source $source `
        --overwrite `
        --content-cache-control 'no-cache' `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Blob upload failed with exit code $LASTEXITCODE."
    }

    az storage blob download `
        --account-name $account `
        --auth-mode key `
        --container-name $webContainer `
        --name $indexBlob `
        --file $temporaryIndex `
        --overwrite `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Download page retrieval failed with exit code $LASTEXITCODE."
    }

    $index = Get-Content -LiteralPath $temporaryIndex -Raw
    Get-ChildItem -LiteralPath $source -File -Filter 'vol*.pdf' | ForEach-Object {
        $url = "https://$account.blob.core.windows.net/$container/$destinationPath/$($_.Name)"
        $size = '{0:0.0}' -f ($_.Length / 1MB)
        $pattern = "(<a class=""file-card"" href=""$([regex]::Escape($url))"">[\s\S]*?<span class=""file-size"">)[^<]+(</span>)"

        $index = [regex]::Replace(
            $index,
            $pattern,
            {
                param($match)
                "$($match.Groups[1].Value)$size MB$($match.Groups[2].Value)"
            }
        )
    }

    Set-Content -LiteralPath $temporaryIndex -Value $index -Encoding utf8NoBOM
    az storage blob upload `
        --account-name $account `
        --auth-mode key `
        --container-name $webContainer `
        --name $indexBlob `
        --file $temporaryIndex `
        --overwrite `
        --content-type 'text/html; charset=utf-8' `
        --content-cache-control 'no-cache' `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Download page update failed with exit code $LASTEXITCODE."
    }

    Write-Output "Published $source to $account/$container/$destinationPath and refreshed $webContainer/$indexBlob."
}
finally {
    Remove-Item -LiteralPath $temporaryIndex -Force -ErrorAction SilentlyContinue
}
