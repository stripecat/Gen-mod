

#| Select-Object Artist, Title, Album, Path|Export-csv -delimiter ";" -NoTypeInformation -encoding utf8 -path modules.csv

<#

Artist : Aceman
Title  : Cold Smoke
Album  : OriginalName: aceman_-_cold_smoke.mod. Imported: 2021-08-14 (TERN-aug2021-02).
Path   : C:\ProgramData\PlayIt Live\AudioStore\79f33d6040b04eed91a9964ef7a0d138.mp3

#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$tracklist = ""

$tracklist = @()

$tsf = Get-Date -Format "yyyy-MM-dd-HHmmss"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$subfolder="TERN-Sept2022-06"

$Basepath = "D:\Projekt\Tools\OpenMPT\"

$LogDir = $Basepath + "Logdir\"

$destinationpath = "D:\Projekt\ProjectOtherTracker\"

$Basepath = "D:\Projekt\Tools\OpenMPT\"

$ProcessPath = $Basepath + "Process\"

Set-Location $Basepath

$fyha=Import-Csv -Path .\OtherFormats2.csv -encoding utf8 -Delimiter ";"
$modlist=$fyha| Select-Object Fullartist, Title, Metadata, LengthHR, AddedToStation


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Logwrite ($message, $todisk = 1, $LD = $LogDir, $tsf = $tsf) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    write-host ("[" + $ts + "] " + $message)
  
    $file = $LD + $tsf + "_Log.txt"
  
    if ($todisk -eq 1) { ("[" + $ts + "] " + $message) | out-file $file -append }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$im=0
$total=$modlist.count

foreach ($mod in $modlist)
{

$im++
$pct=($im/$total)*100


# OriginalName: aceman_-_cold_smoke.mod. Imported


$fail=0

  Logwrite("->" + $im + "/" + $total + "(" + [math]::Round($pct,2) + ") Processing " + $mod.Title + ".")

$regexp="OriginalName:[ ]*(.+?)[ ]*(?=Imported)"

$rc=$mod.Metadata -imatch $regexp

$modname=$matches[1]

if ($modname -notmatch '\.$')
{
    $orginname=$modname
}
else
{
    $orginname=$modname.Substring(0,$modname.Length-1)
}

#$orginname

Logwrite("Processing it as " + $orginname + ".")

    $ErrorActionPreference="stop"
    
    try
    {
    $file=Get-ChildItem -Path "D:\Projekt\TheERICADERadioNetwork\" -Filter $orginname -Recurse -ErrorAction SilentlyContinue -Force

    $sourcepath=$file[0].DirectoryName + "\" + $file[0].Name
    }
    catch
    {
        Logwrite("[ERROR] The file " + $orginname + " was not found.")
        Logwrite("")
        $fail=1
        continue
    }



        try
    {
    Copy-Item $sourcepath $destinationpath -Force -Confirm:$false

    }
    catch
    {
        Logwrite(("[ERROR] Couldn't copy " + $sourcepath + " to " + $destinationpath + ". Reason: " + $_ + "."))
        $fail=1
    }



        $fa=$mod.Fullartist
        $ti=$mod.Title
        #$al="OriginalName: " + $file[0].Name + " Imported: 2022-09-14 (TERN-Sept2022-04)."
        $al="OriginalName: " +  $file[0].Name + " Imported: " + (get-date -uformat %Y-%m-%d) + " (" + $subfolder + ")."
        .\openmpt123.exe --render $sourcepath --force --output-type flac

        .\ffmpeg.exe -i ($sourcepath + ".flac") -metadata title="$ti" -metadata artist="$fa" -metadata album="$al" ($destinationpath + "selected\" + $file[0].Name + ".flac")

        #$fail=0
        try
    {
   # Move-Item ($sourcepath + ".flac") ($destinationpath + "selected\") -Force -Confirm:$false
    #$fail=0
    }
    catch
    {
        Logwrite(("[ERROR] Couldn't move " + ($sourcepath + ".flac") + " to " + $destinationpath + ". Reason: " + $_ + "."))
        $fail=1
    }

                # Fullartist, Title, Metadata, LengthHR, AddedToStation
                $tracklist = $tracklist + [PSCustomObject]@{Artist = $mod.Fullartist; Title= $mod.Title; Album = $mod.Metadata; track=$orginname; failed=$fail; }
    
  
}


logwrite ("The process is now done. Saving the processed track to a CSV")
$tracklist | export-csv -path ($ProcessPath + "tracklist-" + $subfolder + ".csv") -delimiter ";" -encoding utf8 -NoTypeInformation


#openmpt123 --render somemodule.it --output-type flac.