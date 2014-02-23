$packageName = 'NServiceBus.MSMQ'
$tempFile = [System.IO.Path]::GetTempFileName()
$psFile = Join-Path "$(Split-Path -parent $MyInvocation.MyCommand.Definition)" 'setup.ps1'
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
