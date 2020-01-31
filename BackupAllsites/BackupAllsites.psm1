

Function BackupAllsites(){
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, Position=0, HelpMessage="Optionally filter the web application. Keep it empty if you want to backup all web applications")]
    [string]$WebApplication,
    [Parameter(Mandatory=$false, Position=1, HelpMessage="Specify a backup location")]
    [string]$BackupFolder ="\\SHARE OR FILE LOCATION" ,
    [Parameter(Mandatory=$false, Position=2, HelpMessage="Specify the days of retention for your files")]
    [int]$BackupFilesRetentionInDays = -1,
    [Parameter(Mandatory=$false, Position=2, HelpMessage="Specify if today's backup folder needs to be cleaned up first")]
    [boolean]$CleanupBackupFolder = $True
)
Add-PSSnapin Microsoft.SharePoint.Powershell -Ea 0  
 
$logPath = Join-Path $BackupFolder "_logs" 
if (-not (Test-Path $logPath)) {   
  New-Item $logPath -type directory 
}  
$tmpPath = Join-Path $BackupFolder "_tmp" 
if (-not (Test-Path $tmpPath)) {   
  New-Item $tmpPath -type directory
}  
$todaysBackupFolder = Join-Path $BackupFolder ((Get-Date).DayOfWeek.toString())  
if (-not (Test-Path $todaysBackupFolder)) {   
  New-Item $todaysBackupFolder -type directory 
}  
 
# creates a log file  
Start-Transcript -Path (Join-Path $logPath ((Get-Date).ToString('yyyyMdd_hhmmss') + ".log"))  

$allSiteCollections = $null;
if ([System.String]::IsNullOrEmpty($WebApplication)) {
    $allSiteCollections = Get-SPSite -Limit All
}
else {
    $allSiteCollections = Get-SPSite -WebApplication $WebApplication -Limit All
}
$i=0
$ii=$allSiteCollections
$allSiteCollections | ForEach-Object {
    # we have to replace some characters from the url name         
    $name = $_.Url        
    # replace all special characters from url with underscores         
    $name = [System.Text.RegularExpressions.Regex]::Replace($name,"[^0-9a-zA-Z]+","_");                  
    # define the backup name         
    $backupPath = Join-Path $tmpPath ($name + (Get-Date).ToString('yyyyMdd_hhmmss') + ".bak")                  
 
    Write-Host "Backing up $_.Url to $backupPath"         
    Write-Host                  
    Backup-SPSite -Identity $_.Url -Path $backupPath  
    $_.Dispose()
}
#IISBACKUPS
$IISBKUPPATH = Join-Path $BackupFolder\_tmp\((Get-date).Tostring('yyyyMMdd'))
Remove-Item C:\Windows\System32\inetsrv\backup -Force -Recurse
sleep 2
Backup-WebConfiguration -Name IISBKUP
Sleep 10
Copy-Item "C:\Windows\System32\inetsrv\backup" -Destination $IISBKUPPATH -Recurse

# remove the old backup files in the todays folder if specified 
if ($CleanupBackupFolder -eq $true) {   
  Write-Host "Cleaning up the folder $todaysBackupFolder"   
  Remove-Item ($todaysBackupFolder + "\*") -Recurse
}  

# move all backup files from the tmp folder to the target folder 
Write-Host "Moving backups from $tmpPath to $todaysBackupFolder" 
Move-Item -Path ($tmpPath + "\*") -Destination $todaysBackupFolder 
 
 
# you can specify an additial parameter that removes filders older than the days you specified 
if ($removeFilesOlderThanDays -gt 0) {   
  Write-Host "Checking removal policy on $todaysBackupFolder"   
 
  Get-ChildItem $todaysBackupFolder | Where {$_.LastWriteTime -le "$toRemove"} | ForEach-Object {
    Write-Host "Removing the file $fileToRemove because it is older than $removeFilesOlderThanDays days"      
    Remove-Item (Join-Path $todaysBackupFolder $_) | out-null   
      }
} 

Stop-Transcript
}