Set-StrictMode -Version 2

function InstallDismFeatures($features, $ver) {
    if (DismRebootRequired) {
        throw "A reboot is required prior to installing this package"
    }

    $featureNames = [string]::Join(" ", @($features | % { "/FeatureName:$_"}))
    

    if ($ver -eq "6.1") {

        $cmd = "$dism /Online /Enable-Feature /NoRestart /Quiet $featureNames"
    } else {
        $cmd = "$dism /Online /Enable-Feature /NoRestart /Quiet /All $featureNames"
    }

    Write-Host ("Executing: {0}" -f $cmd) | Out-Default
    Invoke-Expression $cmd | Out-Default
    CheckDismForUndesirables
    
    if (DismRebootRequired) {
        Write-Host "A reboot is required to complete the MSMQ installation" | Out-Default
    }
    else {
        StartMSMQ    
    }
} 

function CheckDismForUndesirables() {
    $undesirables = @("MSMQ-Triggers", "MSMQ-ADIntegration", "MSMQ-HTTP", "MSMQ-Multicast", "MSMQ-DCOMProxy")
    $msmqFeatures = @(Invoke-Expression "$dism /Online /Get-Features /Format:Table"| Select-String "^MSMQ" -List )
    $removeThese = @()
    
    foreach ($msmqFeature in $msmqFeatures) {
        
        $key = $msmqFeature.ToString().Split("|")[0].Trim()    
        $value = $msmqFeature.ToString().Split("|")[1].Trim()
        if ($undesirables -contains $key) {
            if (($value -eq "Enabled") -or ($value -eq "Enable Pending")) {
                $removeThese += $key                 
            }
        }
    }
    
    if ($removeThese.Count -gt 0 ) {
         $featureNames = [string]::Join(" ", @($removeThese | % { "/FeatureName:$_"}))
         Write-Warning "Undesirable MSMQ feature(s) detected. Please remove using this command: `r`n`t dism.exe /Online /Disable-Feature $featureNames `r`nNote: This command is case sensitive"  | Out-Default
    } 
}

function StartMSMQ () {

    $msmqService = Get-Service -Name "MSMQ" -ErrorAction SilentlyContinue
    if (!$msmqService)  {
        throw "MSMQ service not found"
    }   

    if (@("Stopped", "Stopping","StopPending") -contains $msmqService.Status) {
        Restart-Service -Name "MSMQ" -Force -Verbose | Out-Default
    }
}

function DismRebootRequired() {
    $info = @(Invoke-Expression "$dism /Online /Get-Features /Format:Table" | Select-String "Disable Pending", "Enable Pending" -List )
    return ($info.Count -gt 0)
}

function IsProcess32Bit(){
     return [IntPtr]::size -eq 4
}

#Is this a Wow64 powershell host
function IsWow64() {
    return (IsProcess32Bit) -and (test-path env:\PROCESSOR_ARCHITEW6432)
}

if (IsWow64) {
    # sysnative is a virtual folder only available to 32 bit processes running under a 64bit OS
    # sysnative is the 64bit version of system32 rather than the redirected folder
    $dism = "$Env:SystemRoot\sysnative\dism.exe"
}
else{ 
    $dism = "$Env:SystemRoot\system32\dism.exe"
}

try {
    Start-Transcript -Path $args[0] -Force

    $osVersion = [Environment]::OSVersion.Version
    $ver = "{0}.{1}" -f $osVersion.Major, $osVersion.Minor

    switch ($ver) 
    {
        { @("6.3", "6.2") -contains $_ }  {
             # Win 8.x and Win 2012
             Write-Host "Detected Windows 8.x/Windows 2012" | Out-Default
             InstallDismFeatures @("MSMQ-Server") $ver
        }
        
        "6.1" {  
              # Windows 7 and Windows 2008 R2
             Write-Host "Detected Windows 7/Windows 2008 R2" | Out-Default
             InstallDismFeatures @("MSMQ-Server", "MSMQ-Container") $ver
         }
        "6.0" { 
            #TBD -  Windows Server 2008 and Vista
            $osInfo = Get-WmiObject Win32_OperatingSystem
            if ($osInfo.ProductType -eq 1) {
                Write-Host "Detected Windows Vista" | Out-Default
                throw "Unsupported Operating System"
            }
            else {
                Write-Host "Detected Windows Windows 2008" | Out-Default
                throw "Unsupported Operating System"
            }
        }
        default {
            # XP and Win2003 
            Write-Host "Detected Windows XP / Windows 2003" | Out-Default
            throw "Unsupported Operating System"
        }
    }
}
catch {
    $_ | Out-Default
	throw $_  
}
finally {
    Stop-Transcript
}