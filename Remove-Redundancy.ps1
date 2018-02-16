param(
[string]$LogFolder  = "C:\Win32\Win32Diff\Logs",
[string]$RS3Folder  = "C:\Win32\Win32Diff\Data\Redstone3\RS3_RELEASE",
[string]$DropFolder = "D:\Win32SharedDrop\Latest"
)

# Store time information of files or folders in specific folder(such as logfolder, 
# rs3folder or dropfoler) if files inside larger than 3.
$EntryTime = [Ordered]@{}

$Folders = @{"LogFolder" = $LogFolder; "RS3Folder" = $RS3Folder; "DropFolder" = $DropFolder}


# Determine if file number are more than three 
Function Get-Number($Path)
{
    if($Path -ne $Folders.LogFolder) #If is directory
    {
        return [System.IO.Directory]::GetDirectories($Path).Count
    }
    else #If is file
    {
        return [system.IO.Directory]::GetFiles($Path).Count
    }
}


# According to date modified under specific path
Function Get-LastWriteTime($Path)
{
    return ((Get-ItemProperty $Path).LastWriteTime).Ticks
}

# Get latest 3 in chronological order in $Directory if number is more than 3. Otherwise, ignore.
Function Sort-LastThree($Directory)
{
    # Get files/folders number in $Directory
    $Num = Get-Number $Directory

    if($Num -gt 3)
    {
        $Prompt = "|-Sorting files/folders in {0}" -f $Directory
        Write-Host $Prompt -ForegroundColor Green

        return (Get-EntryTime $Directory).GetEnumerator() | Sort-Object -Property @{Expression = "Value"; Descending=$false}   
    }
    else
    {
        $Prompt = "|-Files/floders Number is not more than 3 in {0}, not sorting" -f $Directory
        Write-Host $Prompt -ForegroundColor Green

        return $null
    }

}

#Get the ticks of every entry
Function Get-EntryTime([string]$Path)
{
    $temp = [Ordered]@{}

	switch ($Path)
	{
		{$Path -eq $Folders.RS3Folder} {
			foreach($directory in [System.IO.Directory]::GetDirectories($Path)) {$temp.$directory = Get-TimeFromXML "$directory\BuildInfo.xml"}; break}

		{$Path -eq $Folders.LogFolder} {
			foreach($file in [system.IO.Directory]::GetFiles($Path)) {$temp.$file = Get-LastWriteTime $file}; break}

		{$Path.Contains($Folders.DropFolder)} {
			foreach($directory in [System.IO.Directory]::GetDirectories($Path)) {$temp.$directory = Get-LastWriteTime $directory}; break}
    }
    return $temp
}

# Purge redundant
Function Clear-Redundant
{
    $keys = @()
    [System.Collections.ArrayList]$arraylist = $keys
    #Purge redundant
    if($EntryTime.Count -ne 0)
    {
        foreach($key in $EntryTime.GetEnumerator().Name)
        {
            $arraylist.Add($key) | Out-Null
        }
        for($i = 0; $i -lt ($arraylist.Count - 3); $i++)
        {
            $Prompt = "|-Removing {0}" -f $arraylist[$i]
            Write-Host $Prompt -ForegroundColor Green

            Remove-Item $arraylist[$i] -Recurse -Force -ErrorAction SilentlyContinue
        }
        $EntryTime.Clear()
    }
}

# Get time from the buildinfo.xml file
Function Get-TimeFromXML($Path)
{
	$XML = [XML](Get-Content $Path)
	return ([DateTime]($XML.BuildInfo.Time)).ticks
}

# Clear folders without BuildInfo.xml in RS3Folder
Function Clear-WithoutXML($Path)
{
	foreach($directory in [System.IO.Directory]::GetDirectories($Path)) 
	{
		if(!(Test-Path "$directory\BuildInfo.xml"))
		{
			$Prompt = "Due to BuildInfo.xml is not included in {0}, so removing it." -f $directory
			Write-Host $Prompt -ForegroundColor Green
			Remove-Item $directory -Recurse -Force -ErrorAction SilentlyContinue  # Remove directly this directory if not contain buildinfo.xml in folder
		}
	}
}


#################################### Main ####################################
foreach($name in $Folders.Keys)
{
    #Determine if these three folders are existed.
    if(Test-Path $Folders.$name)
    {
		$Prompt = "-Processing the folder {0}" -f $Folders.$name
        Write-Host $Prompt -ForegroundColor Green
		
        if($name -eq "RS3Folder")
		{
			# First clear the folders that not contain buildinfo.xml
			Clear-WithoutXML $Folders.$name
		}
		elseif($name -eq "DropFolder")
		{
			foreach($d in [System.IO.Directory]::GetDirectories($Folders.$name))
			{
				$EntryTime = Sort-LastThree $d
				Clear-Redundant
			}
			continue
		}

        # Get ordered $EntryTime 
        $EntryTime = Sort-LastThree $Folders.$name

        Clear-Redundant
    }
    else
    {
        $Prompt = "-{0} does not exist, please check!" -f $Folders.$name
        Write-Host $Prompt -ForegroundColor Red
        continue
    }

}

Write-Host "Finished all!" -ForegroundColor Green
###############################################################################