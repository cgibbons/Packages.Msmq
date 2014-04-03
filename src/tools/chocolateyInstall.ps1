$packageName = 'NServiceBus.MSMQ'

$psFile = Join-Path "$(Split-Path -parent $MyInvocation.MyCommand.Definition)" 'setup.ps1'
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if ($principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
	& "$psFile"
} 
else {
	$tempFile = [System.IO.Path]::GetTempFileName()
	try
	{
		Start-ChocolateyProcessAsAdmin "& `'$psFile`' `'$tempFile`'"
		Get-Content $tempFile
	}
	catch
	{
		Get-Content $tempFile
		throw $_
	}
}
