Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]$SourceDirectory
)

$ErrorActionPreference = "Stop"

# Python release download URLs can be found here: https://github.com/kennethreitz/requests/releases
#$PythonRequestsVersion = "master"
$PythonRequestsVersion = "v2.13.0"

$PythonRequestsUrl = "https://github.com/kennethreitz/requests/archive/$PythonRequestsVersion.zip"
$PythonArchiveId = ($PythonRequestsUrl -replace 'https://github.com/(\w+/)+(.+)','$2').TrimStart("v").TrimEnd(".zip")

$PythonipaddressVersion = "v1.0.18"

$PythonipaddressUrl = "https://github.com/phihag/ipaddress/archive/$PythonipaddressVersion.zip"
$PythonipaddressArchiveId = ($PythonipaddressUrl -replace 'https://github.com/(\w+/)+(.+)','$2').TrimStart("v").TrimEnd(".zip")

$PythonrequesttoolbeltUrl = "https://github.com/requests/toolbelt/archive/0.9.1.zip"
$PythonrequesttoolbeltArchiveId = ($PythonrequesttoolbeltUrl -replace 'https://github.com/(\w+/)+(.+)','$2').TrimStart("v").TrimEnd(".zip")



if (-not (Test-Path -PathType Container $SourceDirectory))
{
    throw "Directory '$SourceDirectory' does not exist!"
}

$SourceDirectory = (Resolve-Path $SourceDirectory).ToString().TrimEnd("\")

Add-Type -ReferencedAssemblies System.IO,System.IO.Compression @"
using System;
using System.IO;
using System.IO.Compression;

namespace Ex
{
    public static class ZipArchiveEx
    {
        public static void RenameEntry(ZipArchive archive, string oldName, string newName)
        {
            ZipArchiveEntry oldEntry = archive.GetEntry(oldName),
                newEntry = archive.CreateEntry(newName);

            using (Stream oldStream = oldEntry.Open())
            using (Stream newStream = newEntry.Open())
            {
                oldStream.CopyTo(newStream);
            }

            oldEntry.Delete();
        }
    }
}
"@

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Fetching and preparing the requests module ($PythonArchiveId)..."
Invoke-WebRequest $PythonRequestsUrl -OutFile "$SourceDirectory\requests-$PythonArchiveId.zip"
Write-Host "Fetching and preparing the ipaddress module ($PythonipaddressArchiveId)..."
Invoke-WebRequest $PythonipaddressUrl -OutFile "$SourceDirectory\ipaddress-$PythonipaddressArchiveId.zip"
Write-Host "Fetching and preparing the requests_toolbelt module ($PythonrequesttoolbeltArchiveId)..."
Invoke-WebRequest $PythonrequesttoolbeltUrl -OutFile "$SourceDirectory\toolbelt-$PythonrequesttoolbeltArchiveId.zip"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]

Remove-Item -Recurse -Force "$SourceDirectory\requests-$PythonArchiveId" -EA SilentlyContinue
$zip::ExtractToDirectory("$SourceDirectory\requests-$PythonArchiveId.zip", $SourceDirectory)
Remove-Item -Recurse -Force "$SourceDirectory\requests"  -EA SilentlyContinue
Move-Item "$SourceDirectory\requests-$PythonArchiveId\requests" "$SourceDirectory\"
Remove-Item -Recurse -Force "$SourceDirectory\requests-$PythonArchiveId*"  -EA SilentlyContinue

Remove-Item -Recurse -Force "$SourceDirectory\ipaddress-$PythonipaddressArchiveId" -EA SilentlyContinue
$zip::ExtractToDirectory("$SourceDirectory\ipaddress-$PythonipaddressArchiveId.zip", $SourceDirectory)
Remove-Item -Recurse -Force "$SourceDirectory\ipaddress.py"  -EA SilentlyContinue
Copy-Item "$SourceDirectory\ipaddress-$PythonipaddressArchiveId/ipaddress.py" "$SourceDirectory"
Remove-Item -Recurse -Force "$SourceDirectory\ipaddress-$PythonipaddressArchiveId*"  -EA SilentlyContinue

Remove-Item -Recurse -Force "$SourceDirectory\toolbelt-$PythonrequesttoolbeltArchiveId" -EA SilentlyContinue
$zip::ExtractToDirectory("$SourceDirectory\toolbelt-$PythonrequesttoolbeltArchiveId.zip", $SourceDirectory)
Remove-Item -Recurse -Force "$SourceDirectory\toolbelt"  -EA SilentlyContinue
Move-Item "$SourceDirectory\toolbelt-$PythonrequesttoolbeltArchiveId\requests_toolbelt" "$SourceDirectory\"
Remove-Item -Recurse -Force "$SourceDirectory\toolbelt-$PythonrequesttoolbeltArchiveId*"  -EA SilentlyContinue

$ZipFileName = "$SourceDirectory" + ".zip"
Write-Host "Creating ZIP of plugin at $ZipFileName..."

if (Test-Path $ZipFileName)
{
    Remove-Item -Force $ZipFileName
}

$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
$zip::CreateFromDirectory($SourceDirectory, $ZipFileName, $CompressionLevel, $false)

# Swap default slashes
$archive = $zip::Open($ZipFileName, [System.IO.Compression.ZipArchiveMode]::Update)
$filenames = ($archive.Entries | ?{ $_.FullName -match '(\w+\\)+\w+' }).FullName
$count = $filenames.Count
$i = 1
$filenames | %{
    $old = $_
    $new = $old -replace '\\','/'
    Write-Progress -Activity "Rewriting Windows Paths in ZIP" -Status "Rewriting $old to $new" -PercentComplete ($i / $count * 95)
    [Ex.ZipArchiveEx]::RenameEntry($archive, $old, $new)
    $i += 1
}
$archive.Dispose()
$archive = $null

# Add directory entries
$archive = $zip::Open($ZipFileName, [System.IO.Compression.ZipArchiveMode]::Update)
$directories = ($archive.Entries | ?{ $_.FullName -match '(\w+/)+\w+' }).FullName -replace '((\w+/)+)\w+\.\w+', '$1' | unique
$directories | %{
    Write-Progress -Activity "Rewriting Windows Paths in ZIP" -Status "Adding $_ directory" -PercentComplete 97
    $archive.CreateEntry($_, $CompressionLevel) | Out-Null
}
Write-Progress -Activity "Rewriting Windows Paths in ZIP" -PercentComplete 100
$archive.Dispose()
$archive = $null

Remove-Item -Recurse -Force "$SourceDirectory\requests"
Remove-Item -Recurse -Force "$SourceDirectory\ipaddress.py"
Remove-Item -Recurse -Force "$SourceDirectory\requests_toolbelt"
