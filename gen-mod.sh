#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -y|--year)
    YEAR="$2"
    shift # past argument
    shift # past value
    ;;
    -m|--month)
    MONTH="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--batch)
    BATCHNO="$2"
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters


Artistpath="/mnt/hgfs/LinuxInput/ArtistImport/"
Titlepath="/mnt/hgfs/LinuxInput/TitleImport/"
Basepath="/mnt/hgfs/LinuxInput/"

cd "$Basepath"


            if [ -z "$YEAR" ]; then
               echo No input params given. Assuming current date and month
	       batchno=$(date "+%b%Y-")

		# Calculate the batch number.

		numfiles=$(ls|grep "TERN-$batchno"|wc -l)
		nextbatch=$(($numfiles + 1))

		echo "Nästa batch är $nextbatch."
		totbatch="TERN-"$batchno"0$nextbatch"


            else
               echo Enough parameters given. Will use them.
               totbatch="TERN-${MONTH}${YEAR}-0${BATCHNO}"

            fi

echo $totbatch

#exit

datum=$(date "+%Y-%m-%d")
rm -rf temp/*.*

mkdir $totbatch
mkdir "$totbatch/selected"

for f in *.*
    do
extension="${f##*.}"
filename="${f%.*}"


extlow="${extension,,}"

#echo $extlow
#exit

echo "Processar filen "$f". Extension: $extension"

if [[ "$extlow" = "mod" ]]
then
  echo "Amiga module. Setting to mono."
	xmp "$f" -m --interpolation spline -e protracker -o ./temp/temp.wav </dev/null -v 1>/dev/null 2>"./temp/$f.txt"
else
	xmp "$f" -o ./temp/temp.wav </dev/null -v 1>/dev/null 2>"./temp/$f.txt"
fi


#exit
	normalize-audio ./temp/temp.wav 2>/dev/null
	ffmpeg -i ./temp/temp.wav -c:a flac "./temp/$f.flac" 2>/dev/null
#	ffmpeg -i ./temp/temp.wav -acodec libmp3lame -ab 320k "./temp/$f.mp3" 2>/dev/null
	rm -f ./temp/temp.wav
	rm -f ./temp/temp_norm.wav
	rm -f \*.XM.* 2>/dev/null
	#echo 1
	mname=$(cat ./temp/"$f".txt 2>/dev/null|grep "Module name"|cut -d " " -f5-)
	#echo 2
	comments=$(cat ./temp/"$f".txt|grep "40 0"|cut -c4-36|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'|tr : .|tr - .)
	#echo 3
	rm -f ./temp/$f.txt

	echo "The module is called $mname according to its internal name."

	Artist="Amiga"

	AFILE="$Artistpath$f";
	#echo "Looking for artistdate in $AFILE."
	if test -f "$AFILE"; then
    		echo "Found artist information for $f"
    		#Artist=$(cat "$AFILE")
		CDATA=$(tr -d '\0' < "$AFILE")
		ADATA=$(echo "$CDATA"|iconv -c -f utf-8 -t ascii)
		Artist=$(echo "$ADATA")
	fi
	echo "Artist will be set to $Artist."

	TFILE="$Titlepath$f";
	#echo "Looking for titledata in $TFILE."
	if test -f "$TFILE"; then
    		echo "Found overriding title information for $f"
    		#Title=$(cat "$TFILE")
		CTDATA=$(tr -d '\0' < "$TFILE")
		TDATA=$(echo "$CTDATA"|iconv -c -f utf-8 -t ascii)
		mname=$(echo "$TDATA")
	fi
	echo "Title will be set to $mname."

	id3v2 -t "$mname" "./temp/$f.flac"
	id3v2 -c "$comments" "./temp/$f.flac"
	id3v2 -a "$Artist" "./temp/$f.flac"
	id3v2 -A "OriginalName: $f. Imported: $datum ($totbatch)." "./temp/$f.flac"
	mv "./temp/$f.flac" "./$totbatch/selected/$f.flac"
	mv "./$f" "./$totbatch/$f"
done

echo "... AAAAAAnd we're done"