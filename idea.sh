#! /usr/local/bin/bash

platform='unknown'
unamestr=`uname`
browseCommands=()

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
grey='\033[01;08m'
none='\033[0m'
reset='\033c'

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
	patterns=$(echo "$@" | sed 's/ /|/g')
	lsResult="$(awk -v FNR=1 -v p=$patterns '
	{
		m=1
		split(p, patterns, "|")
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
	lsOutput=`echo "$lsResult" | awk -v g=$green -v y=$yellow -v b=$blue -v p=$purple -v m=$magenta -v gg=$grey -v n=$none '
	function printTokens(c)
	{
		res=substr($0, length($1) + 2)
		res=gensub(/^(\(([A-Z])\))?/, "(\\\2)\t", "g", res)
		res=gensub(/^\(\)/, "(_)", "g", res)
		res=gensub(/ ([\+][^ ]+)/,"\t"m"\\\1"c, "g", res)
		res=gensub(/ ([@][^ ]+)/,"\t"p"\\\1"c, "g", res)
		printf $1"\t"c""res""n"\n"
	}
	{
		if ($2 ~ /^\(A\)$/) { printTokens(y) }
		else if ($2 ~ /^\(B\)$/) { printTokens(g) }
		else if ($2 ~ /^\(C\)$/) { printTokens(b) }
		else {printTokens(gg)}
	}' | column -s$'\t' -tx`
}

function doFind() {
	findResults=($(find ./ -name "*.md" | sed '/^\s*$/d'))

	allCount="${#findResults[@]}"

	if [ "$allCount" -eq "0" ]; then
		echo "No ideas found in $(pwd)"
		return 1
	fi
}

function doFindFile() {
	filename="${findResults[$1 - 1]}"
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

function replace() {
	title=$(echo "$@" | sed 's/\n//g')
	sedInPlace -E -e "1s/^# (\([A-Z]\))? .+$/# \\1 $title/" ./$filename
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

function printBrowsePrompt() {
	local pre=""

	if [[ "$1" == "true" ]]; then
		pre+="\033[1K\r"
	fi

	shift

	local prettyCom=$(echo "$@" | awk -v m=$magenta -v p=$purple -v spaceChar=$'\e0' '
		{
			$0=gensub(spaceChar, " ", "g", $0)
			$0=gensub(/([\+][^ ]+)/, m"\\1"n, "g", $0)
			$0=gensub(/([@][^ ]+)/, p"\\1"n, "g", $0)
			print $0
		}
	')
	printf $pre"💡  "$blue"❯"$none" $prettyCom"
}

function doBrowse() {
	local commandIndex=${#browseCommands[@]}
	local newChar=""
	local lastChar=""
	local com=""
	local prettyArgs=$(echo "$@" | awk -v m=$magenta -v p=$purple -v n=$none -v spaceChar=$'\e0' '
		{
			$0=gensub(spaceChar, " ", "g", $0)
			$0=gensub(/([\+][^ ]+)/, m"\\1"n, "g", $0)
			$0=gensub(/([@][^ ]+)/, p"\\1"n, "g", $0)
			print $0
		}
	')

	printf $reset
	doFind
	doLs $@
	doLsColor
	echo "IDEA: Browsing $prettyArgs"
	echo "--"
	printLs
	echo

	printBrowsePrompt "false" $com

	while IFS= read -r -n 1 -s newChar ; do
		if [ -z "$newChar" ]; then
			break
		elif [[ $newChar == $'\x7f' ]]; then
			if [ ! -z $com ]; then
				com=${com::-1}
			fi
		elif [[ "$newChar" == " " ]]; then
			com+=$'\e0'
		else
			com+=$newChar
		fi
		lastChar=$newChar
		printBrowsePrompt "true" "$com"
	done
	local IFS=$'\e0'
	args=($com)
	IFS=$'\n'
	case ${args[1]} in
		"b"|"browse"|"l"|"ls" ) doBrowse ${args[@]} ;;
		* ) doCommand ${args[@]} && doBrowse $@ ;;
	esac
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
	sedInPlace -E -e "1s/(.+)/\\1 $1/" ./$filename
}

function doWatch() {
	if [ -n "$(find ./ -type f -mtime 1s)" ]; then
		watchOutput $@
	fi

	sleep 1
	doWatch $@
}

function watchOutput() {
	printf $reset
	echo "IDEA: Watching $@"
	echo "--"
	doFind && doLs $@ && doLsColor && printLs
}

function doCommand() {
	command=$1

	shift

	# TODO: Do flags

	case "$command" in

		"i"|"incpri" ) doFind && doFindFile $1 && doIncpri;; # Increment Priority

		"g" ) ;;
		"r"|"replace" ) doFind && doFindFile $1 && replace $@;; # Replaces a title
		"w"|"watch" ) watchOutput $@ && doWatch $@;;

		"l"|"ls" ) doFind && doLs $@ && doLsColor && printLs;;
		"e"|"enum" ) ;; # Enumerates idea types
		"a"|"append" ) doFind && doFindFile $1 && doAppend $2;; # Appends to the title
		"p"|"pri" ) doFind && doFindFile $1 && doPri $2;;
		"s"|"stat" ) doFind && doLs $@ && doStats;; # Displays statistics

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
