#! /usr/bin/env zsh

green='\033[01;32m'
yellow='\033[01;33m'
blue='\033[01;34m'
purple='\033[01;35m'
magenta='\033[01;31m'
none='\033[0m'

subdir="$(date +'%Y/%m/%d')"
allCount=0
findResults=""
resultCount=0
lsResult=""
lsOutput=""
filename=""
stats=""

function mkSubdir() {
	mkdir -p $subdir
}

function doLs() {
	lsResult="$(awk -v FNR=1 -v p="$@" '
	{
		m=1
		split(p, patterns, " ")
		for (i=0; i < length(patterns) && m==1; i++) {
			pattern=patterns[i]
			if (pattern ~ /^-/) { 
				if($0 ~ substr(pattern, 2)) { m=0 }
			} else {
				if($0 !~ pattern) { m=0 }
			}
		}

		if (m==1) {
			print NR, substr($0,length($1)+2)
		}
	}
	{nextfile}' "${findResults[@]}" | sort -k2)"

	resultCount=`echo "$lsResult" | wc -l`
}

function doLsColor() {
	lsOutput=`echo "$lsResult" | awk -v g=$green -v y=$yellow -v b=$blue -v p=$purple -v m=$magenta -v n=$none '
	function printTokens(c)
	{
		$0=gensub(/ ([\+][^ ]+)/," "m"\\\1"c, "g", $0)
		$0=gensub(/ ([@][^ ]+)/," "p"\\\1"c, "g", $0)
		printf c$0n"\n"
	}
	{
		if ($2 ~ /^\(A\)$/) { printTokens(y) }
		else if ($2 ~ /^\(B\)$/) { printTokens(g) }
		else if ($2 ~ /^\(C\)$/) { printTokens(b) }
		else {printTokens(n)}
	}'`
}

function doFind() {
	setopt nullglob
	findResults=(./**/*.md)
	unsetopt nullglob

	allCount="${#findResults[@]}"

	if [ "$allCount" -eq "0" ]; then
		echo "No ideas found in $(pwd)"
		return 1
	fi
}

function doFindFile() {
	filename="${findResults[$1]}"
}

function doNew() {
	local title="# $@"
	title+=$'\n'
	title+=$'\n'
	local newFilename="$(date +'%H.%M.%S').md"
	
	echo "$title" > $subdir/$newFilename
	vim +3 $subdir/$newFilename
}

function replacePri() {
	sed -E -i -e "1s/^# (\([A-Z]\) )?/# $1/" ./$filename
}

function doPri() {
	local pri=`awk -v pri=$1 'BEGIN { pri=toupper(pri); if (pri ~ /^[A-Z]$/) {print pri} }'`

	if [ -n "$pri" ]; then
	 	replacePri "($1) "
	else
		echo "Priority must be a letter A-Z"
	fi
}

function doUnpri() {
	replacePri ""
}

function doDepri() {
	local newPri=`awk -v NR=1 '
		{
			if ($2 ~ /^\(A\)$/) { printf "(B) " }
			else if ($2 ~ /^\(B\)$/) { printf "(C) " }
			else if ($2 ~ /^\(C\)$/) { printf "(D) " }
			else if ($2 ~ /^\(D\)$/) { printf "(E) " }
			else if ($2 ~ /^\(E\)$/) { printf "(F) " }
			else { printf "" }
		}
	' $filename`

	replacePri $newPri
}

function doIncpri() {
	local newPri=`awk -v NR=1 '
		{
			if ($2 ~ /^\(A\)$/) { printf "(A) " }
			else if ($2 ~ /^\(B\)$/) { printf "(A) " }
			else if ($2 ~ /^\(C\)$/) { printf "(B) " }
			else if ($2 ~ /^\(D\)$/) { printf "(C) " }
			else if ($2 ~ /^\(E\)$/) { printf "(D) " }
			else if ($2 ~ /^\(F\)$/) { printf "(E) " }
			else { printf "(F) " }
		}
	' $filename`

	replacePri $newPri
}

function doEdit() {
	$EDITOR $filename
}

function doBrowse() {
	local IFS=$'\n'
	select choice in $lsOutput; do
		num=`echo "$lsResult" | head -n $REPLY | tail -n 1 | awk '{print $1}'`
		doFindFile $num
		break;
	done
	less +gg $filename
	echo "\n"
	doBrowse
}

function doDelete() {
	local title=`head -n 1 $filename | awk '{print substr($0, 3)}'`

	echo "Are you sure you want to delete $title? " 
	read -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		rm $filename
		echo "Deleted $filename"
	fi
	
}

function printLs() {
	echo "Found $resultCount results:\n"
	echo "$lsOutput"
}

function doStats() {
	stats=$(echo "$lsResult" | awk -v p=$purple -v m=$magenta -v n=$none '
		{
			split($0, tokens, " ")
			for (i=0; i < length(tokens); i++) {
				token=tokens[i]
				if (token ~ /^[\+]/) projects[token]++
				else if (token ~ /^[@]/) contexts[token]++
			}
		}
		END {
			print ""
			for (tag in projects) print projects[tag], m""tag""n
			for (tag in contexts) print contexts[tag], p""tag""n
		}
	' | sort -nrk 1,1)
	echo "$stats"
}

function doAppend() {
	echo $filename
	sed -E -i -e "1s/(.+)/\\1 $1/" ./$filename
}

command=$1

shift

case "$command" in

	"i"|"incpri" ) doFind && doFindFile $1 && doIncpri;; # Increment Priority

	"l"|"ls" ) doFind && doLs $@ && doLsColor && printLs;;
	"e"|"enum" ) ;; # Enumerates idea types
	"a"|"append" ) doFind && doFindFile $1 && doAppend $2;; # Appends to the title
	"p"|"pri" ) doFind && doFindFile $1 && doPri $2;;

	"b"|"browse" ) doFind && doLs $@ && doLsColor && doBrowse;;
	"o"|"open" ) doFind && doFindFile $1 && doEdit;;
	"u"|"unpri" ) doFind && doFindFile $1 && doUnpri;;
	"n"|"new" ) mkSubdir && doNew $@;;
	"d"|"depri" ) doFind && doFindFile $1 && doDepri;;
	"s"|"stat" ) doFind && doLs && doStats;; # Displays statistics

	"config" ) ;; # Configuration
	"newtype" ) ;; # Creates a new idea type
	"deltype" ) ;; # Deletes an idea type
	"delete" ) doFind && doFindFile $1 && doDelete;;
esac
	
