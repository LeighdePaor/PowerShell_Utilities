<#
    .SYNOPSIS
    Finds all plug and play audio devices and filters disables any that are display type (HDMI/DP)

    .DESCRIPTION
    Retrieves all plug and play audio devices on local PC and filters for "display" type
    Disables any display type audio devices

	.NOTES
	Must run elevated
#>
$DisplayAudioDevices = @(Get-PnpDevice -Class MEDIA |Where-Object{$_.FriendlyName -match "display"})
if($DisplayAudioDevices.count -gt 0){
	$DisplayAudioDevices | ForEach-Object {Disable-PnpDevice -InstanceId $_.InstanceID -Confirm:$false}
}else{Write-host "No display type audio devices found on $(hostname)"}