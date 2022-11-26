
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
  Version:        1.1
  Author:         Erik Zalitis
  Creation Date:  2022-09-21
  Latest update:  2022-11-26
  Purpose/Change: Empty titles would cause script to crash.
  
.EXAMPLE
  gen-mod
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$tracklist = ""

$tracklist = @()

$tsf = Get-Date -Format "yyyy-MM-dd-HHmmss"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$Password="DEADBEEFD3ADB33F1GGGAACC45353689090" # The password for the check

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

Function Read-exists($OriginalFileName,$Password=$Password)
{

    # We will check if the song already exists on the station.
    # This is done but searching for the original file name of the file in the API.

    $StationID=1 # Hardwired as we don't push to station 2 from this script.
    $Domain = "https://api.ericade.net"
    $url = $Domain + "/radio/checkifexists/";
    $params = "{
    `"Password`": `"" + $Password + "`",
    `"StationID`": `""+ $StationID + "`",
    `"OriginalFileName`": `""+ $OriginalFileName + "`"
    }";


    try {
 
 #$url|out-file "d:\url.txt"
 
  #      $params | out-file "d:\req.txt"


        $CheckStatus = Invoke-WebRequest $url -Method Post -Body $params -UseBasicParsing -ContentType "application/json; charset=utf-8"


        $CheckStatus.Content | out-file "d:\resp.txt"

        $CallResult = ConvertFrom-Json ($CheckStatus.Content)

        if ($CallResult.subcode -eq "TRUE") { return ("[WARNING] Track appears to already exist on the station."); } else { return ("The song is new.") }


    }
    catch {
        logwrite("[ERROR] Unable to determine is the track already exists on the station. Given EC: " + $_ + ".")

    }


}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Set-Location $ProcessPath

# Figure out the new subfolder to create

$subfolderstem = "TERN-"
$subfolderstem = ($subfolderstem + (Get-date -uformat %b%Y).ToLower() + "-") 

$lastrepo = $null


$im = 0
$dirs = get-childitem $ingress -File|where-object { $_.Name -notlike '*.flac' } # Weird, huh? -Exclude has a bug. It will not work with -file.
$total = $dirs.count

if ($total -eq 0)
{
   logwrite("[Error] There seem to be no files to pick up.")
   exit 
}

try {
    $lastrepo = (Get-ChildItem $ingress -Filter ("*" + $subfolderstem + "*") | Sort-Object { $_.Name } -Descending)[0].Name.tostring()
}
catch {
    #logwrite("[Error] There seem to be no files to pick up. Given EC: " + $_ + ".")
    #exit
}

try {

    if ($null -eq $lastrepo) {
        logwrite("This month has no previous batches.")
        $incrementalnumber = "1"
        $subfolder = $subfolderstem + "0" + $incrementalnumber
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

    $re=(Read-exists $mod.Name)

    logwrite("Station validation: " + $re)


    $Album = "OriginalName: " + $mod.Name + " Imported: " + (get-date -uformat %Y-%m-%d) + " (" + $subfolder + ")."
    $Title = $trackdata -match '^Title[^\:]*..(.*)'
    
      $fail = 0
    try
    {
    if ($Title -ne "") { $Title = $Title.split(':')[1].trim() } else { $Title = "Unknown Title" }
    $Artist = "Trackerartist"
    }
    catch
    {  $fail = 1
      logwrite("[Error] Could not find title")
      $Title = "Unknown Title"
    }

  

    # Fullartist, Title, Metadata, LengthHR, AddedToStation

    $cmd = "..\ffmpeg.exe -i " + ($sourcepath + ".flac") + " -metadata title=`"$Title`" -metadata artist=`"$Artist`" -metadata album=`"$Album`" " + ("`"" + $catdip + $mod.Name + ".flac" + "`"")
        
    try {
        cmd /c ($cmd + ' > NUL 2>&1') 
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