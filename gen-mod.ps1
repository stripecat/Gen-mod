
#requires -version 3
<#
.SYNOPSIS
  Generates .flac-files from all modules that OpenMPT123.exe can handle.
.DESCRIPTION
  Takes any support tracked music files and generates new audio files from them.
.PARAMETER <Parameter_Name>
    None
.INPUTS
  None
.OUTPUTS
  Stdout
.NOTES
  Version:        1.0
  Author:         Erik Zalitis
  Creation Date:  2022-09-21
  Latest update:  2022-09-21
  Purpose/Change: Initial release.
  
.EXAMPLE
  gen-mod
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$tracklist = ""

$tracklist = @()

$tsf = Get-Date -Format "yyyy-MM-dd-HHmmss"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ingress = "D:\Projekt\Tools\OpenMPT\Ingress\" # We to get the modules.

$Basepath = "D:\Projekt\Tools\OpenMPT\"

$ProcessPath = $Basepath + "Process\"

$LogDir = $Basepath + "Logdir\" # Where to store the logs.

$catdip = "D:\Projekt\Tools\OpenMPT\Process\Catdip\" # Store the file where Thimeo WatchCat will find it.

$destinationpath = "D:\Projekt\Tools\OpenMPT\Ingress\" # The base path, where a new subfolder will be created.

$ErrorActionPreference = "stop"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Logwrite ($message, $todisk = 1, $LD = $LogDir, $tsf = $tsf) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    write-host ("[" + $ts + "] " + $message)
  
    $file = $LD + $tsf + "_Log.txt"
  
    if ($todisk -eq 1) { ("[" + $ts + "] " + $message) | out-file $file -append }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Set-Location $ProcessPath

# Figure out the new subfolder to create

$subfolderstem = "TERN-"
$subfolderstem = ($subfolderstem + (Get-date -uformat %b%Y).ToLower() + "-") 

$lastrepo = $null

$lastrepo = (Get-ChildItem $ingress -Filter ("*" + $subfolderstem + "*") | Sort-Object { $_.Name } -Descending)[0].Name.tostring()

try {

    if ($null -eq $lastrepo) {
        logwrite("This month has no previous batches.")
        $incrementalnumber = "01"
        $subfolder = $subfolderstem + $incrementalnumber
    }
    else {
    
        $rc = $lastrepo -imatch "([^\-])$";
        [int]$incrementalnumber = $matches[0]
        $subfolder = $subfolderstem + "0" + ($incrementalnumber + 1)
        logwrite("Last batch for this month was " + $lastrepo + ". Next will be " + $subfolder + ".")
    
    }

    if (test-path ($ingress + $subfolder)) {
        logwrite("The destination folder exists. This should not have happened, yet here we are.")
        exit
    }
    else { 
        $rc = New-Item (($ingress + $subfolder)) -ItemType "directory"
        $rc = New-Item (($ingress + $subfolder) + "/selected/") -ItemType "directory"
    }
}
catch {
    logwrite("[Error] Unable to find the proper foldername. Please investigate. Given EC: " + $_)
    exit
}

$im = 0
$dirs = get-childitem $ingress -File
$total = $dirs.count


foreach ($mod in $dirs) {

    $im++
    $pct = ($im / $total) * 100


    Logwrite("->" + $im + "/" + $total + "(" + [math]::Round($pct, 2) + ") Processing " + $mod.Name + ".")


    $sourcepath = ("`"" + $ingress + $mod.Name + "`"")

    $ErrorActionPreference = "stop"

    If (Test-Path ($catdip + "Ready\" + $mod.Name + ".flac")) { Remove-item ($catdip + "Ready\" + $mod.Name + ".flac") -Confirm:$false -Force } 
    If (Test-Path ($catdip + "Processed\" + $mod.Name + ".flac")) { Remove-item ($catdip + "Processed\" + $mod.Name + ".flac") -Confirm:$false -Force } 

    if ($mod.Name -ilike "*.mod") {
        logwrite("Amiga module detected. Pushing to mono")
        $trackdata = (..\openmpt123.exe --info -v --stereo 0 --render $sourcepath --force --output-type flac)
    }
    else {
        $trackdata = (..\openmpt123.exe --info -v --render $sourcepath --force --output-type flac)
    }

    $Album = "OriginalName: " + $mod.Name + " Imported: " + (get-date -uformat %Y-%m-%d) + " (" + $subfolder + ")."
    $Title = $trackdata -match '^Title[^\:]*..(.*)'
    $Title = $Title.split(':')[1].trim()
    $Artist = "Trackerartist"

    $fail = 0

    # Fullartist, Title, Metadata, LengthHR, AddedToStation



        
    $cmd = "..\ffmpeg.exe -i " + ($sourcepath + ".flac") + " -metadata title=`"$Title`" -metadata artist=`"$Artist`" -metadata album=`"$Album`" " + ("`"" + $catdip + $mod.Name + ".flac" + "`"")
        
    try {
        cmd /c $cmd
    }
    catch {
        # This may seem dumb, and you're right, it is. 
        # ffmpeg thinks it brilliant to send progressdata down the stderr output.
        # Really not the smartest thing to do.
        # Powershell compounds the problem by only keep the first line in $_. Good luck parsing, when
        # you only get ffmpeg and the versionnumber.
    }


    # Wait for the tune to go through the catdip
    # The correct term is sheepdip, as in a sanitization-process to remove bad stuff 
    # from files. Thimeo's product for audio levelling is called WatchCat. So... It's my kinda humor.

    $count = 0
    $maxTries = 20
    $catprocessed = $false
      
    logwrite ("Waiting for Thimeo Watchcat to process this file")

    do {

        
    
        If (Test-Path ($catdip + "Ready\" + $mod.Name + ".flac")) {
            $count = $maxTries
            $catprocessed = $true

        }
        Else {
            logwrite ("... Here kitty, kitty, kitty.")
            If ($count -lt ($maxTries - 1)) {
                Start-Sleep -Seconds 2
            }
            $count++

        }

    } While ($count -lt $maxTries)

    if ($catprocessed -eq $true) {
        logwrite("The file was succesfully processed by Watchcat")
    }
    else {
        logwrite("The moggie fell asleep again.")
        $fail = 1
        $tracklist = $tracklist + [PSCustomObject]@{Artist = $Artist; Title = $Title; Album = $Album; track = $orginname; failed = $fail; }
        continue

    }

        $tracklist = $tracklist + [PSCustomObject]@{Artist = $Artist; Title = $Title; Album = $Album; track = $orginname; failed = $fail; }

    if (test-path(($ingress + $mod.Name + ".flac"))) { Remove-Item ($ingress + $mod.Name + ".flac") -Confirm:$false -Force }

     $readymap=("`"" + $catdip + "Ready\" + $mod.Name + ".flac" + "`"")
     $readymap2=($catdip + "Ready\" + $mod.Name + ".flac")
     $sp=$ingress + $mod.Name

    try {
        
        Start-sleep 2
        Move-Item -LiteralPath $readymap2 ($ingress + $subfolder + "\selected\") -Force -Confirm:$false
        Move-Item -LiteralPath $sp  (($ingress + $subfolder)) -Force -Confirm:$false

        $fail = 0
    }
    catch {
        Logwrite(("[ERROR] Couldn't move " + $readymap2 + " to " + $destinationpath + ". Reason: " + $_ + "."))
        $fail = 1
    } 
  
}


logwrite ("The process is now done. Saving the processed track to a CSV")
$tracklist | export-csv -path ($ProcessPath + "tracklist-" + $subfolder + ".csv") -delimiter ";" -encoding utf8 -NoTypeInformation