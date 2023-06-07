# Digital Ocean Auto-Snapshot

## Requirements
- [doctl](https://github.com/digitalocean/doctl#installing-doctl)
- Digital Ocean Access Token

## Installation
- Clone the repository
```
$ git clone https://github.com/mrofi/digital-ocean-auto-create-snapshot.git
```

## How To Use
- add tag `allow-backup` in every droplets that need backup
- create new `.env` file :
```
$ cp .env.example .env
```
  check part [Configurations](#Configuration)
- to run the command : `./do_auto_snapshot.sh`
- you also can provide **Digital Ocean Token** :
`DIGITALOCEAN_ACCESS_TOKEN=<your token> ./do_auto_snapshot.sh`
- for only specific tag i.e. `backup-batch-1`, you can do :
`./do_auto_snapshot.sh backup-batch-1`

## Configuration
- `BACKUP_MAX_PER_DAY=1`
maximum number of backup in each day, you can override for specific droplet by adding tag: `backup-max-per-day-{max_number_per_day}`, example `backup-max-per-day-1`

- `BACKUP_MAX_NUMBER=3`
how many days to keep the backup, you can override for specific droplet by adding tag: `backup-max-number-{max_number_of_snapshots}`, example `backup-max-number-3`


## How Does It Work?
- get all droplets
- filter only has `allow-backup` tag
- based on configuration, check if backup for today is created
- delete expired backup  
