# This powershell script will:
#   Disable users and computers which inactive N days
#   Append date when it was disabled and current CN to object description
#   Move disabled users and computers to specific OU
#   Remove empty groups
# Just set variables and schedule execution!

import-module activedirectory

$ou="ou=some ou,dc=domain,dc=com"
$days=90
$disabledusers="ou=some other ou,dc=domain,dc=com"
$disabledcomputers="ou=some other ou,dc=domain,dc=com"

get-aduser -searchbase $ou -filter * -properties lastlogondate, canonicalname, description |
	where-object {$_.enabled -eq "true" -and $_.lastlogondate -lt (get-date).adddays(-($days))} |
	foreach-object {set-aduser -enabled $false $_ -description "Disabled on $(get-date) Last logon $($_.lastlogondate) $($_.canonicalname) $($_.description)"}

get-adcomputer -searchbase $ou -filter * -properties lastlogondate, canonicalname, description |
	where-object {$_.enabled -eq "true" -and $_.lastlogondate -lt (get-date).adddays(-($days))} |
	foreach-object {set-adcomputer -enabled $false $_ -description "Disabled on $(get-date) Last logon $($_.lastlogondate) $($_.canonicalname) $($_.description)"}

get-aduser -searchbase $ou -filter ‘enabled -eq $false’ |
	foreach {move-adobject -identity "$_" -targetpath $disabledusers}

get-adcomputer -searchbase $ou -filter ‘enabled -eq $false’ |
	foreach {move-adobject -identity "$_" -targetpath $disabledcomputers}

get-adgroup -searchbase $ou -filter * -properties members |
    	where { $_.members.count -eq 0 } |
    	foreach {remove-adgroup -identity "$_" -confirm:$false}
