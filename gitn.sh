#!/usr/bin/bash
function clean_date()
{
	clean=$(echo "$1" | sed "s/ ago//g")
	echo "$clean"
}

function yellow_output()
{
	printf "\033[1;33m"
}

function normal_output()
{
	printf "\033[0m"
}

function git_command_exec()
{
	for key in ${!REPO_maps_PATH[@]}; do
		repoPath=${REPO_maps_PATH[$key]}
		cd $repoPath
		yellow_output
		echo "Updating $key repo"

		normal_output

		if [ "$2" = "" ]; then
			echo "$1 >>> MASTER"
			git checkout master &> /dev/null
			git "$1"

			echo ""

			echo "$1 >>> RELEASE"
			git checkout release &> /dev/null
			git "$1"
		else
			echo "$1 >>> $2"
			git checkout "$2" &> /dev/null
			git "$1"
		fi

		echo -e "\n"
	done
}

function get_stale_branches()
{
	repo=$2
	path=$3
	cd "$path"

	yellow_output
	echo "Swtiching to $repo -> $path"
	normal_output

	ago=$1
	cutoffEpoch=$(date +%s --date="$ago")
	cleanDate=$(clean_date "$ago")


	branches=$(git branch -a | fgrep -iv "/head" | sed s/^..//)


	branchesInRange=$(for k in $branches; do
		branch=$(git log -1 --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k)"\t$k"
		lastCommitDate=$(echo "$branch" | cut -d" " -f1)
		lastCommitEpoch=$(date --date=$lastCommitDate +%s)
		if [[ $lastCommitEpoch < $cutoffEpoch ]]; then
			echo -e "$branch++"
		fi
	done | sort -r | sed 's/++ /\n/g' | sed 's/++//g' )

	if [ $VERBOSE = true ]; then
		echo "Ignoring requested sensitive branches"
	fi

	if [[ $IGNORE_FILE != "" ]]; then
		branchesInRange=$(printf "$branchesInRange" | fgrep -vw 'master' | fgrep -vw 'release' | fgrep -vw -f "$IGNORE_FILE")
	else
		branchesInRange=$(printf "$branchesInRange" | fgrep -vw 'master' | fgrep -vw 'release')
	fi
	
	cleanBranches=$(printf "$branchesInRange" | cut -f2 | cut -d'/' -f3| uniq )


	numBranches=$(echo -e "$branchesInRange" | egrep -v ^$ | wc -l)
	if [ $numBranches -eq 0 ]; then
		echo "No branches found matching older than $cleanDate and processed through ignore filter"
		exit 0
	else
		if [ $VERBOSE = true ]; then
			echo -e "\nAny branches with latest commit being older than the cutoff are listed below"
			echo -e "$branchesInRange"
			echo -en "\nCleaning data..."
		fi
	fi

	yellow_output
	echo -e "\nBRANCHES"
	normal_output
	echo "$cleanBranches"

	confirmDELETE=false
	if [ $DELETE = true ]; then
		read -p "Delete above branches? (y/n): " response
		if [ $response = 'y' ]; then
			read -p "Are you sure? (y/n): " response
			if [ $response = 'y' ]; then
				confirmDELETE=true
			else
				exit 0
			fi
		else
			exit 0
		fi
	fi

	while read -r cleanBranch <&3; do
		if [ $confirmDELETE = true ]; then
			read -p "Delete $cleanBranch?: " r
			if [ "$r" = 'y' ]; then
				git push origin --delete "$cleanBranch"
			fi
		fi
	done 3<<< "$cleanBranches"
	
	if [ $confirmDELETE = true ]; then
		git push
	fi
}

declare -g DELETE=false
declare -g GIT_PULL=false
declare -g VERBOSE=false
declare -g CUSTOM_GIT_REPO=false
declare -g IGNORE_FILE=''

while getopts "dhpvdc:i:" opt
	do
		case $opt in
			(h)
				echo "help menu"
				exit 0
				;;
			(d)
				DELETE=true
				;;
			(v)
				VERBOSE=true
				;;
			(p)
				cat ~/.git_repos
				exit 0
				;;
			(c)
				CUSTOM_GIT_REPO=true
				;;
			(i)
				IGNORE_FILE=$(realpath "$OPTARG")
				;;
		esac
	done


arg1=$(echo "${@:$OPTIND:2}" | cut -d' ' -f1)

#echo $IGNORE_FILE; exit 0;

declare -Ag REPO_maps_PATH
while IFS= read -r line; do
	repo=$(echo $line | cut -d"=" -f1)
	path=$(echo $line | cut -d"=" -f2)
	REPO_maps_PATH[$repo]=$path
done < ~/.git_repos

# Calling pull on all repos
if [ "$arg1" = "pull" -o "$arg1" = "status" -o "$arg1" = "checkout" ]; then
	arg2=$(echo "${@:$OPTIND:2}" | cut -d' ' -f2 -s)
	git_command_exec "$arg1" "$arg2"
	exit 0
fi

# Finding stale branches on all repos
for repo in ${!REPO_maps_PATH[@]}; do
	ago=${@:$OPTIND:1}
	cutoffDate=$(date +%F --date="$ago")
	yellow_output
	echo -e "Using $cutoffDate as the cutoff date. \n"
	normal_output

	path=${REPO_maps_PATH[$repo]}
	get_stale_branches "$ago" "$repo" "$path"
done