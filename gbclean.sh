
function clean_date(){
	clean=$(echo "$1" | sed "s/ ago//g")
	echo "$clean"
}

delete=false



while getopts "h:d:" opt
	do
		case $opt in
			(h)
				echo "help menu"
				exit 0
				;;
			(d)
				delete=true
				;;
		esac
	done


ago=$2
cutoffEpoch=$(date +%s --date="$ago")
cutoffDate=$(date +%F --date="$ago")
cleanDate=$(clean_date "$ago")


echo "Using $cutoffDate as the cutoff date."

branches=$(git branch -a | fgrep -iv "/head" | sed s/^..//)

branchesInRange=$(for k in $branches; do
	branch=$(git log -1 --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k)"\t$k"
	lastCommitDate=$(echo "$branch" | cut -d" " -f1)
	lastCommitEpoch=$(date --date=$lastCommitDate +%s)
	if [[ $lastCommitEpoch < $cutoffEpoch ]]; then
		echo -e "$branch++"
	fi
done | sort -r | sed 's/++ /\n/g' | sed 's/++//g' )


numBranches=$(echo -e "$branchesInRange" | wc -l)
if [ $numBranches -eq 0 ]; then
	echo "No branches found"
	exit 0
else
	echo -e "\nAny branches with latest commit being older than the cutoff are listed below"
	echo -e "$branchesInRange"
fi


cleanBranches=$(printf "$branchesInRange" | cut -f2 | cut -d'/' -f3 | fgrep -v 'master' | fgrep -v 'release')
echo -e "\nCleaning data..."
echo "$cleanBranches"

confirmDelete=false
if [ $delete = true ]; then
	read -p "Delete above branches? (y/n): " response
	if [ $response = 'y' ]; then
		read -p "Are you sure? (y/n): " response
		if [ $response = 'y' ]; then
			confirmDelete=true
		else
			exit 0
		fi
	else
		exit 0
	fi
fi

for k in "$cleanBranches"; do
	echo "$k yo"
done