<#
	Disable Windows Fast boot - run from elevated PowerShell
#>

################### - Functions - ####################
function set-reg_keys{
  Param(
    #Parameter that can be modified to control which resource groups this runs against
    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        HelpMessage="Enter one or more Windows registry setting as a hashtable object."
        )
    ]
    $RegSet = $null
  )
  if(!(($RegSet | Get-Member | Where-Object {$_.MemberType -like "NoteProperty"}).count -eq 6)){
		Write-Host "Cannot process item RegSet parameter requires psobject with 6 NoteProperty items: Path, Name, Type, Value, Hive, Comment" -ForegroundColor Red
    break
	}else{
    $Names = (($RegSet | Get-Member | Where-Object {$_.MemberType -like "NoteProperty"}).name)
    foreach($Name in $names){
      if(!(@("Path", "Name", "Type", "Value", "Hive", "Comment") -contains  $name)){
        Write-Host "Cannot process item RegSet parameter requires psobject with 6 NoteProperty items: Path, Name, Type, Value, Hive, Comment" -ForegroundColor Red
        break
      }else{Write-Verbose "Valid noteproperty field object found"}
    }
		
    switch($RegSet.Hive){
			{$_ -eq "HKEY_LOCAL_MACHINE"}{
        $Hive = "HKLM"
        Write-Verbose "Hive = HKLM"
      }
			{$_ -eq "HKEY_CURRENT_USER"}{
        $Hive = "HKCU"
        Write-Verbose "Hive = HKCU"
      }
			default {
        $Hive = $false
        Write-Host "Error invalid Hive type, should be either HKEY_LOCAL_MACHINE or HKEY_CURRENT_USER" -ForegroundColor Red
        break
      }
		}
		switch($RegSet.Type){
			{$_ -eq "REG_SZ"}{
        $Type = "String"
        Write-Verbose "Data Type = String"
        break
      }
			{$_ -eq "REG_EXPAND_SZ"}{
        $Type = "ExpandString"
        Write-Verbose "Data Type = ExpandString"
        break
      }
			{$_ -eq "REG_BINARY"}{
        $Type = "Binary"
        Write-Verbose "Data Type = Binary"
        break
      }
			{$_ -eq "REG_DWORD"}{
        $Type = "DWord"
        Write-Verbose "Data Type = DWord"
        break
      }
			{$_ -eq "REG_MULTI_SZ"}{
        $Type = "MultiString"
        Write-Verbose "Data Type = MultiString"
        break
      }
			{$_ -eq "REG_QWORD"}{
        $Type = "Qword"
        Write-Verbose "Data Type = QWord"
        break
      }
			default {
        $Type = $false
        Write-Host "Error invalid data type, should be one of REG_SZ, REG_EXPAND_SZ, REG_BINARY, REG_DWORD, REG_MULTI_SZ or REG_QWORD" -ForegroundColor Red        
        break
      }
		}
		if(($Hive -eq $false) -or ($Type -eq $false)){
			Write-Host "Error with type or hive specified, cannot continue" -Foregroundcolor Red
			break
		}
		[string]$Path = $RegSet.Path
    Write-Verbose "Looking for registry path $($Path)"
		[string]$Name = $RegSet.Name
    Write-Verbose "Looking for registry key $($Name)"
		$Value = $RegSet.Value
    Write-Verbose "Looking for key value $($Value)"
    #see if reg path works, create if not
    $pathitems = $Path.split("\")
    $CurrentPath = ""
    $ItemNumber = 0
    foreach($Item in $pathitems){
      if($ItemNumber -eq 0){
        $CurrentPath = $Item
      }else{
        $OldPath = $CurrentPath
        $CurrentPath = "$($CurrentPath)\$($Item)"
      }
      try{
        Write-Verbose "Testing $($Hive):\$($CurrentPath)"
        $testpath = Test-Path -path "$($Hive):\$($CurrentPath)" -erroraction stop
        if(!$testpath){
          Write-Host "Reg path $($Hive):\$($CurrentPath) not found, attempting to create $($Item) at $($Hive):\$($OldPath)" -ForegroundColor Green
          New-Item -Path "$($Hive):\$($OldPath)\" -Name $Item
        }
      }catch{
        Write-Host "Failed at $($Hive):\$($CurrentPath), attempting to create $($Item) at $($Hive):\$($OldPath)" -ForegroundColor Red
        New-Item -Path "$($Hive):\$($OldPath)\" -Name $Item
      } 
      $ItemNumber ++ 
    }

    try{
			#Get-Item -path "$($Hive):\$($Path)\$($Name)" -erroraction stop
			if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
  			Write-Verbose "$($Name) is already set to $($Value), no further action required."
			}else{
				#handle null values
        if(($null -like $Value) -or ($Value -eq "")){
          Clear-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop
          #check result of actions
          if( ($null -like ((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name)) -or (((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name) -eq "")){
            Write-Verbose "$($Name) succesfully set to NULL, no further action required."
          }else{
            Write-Host "Error setting $($Hive):\$($Path)\$($Name) to NULL, please remediate." -Foregroundcolor Red
          }
        }else{
          Set-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -Value $Value -Type $Type
          #check result of actions
          if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
            Write-Verbose "$($Name) succesfully set to $($Value), no further action required."
          }else{
            Write-Host "Error setting $($Hive):\$($Path)\$($Name) to $($Value), please remediate." -Foregroundcolor Red
          }
        }
			}
		}catch{

			Write-Host "Item $($Name) does not exist at $($Hive):\$($Path), attempting to create" -ForegroundColor Green
			#handle null values
			if(($null -like $RegSet.Value) -or ($RegSet.Value -eq "")){
			  try{
				  Clear-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop
  			}catch{
   			  $arguments = "add `"$($Hive)\$($Path)`" /f"
				  Start-Process reg.exe -ArgumentList $arguments -Wait

				  $arguments = "add `"$($Hive)\$($Path)`" /v $($Name) /t $($RegSet.Type) /ve /f"
				  Start-Process reg.exe -ArgumentList $arguments -Wait
        }
			}else{
				Set-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -Value $Value -Type $Type -ErrorAction Stop
			}
			
			try{
				if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
					Write-Verbose "$($Name) succesfully set to $($Value), no further action required."
				}else{
					Write-Host "Error setting $($Hive):\$($Path)\$($Name) to $($Value), please remediate." -Foregroundcolor Red
				}			
			}catch{
				$arguments = "add `"$($Hive)\$($Path)`" /f"
				Start-Process reg.exe -ArgumentList $arguments -Wait

				$arguments = "add `"$($Hive)\$($Path)`" /v $($Name) /t $($RegSet.Type) /d $($Value) /f"
				Start-Process reg.exe -ArgumentList $arguments -Wait
			}
		}		
	}
}

################### - End of Functions - ####################


#method 1 set registry entry to disable Windows FastBoot using native PowerShell
$RegSettings = @{
  "Comment" = "List of software installed by Chocolatey on this VM";
  "Name" = "HiberbootEnabled";
  "Value" = 0;
  "Path" = "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power";
  "Hive" = "HKEY_LOCAL_MACHINE";
  "Type" = "REG_DWORD"
}
set-reg_keys -RegSet @($RegSettings|convertto-json|convertfrom-json)

#method 2 using reg.exe
$arguments = "ADD HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power /v HiberbootEnabled /t REG_DWORD /d 0 /f"
Start-Process reg.exe -ArgumentList $arguments -Wait -ErrorAction stop