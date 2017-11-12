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

function doFind() {
	filename=`ls ./ | head -n $1 | tail -n 1`
}

function doAdd() {
	local title="# $@\n\n"
	local newFilename="$(date +%s).md"
	
	echo $title >> $newFilename
	vim -c +3 $newFilename
}

function doPri() {
	sed -E -i '' -e "1s/^# (\([A-Z]\) )?/# ($1) /" $filename
}

function doEdit() {
	$EDITOR $filename
}

function doBrowse() {
	local IFS=$'\n'
	local menu=`echo "$lsResult" | awk '{print substr($0, length($1) + 2)}'`
	select choice in $menu; do
		file=`echo "$lsResult" | head -n $REPLY | tail -n 1 | awk '{print $1}'`
		break;
	done
	vim $file
	doBrowse
}

function printLs() {
	echo "$lsResult"
}

command=$1

shift

case "$command" in
	"c"|"config" ) ;; # Configuration

	"l"|"ls" ) doLs $@ && printLs;;
	"e"|"enum" ) ;; # Enumerates idea types
	"a"|"add" ) doAdd $@;;
	"p"|"pri" ) findFile $1 && doPri $2;;

	"b"|"browse" ) doLs $@ && doBrowse;;
	"o"|"open" ) findFile $1 && doEdit;;
	"u"|"unpri" ) ;; # Unprioritizes a task
	"n"|"newtype" ) ;; # Creates a new idea type
	"d"|"del" ) ;; # Deletes an idea
	"s"|"stat" ) ;; # Displays statistics
esac
	
