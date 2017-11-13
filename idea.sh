#! /usr/bin/env zsh

platform='unknown'
unamestr=`uname`

if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='freebsd'
fi

if [[ "$platform" == "freebsd" ]]; then
	alias awk=gawk
	alias sedInPlace="sed -i '' "
else
	alias sedInPlace="sed -i "
fi
 
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
	lsResult="$(awk -v FNR=1 -v p="${@}" '
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

	resultCount=`echo "$lsResult" | sed '/^\s*$/d' | wc -l`
}

function doLsColor() {
	lsOutput=`echo "$lsResult" | awk -v g=$green -v y=$yellow -v b=$blue -v p=$purple -v m=$magenta -v n=$none '
	function printTokens(c)
	{
		$0=gensub(/ ([\+][^ ]+)/,"\t"m"\\\1"c, "g", $0)
		$0=gensub(/ ([@][^ ]+)/,"\t"p"\\\1"c, "g", $0)
		printf $1" "c""substr($0, length($1) + 2)""n"\n"
	}
	{
		if ($2 ~ /^\(A\)$/) { printTokens(y) }
		else if ($2 ~ /^\(B\)$/) { printTokens(g) }
		else if ($2 ~ /^\(C\)$/) { printTokens(b) }
		else {printTokens(n)}
	}' | column -s$'\t' -tx`
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
	sedInPlace -E -e "1s/^# (\([A-Z]\) )?/# $1/" ./$filename
}

function doPri() {
	local pri=`awk -v pri=$1 'BEGIN { if (toupper(pri) ~ /^[A-Z]$/) { print toupper(pri)} }'`

	if [ -n "$pri" ]; then
	 	replacePri "($pri) "
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
	printf "\033c"
	doFind
	doLs $@
	doLsColor
	echo "IDEA: Browsing $@"
	echo "--"
	printLs
	printf "💡  "$blue"❯"$none" "
	read
	doCommand ${=REPLY}
	doBrowse $@
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
	echo "$lsOutput"
	echo "--"
	echo "IDEA: $resultCount of $allCount ideas shown\n"
}

function doStats() {
	stats=$(echo "$lsResult" | awk -v allCount=$allCount '
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
			for (tag in projects) print projects[tag], tag
			for (tag in contexts) print contexts[tag], tag
			print "IDEA:", allCount, "Ideas", length(projects), "+Projects", length(contexts), "@Contexts"
		}
	' | sort -nrk 1,1)

	local lastLine="$(echo "$stats" | tail -1)"
	local rest=$(echo $stats | sed \$d | column -x)

	echo "$rest"$'\n'"--"$'\n'"$lastLine" | awk -v p=$purple -v m=$magenta -v n=$none '
		{
			$0=gensub(/([\+][^ \t]+)/, m"\\1"n, "g", $0)
			$0=gensub(/([@][^ \t]+)/, p"\\1"n, "g", $0)
			print $0
		}
	';
}

function doAppend() {
	echo $filename
	sedInPlace -E -e "1s/(.+)/\\1 $1/" ./$filename
}

function doCommand() {
	command=$1

	shift

	# TODO: Do flags

	case "$command" in

		"i"|"incpri" ) doFind && doFindFile $1 && doIncpri;; # Increment Priority

		"g" ) ;;
		"r"|"replace" ) ;; # Replaces a title
		"w" ) ;;

		"l"|"ls" ) doFind && doLs ${@} && doLsColor && printLs;;
		"e"|"enum" ) ;; # Enumerates idea types
		"a"|"append" ) doFind && doFindFile $1 && doAppend $2;; # Appends to the title
		"p"|"pri" ) doFind && doFindFile $1 && doPri $2;;
		"s"|"stat" ) doFind && doLs ${@} && doStats;; # Displays statistics

		"b"|"browse" ) doBrowse $@;;
		"o"|"open" ) doFind && doFindFile $1 && doEdit;;
		"u"|"unpri" ) doFind && doFindFile $1 && doUnpri;;
		"n"|"new" ) mkSubdir && doNew $@;;
		"d"|"depri" ) doFind && doFindFile $1 && doDepri;;
		"ss"|"snapstat" ) ;; # Snapshots statistics
		
		"config" ) ;; # Configuration
		"newtype" ) ;; # Creates a new idea type
		"deltype" ) ;; # Deletes an idea type
		"delete" ) doFind && doFindFile $1 && doDelete;;
	esac
}

doCommand $@
	
