#!/bin/bash

command=$(which doctl)
scriptDir=$(pwd)
varLogDir=$scriptDir/logs
groupTag="${1:-allow-backup}"

if [ ! -d "$varLogDir" ]; then
  mkdir -p $varLogDir
fi

tempListFile=$scriptDir/list.tmp
rm $tempListFile > /dev/null 2>&1
touch $tempListFile
$command compute droplet list --format "ID,Name,Tags" --tag-name $groupTag >> $tempListFile

checkSnapshots() {
  dropletId=$1
  date=$2

  if [ -z "$date" ]; then
    snapshots=$($command compute snapshot list | grep "$dropletId" | wc -l)
  else
    snapshots=$($command compute snapshot list | grep "$dropletId" | grep "$date" | wc -l)
  fi
}

getOldestSnapshot() {
  dropletId=$1
  date=$2

  if [ -z "$date" ]; then
    oldestSnapshot=$($command compute snapshot list --format "ID,Name,ResourceId,CreatedAt" | grep "$dropletId" | head -n 1)
  else
    oldestSnapshot=$($command compute snapshot list --format "ID,Name,ResourceId,CreatedAt" | grep "$dropletId" | grep "$date" | head -n 1)
  fi
}

createSnapshot() {
  dropletId=$1
  maxPerDay=$2
  maxNumber=$3

  checkdate=$(date '+%Y-%m-%d')
  checktime=$(date '+%H:%M-%Z')

  dropletname=$(cat $tempListFile | grep -e $dropletId | awk '{print$2}')
  name=$dropletname-$checkdate@$checktime

  echo "Creating snapshot titled \"$name\""
  echo "Please wait this may take awhile. About 1 minute per GB."
  $command compute droplet-action snapshot --snapshot-name "$name" $dropletId --wait
  newSnap=$($command compute snapshot list | grep $dropletId | tail -n 1 | awk '{print$2}')

  checkSnapshots $dropletId $checkdate
  while [ "$snapshots" -gt "$maxPerDay" ]
  do
    getOldestSnapshot $dropletId $checkdate
    oldestId=$(echo $oldestSnapshot | awk '{print$1}')
    oldestName=$(echo $oldestSnapshot | awk '{print$2}')
    
    echo "Deleting "$oldestName""$'\r'
    $command compute image delete $oldestId --force
    checkSnapshots $dropletId $checkdate
  done

  checkSnapshots $dropletId
  while [ "$snapshots" -gt "$maxNumber" ]
  do
    getOldestSnapshot $dropletId
    oldestId=$(echo $oldestSnapshot | awk '{print$1}')
    oldestName=$(echo $oldestSnapshot | awk '{print$2}')
    
    echo "Deleting "$oldestName""$'\r'
    $command compute image delete $oldestId --force
    checkSnapshots $dropletId
  done

  echo "========================================================="
}

#read .env file
envFile=$scriptDir/.env
if [ -f "$envFile" ]; then
  source $envFile
fi

# if .env is empty or not exist, use default value
BACKUP_MAX_PER_DAY="${BACKUP_MAX_PER_DAY:-1}"
BACKUP_MAX_NUMBER="${BACKUP_MAX_NUMBER:-3}"

logdate=$(date '+%Y-%m-%d-%H:%M-%Z')

exec > >(tee -i $varLogDir/"$logdate".log)

# Read file line by line
while IFS= read -r line; do
  ID=$(echo $line | awk '{print$1}')
  MAX_PERDAY=
  MAX_NUMBER=
  tags=$(echo $line | awk '{print$3}' | grep 'allow-backup')
  if [ ! -z "$tags" ]; then
    # split tags by coma
    IFS=',' read -ra array <<< "$tags"

    # Iterate over the array elements
    for tag in "${array[@]}"; do
      # get max snapshot per day
      substring="backup-max-per-day-"
      if [[ $tag == *"$substring"* ]]; then
        MAX_PERDAY="${tag##*-}"
      fi

      # get max age
      substring="backup-max-number-"
      if [[ $tag == *"$substring"* ]]; then
        MAX_NUMBER="${tag##*-}"
      fi
    done

    # if not defined in tag, then use default value
    if [ -z "$MAX_PERDAY" ]; then
      MAX_PERDAY=$BACKUP_MAX_PER_DAY
    fi
    if [ -z "$MAX_NUMBER" ]; then
      MAX_NUMBER=$BACKUP_MAX_NUMBER
    fi

    createSnapshot $ID $MAX_PERDAY $MAX_NUMBER
  fi
done < "$tempListFile"
