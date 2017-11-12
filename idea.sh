lsResult=""
filename=""

function doLs() {
	lsResult=`awk -v FNR=1 -v p="$@" '
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
	{nextfile}' * | sort -k2`
}

function doLsColor() {
	local green='\033[01;32m'
	local yellow='\033[01;33m'
	local blue='\033[01;34m'
	local none='\033[0m'

	lsResult=`echo "$lsResult" | awk -v g=$green -v y=$yellow -v b=$blue -v n=$none '
	{
		if ($2 ~ /^\(A\)$/) { printf y$0n"\n" }
		else if ($2 ~ /^\(B\)$/) { printf g$0n"\n" }
		else if ($2 ~ /^\(C\)$/) { printf b$0n"\n" }
		else {print $0}
	}'`
}

function doFind() {
	filename=`ls ./ | head -n $1 | tail -n 1`
}

function doNew() {
	local title="# $@\n\n"
	local newFilename="$(date +%s).md"
	
	echo $title >> $newFilename
	vim -c +3 $newFilename
}

function replacePri() {
	sed -E -i '' -e "1s/^# (\([A-Z]\) )?/# $1/" $filename
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

function doEdit() {
	$EDITOR $filename
}

function doBrowse() {
	local IFS=$'\n'
	select choice in $lsResult; do
		num=`echo "$lsResult" | head -n $REPLY | tail -n 1 | awk '{print $1}'`
		doFind $num
		break;
	done
	less +gg $filename
	echo "\n"
	doBrowse
}

function printLs() {
	echo "$lsResult"
}

command=$1

shift

case "$command" in
	"c"|"config" ) ;; # Configuration
	"nt"|"newtype" ) ;; # Creates a new idea type
	"dt"|"deltype" ) ;; # Deletes an idea type


	"l"|"ls" ) doLs $@ && doLsColor && printLs;;
	"e"|"enum" ) ;; # Enumerates idea types
	"a"|"add" ) doAdd $@;;
	"p"|"pri" ) doFind $1 && doPri $2;;

	"b"|"browse" ) doLs $@ && doBrowse;;
	"o"|"open" ) doFind $1 && doEdit;;
	"u"|"unpri" ) doFind $1 && doUnpri;;
	"n"|"new" ) doNew $@;;
	"d"|"del" ) ;; # doFind $1 && doDel;;
	"s"|"stat" ) ;; # Displays statistics

esac
	
