param (
    [string]$Key
)

# CSFix.ps1
# This script deletes the problematic CrowdStrike driver file causing BSODs and reverts Safe Mode
try {
    $fileDeleted = $false

    #Create RegKey in WinPE to store feedback for UI++
    if (!(Test-Path -Path "HKLM:\SOFTWARE\IMAGE")) {
        New-Item -Path "HKLM:\SOFTWARE\IMAGE" -Force
    }

    #Get all drives and loop through the drive letters in case the OS drive is not the C: drive
    $drives = Get-Partition 
    foreach ($drive in $drives) {
        if ($drive.DriveLetter -match "[A-Za-z]") {
            $driveLetter = "$($drive.DriveLetter):"

            $bdestatus = Invoke-Expression "manage-bde -status $letter"
            $LockStatus = $bdestatus | Select-String "Lock Status:"
            $LockStatus = (($LockStatus -split ": ")[1]).Trim()

            if ($LockStatus -eq 'Locked') {
                if ([String]::IsNullOrWhiteSpace($Key)) {
                    #No Key provided, use CSV
                    # Import CSV file
                    $recoveryKeys = Import-Csv ".\Keys.csv"

                    # Get recovery key ID 
                    $getbitlockerinfo = Invoke-Expression "manage-bde -protectors -get $driveLetter -t RecoveryPassword"
                    $recoveryKeyID = ($getbitlockerinfo | Select-String -Pattern 'ID:\s+{(.+?)}').Matches.Groups[1].Value

                    # Search for the recovery key based on recovery key ID
                    $matchingRecoveryKey = $recoveryKeys | Where-Object { $_.ID -eq $recoverykeyid }

                    # Check if a matching recovery key was found, unlock drive if found
                    if ($matchingRecoveryKey) {
                        Write-Host "Recovery key found for" $recoverykeyid
                        Write-Host "Recovery key:" $($matchingRecoveryKey.Key)
                        Write-Host "Unlocking Bitlocker Encrypted Drive"
                        manage-bde -unlock $driveLetter -RecoveryPassword $($matchingRecoveryKey.Key)
                    }
                    else {
                        Write-Host $recoverykeyid
                        Write-Host $($matchingRecoveryKey.Key)
                        Write-Host "Recovery key not found! Please resolve manually by retreiving the recovery key from MBAM."
                    }
                }
                else {
                    #Unlock with provided key
                    manage-bde -unlock $driveLetter -RecoveryPassword $key
                }
                
            }

            #Delete CS files
            Write-Host "Deleting Crowdstrike corrupt files" 
            $filePath = "$driveLetter\Windows\System32\drivers\Crowdstrike\C-00000291*.sys"
            $files = Get-ChildItem -Path $filePath -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                try {
                    Remove-Item -Path $file.FullName -Force
                    Write-Output "Deleted: $($file.FullName)"
                    if ($fileDeleted -ne $true) {
                        $fileDeleted = $true
                    } 
                }
                catch {
                    Write-Output "Failed to delete: $($file.FullName)"
                }
            }
        }
    }
    New-ItemProperty -Path "HKLM:\SOFTWARE\IMAGE" -Name "CSFixComplete" -Value $fileDeleted -PropertyType "String" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\IMAGE" -Name "RecoveryKeyID" -Value $recoveryKeyID -PropertyType "String" -Force
}
finally {
    Remove-Item 'Keys.csv' -Force
}
