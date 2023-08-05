# Helper script on Windows to create or backup the pub.db database in the /data folder
# This assumes "sqlite3" has been added to PATH

# This file's location
$ROOT = $PSScriptRoot + '\'

# Data folder
$FD = $ROOT + 'data\'

# Database name
$DB = $FD + 'pub.db'

# SQL File
$SQL = $ROOT + 'pub.db.sql'

# Log file
$LOG = $FD + 'install.log'

# Timestamp
$DATE = (Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')

if ( -not( Test-Path -Path $FD -PathType container ) ) {
	New-Item -ItemType Directory -Path $FD
}

if ( -not( Test-Path -Path $LOG -PathType leaf ) ) {
	New-Item -ItemType File -Path $LOG
}

# Backup to data folder, if pub.db already exists
if ( Get-Item -Path $DB -ErrorAction Ignore ) {
	sqlite3 $DB .dump | Set-Content "$DB.$DATE.sql"
  	$MSG = "- Backed up $DB $DATE"
   	$MSG | Out-File $LOG -Append
	Write-Host $MSG
} else {
	Get-Content $SQL | sqlite3 $DB
 	$MSG = "- Created $DB $DATE"
  	$MSG | Out-File $LOG -Append
	Write-Host $MSG
}
