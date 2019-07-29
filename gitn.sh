#!/usr/bin/bash

source ~/.colorize.sh

function clean_date()
{
	clean=$(echo "$1" | sed "s/ ago//g")
	echo "$clean"
}

function git_command_exec()
{
	for key in ${!REPO_maps_PATH[@]}; do
		repoPath=${REPO_maps_PATH[$key]}
		cd $repoPath
		yellow_output
		echo -e "Updating $key repo\n"

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

	echo -n "Switching to"
	yellow_output
	echo -n " $repo "
	normal_output
	echo "@ $path"

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
		branchesInRange=$(printf "$branchesInRange" | fgrep -vw 'master' | fgrep -vw -f "$IGNORE_FILE")
	else
		branchesInRange=$(printf "$branchesInRange" | fgrep -vw 'master')
	fi
	
	# ignores branches user has specified in config file
	for importantBranch in $(echo $IMPORTANT_BRANCHES | tr "+" " "); do
		branchesInRange=$(printf "$branchesInRange" | fgrep -vw "$importantBranch" )
	done
	
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
	echo -e "\nStale branches\n-----"
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
}

declare -g DELETE=false
declare -g GIT_PULL=false
declare -g VERBOSE=false
declare -g CUSTOM_GIT_REPO=false
declare -g IGNORE_FILE=''
declare -g INTERACTIVE=false
declare -g IMPORTANT_BRANCHES=''

while getopts "hpvdic:f:" opt
	do
		case $opt in
			(h)
				echo "-d (d)eletes stale branches if checking for stale branches"
				echo "-i (i)nteractive, confirmation when needed"
				echo "-v (v)erbose output"
				echo "-p (p)rints config file"
				echo "-f (f)ile containing branches to ignore if checking for stale branches"
				exit 0
				;;
			(d)
				DELETE=true
				;;
			(i)
				INTERACTIVE=true
				;;
			(v)
				VERBOSE=true
				;;
			(p)
				yellow_output
				echo "$(pwd ~)/.git_repos"
				normal_output
				cat ~/.git_repos
				exit 0
				;;
			(c)
				CUSTOM_GIT_REPO=true
				;;
			(f)
				IGNORE_FILE=$(realpath "$OPTARG")
				;;
		esac
	done


arg1=$(echo "${@:$OPTIND:2}" | cut -d' ' -f1)

declare -Ag REPO_maps_PATH
while IFS= read -r line; do
	repo=$(echo $line | cut -d"=" -f1)
	path=$(echo $line | cut -d"=" -f2 | cut -d":" -f1)
	REPO_maps_PATH[$repo]=$path
	
	IMPORTANT_BRANCHES=$(echo $line | cut -d"=" -f2 | cut -d":" -f2)
done < ~/.git_repos


# Executes a git command on all saved repos found in .git_repos
if [ "$arg1" = "pull" -o "$arg1" = "status" -o "$arg1" = "checkout" ]; then
	arg2=$(echo "${@:$OPTIND:2}" | cut -d' ' -f2 -s)
	git_command_exec "$arg1" "$arg2"
	exit 0
fi


# Finding stale branches on all repos
ago=$arg1
cutoffDate=$(date +%F --date="$ago")
yellow_output
echo -e "Using $cutoffDate as the cutoff date. \n"
normal_output

for repo in ${!REPO_maps_PATH[@]}; do
	path=${REPO_maps_PATH[$repo]}
	get_stale_branches "$ago" "$repo" "$path"
done