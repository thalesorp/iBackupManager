<#
.SYNOPSIS
Cmdlet that offers a convenient way for iPhone and Windows PC users to organize and standardize their photo backups.

.DESCRIPTION
Converts HEIC photos to a desired extension and inserts the date taken as a prefix in each file name, including MP4 and MOV files.

.PARAMETER Path
Specifies the path to the directory containing the images to convert. If not provided, the current working directory is used.

.PARAMETER Replace
If specified, the original files will be replaced with the new converted ones.

.PARAMETER Confirm
By using this parameter, all actions will be performed without further prompts or confirmations.

.PARAMETER Verbose
Enables verbose output, providing detailed information during the execution of the script.

.INPUTS
Accepts input from the pipeline.

.OUTPUTS
None.

.EXAMPLE
Convert images in the current directory and prompt for confirmation at each step:
.\iBackupManager.ps1

.EXAMPLE
Convert images in a specific directory, replace original files, and confirm all actions:
.\iBackupManager.ps1 -Path "C:\Images" -Replace -Confirm

.EXAMPLE
Convert images in the current directory, showing detailed information about the execution:
.\iBackupManager.ps1 -Verbose

.NOTES
Author: Thales Pinto
Version: 0.2.0
Licence: This code is licensed under the MIT license.
For more information, refer to the README.md file in the repository.
#>

[CmdletBinding()]

param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-Not (Test-Path -Path $_ -PathType Container)) { throw "Invalid path." }
        $true
    })]
    [string]$Path = $pwd,

    [Parameter(HelpMessage = "Enables verbose logging, capturing step-by-step processing information during script execution.")]
    [Switch]$VerboseLogging,

    [Parameter(HelpMessage = "Organizes live photos (.mov) by moving them to a subfolder.")]
    [Switch]$MoveLivePhotos,

    [Parameter(HelpMessage = "Replace the original files with the new converted ones.")]
    [Switch]$Replace,

    [Parameter(HelpMessage = "By using the prefix parameter, the date of the photo and video will be added to the file name.")]
    [Switch]$Prefix,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Specifies the extension to which images will be converted, accpeting any extension supported by Magick."
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ($(magick identify -list format | Select-String -Pattern $($_ -replace "^\.")) -eq $null) { throw "Invalid extension or Magick can't convert to it." }
        $true
    })]
    [string]$Extension
)

begin {

    <#
    .SYNOPSIS
    Presents a yes or no prompt to the user and returns their response.
    #>
    function Get-YesNo {
        Param (
            [Parameter(Mandatory = $true)][string]$Title,
            [Parameter(Mandatory = $true)][string]$Question
        )

        $Answer = $Host.UI.PromptForChoice($Title, $Question, @('&Yes', '&No'), 1)

        if ($Answer -eq 1) {
            return $false
        }
        return $true
    }

    <#
    .SYNOPSIS
    Writes a verbose message to the console and optionally logs it to a file.
    #>
    function Write-CustomVerbose {
        Param (
            [Parameter(Mandatory = $true)][string]$Message
        )
        if ($Global:Logging -eq $true) {
            Add-Content -Path $Global:ExecutionLogFile -Value $Message
        }
        Write-Verbose $Message
    }

    <#
    .SYNOPSIS
    Retrieves the date taken of an image file.
    #>
    Function Get-ImageDate {
        param (
            [string]$FilePath
        )

        $objFile = Get-Item $FilePath

        $objFolder = $(New-Object -ComObject Shell.Application).Namespace($objFile.Directory.FullName)
        $fileIndex = $objFolder.ParseName($objFile.Name)
        $FileMetaData = New-Object PSObject

        for ($a = 0; $a -le 266; $a++) {
            if ($objFolder.GetDetailsOf($objFolder.Items, $a)) {
                $propertyName = $objFolder.GetDetailsOf($objFolder.Items, $a)
                if ($propertyName -eq "Date taken") {
                    $DateTaken = $objFolder.GetDetailsOf($fileIndex, $a)
                    if ($DateTaken -eq "") {
                        return $null
                    }
                    $DateTaken = $DateTaken -replace "\u200e|\u200f|\u202a|\u202c", ""
                    $DatePrefix = $((Get-Date $DateTaken).ToString($Global:DateFormat))
                    return $DatePrefix
                }
            }
        }

        Write-Error "Problem acquiring `"$FilePath`" metadata."
        exit
    }

    <#
    .SYNOPSIS
    Retrieves the encoded date of a video file.
    #>
    Function Get-VideoDate {
        param (
            [string]$FilePath
        )

        $VideoMetadata = $(MediaInfo --Output=JSON $FilePath) | ConvertFrom-Json
        $DatePrefix = $VideoMetadata.media.track[0].Encoded_Date
        $DatePrefix = $([DateTime]::ParseExact($DatePrefix, "yyyy-MM-dd HH:mm:ss UTC", $null)).ToString($Global:DateFormat)
        return $DatePrefix
    }

    <#
    .SYNOPSIS
    Converts image files from the specified path to the JPEG format.
    #>
    function Convert-ImagesFiles {
        $Global:OriginalFiles = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in ".png", ".heic" }

        if ($Global:OriginalFiles.Count -eq 0) {
            Write-Error "There is no images to convert."
            exit
        }

        Write-CustomVerbose "Converting images..."

        $FinalFileNames = $Global:OriginalFiles.FullName | ForEach-Object { [System.IO.Path]::ChangeExtension($_, $Global:OutputExtension) }

        for ($i = 0; $i -lt $Global:OriginalFiles.Count; $i++) {

            # Testing if already have a file with the same name, and if so, append a "New" at the end of the file name.
            if ((Test-Path -Path $FinalFileNames[$i] -PathType Leaf) -eq $true) {
                $FinalFileNames[$i] = $($FinalFileNames[$i]).Replace(".$Global:OutputExtension", " - New.$Global:OutputExtension")
            }

            magick $Global:OriginalFiles[$i] $FinalFileNames[$i]
            Write-CustomVerbose "Converting image $($i+1) of $($Global:OriginalFiles.Count): `"$(Split-path $FinalFileNames[$i] -Leaf)`"."
        }

        Write-CustomVerbose "Images converted."
    }

    <#
    .SYNOPSIS
    Deletes the original image files that were converted.
    #>
    function Remove-OriginalFiles {
        Write-CustomVerbose "Deleting original images..."

        for ($i = 0; $i -lt $Global:OriginalFiles.Count; $i++) {
            Write-CustomVerbose "Deleting image $($i+1) of $($Global:OriginalFiles.Count): `"$($($Global:OriginalFiles[$i]).Name)`"."
            Remove-Item $Global:OriginalFiles[$i]
        }

        Write-CustomVerbose "Original files deleted."
    }

    <#
    .SYNOPSIS
    Adds a prefix to each file in the specified path based on the file's metadata.
    #>
    function Add-Prefix {
        $ImagesFiles = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -eq ".$Global:OutputExtension" }
        $VideoFiles = Get-ChildItem -Path $Path -File -Recurse | Where-Object { $_.Extension -in ".mp4", ".mov" }

        $Counter = 0
        $MaxCounter = $ImagesFiles.Count + $VideoFiles.Count

        Write-CustomVerbose "Adding prefix on each file..."

        ForEach ($Image in $ImagesFiles) {
            $Counter += 1
            $Prefix = Get-ImageDate $Image.FullName
            if ($Prefix -eq $null) {
                Write-CustomVerbose "Renaming file $Counter of $($MaxCounter): `"$($Image.Name)`" NOT RENAMED due to missing date on metadata."
                continue
            }
            $NewName = $Prefix + $Image.Name
            $NewFullName = Join-Path $Image.Directory $NewName
            Rename-Item $Image.FullName $NewFullName
            Write-CustomVerbose "Renaming file $Counter of $($MaxCounter): `"$NewName`"."
        }

        ForEach ($Video in $VideoFiles) {
            $Counter += 1
            $Prefix = Get-VideoDate $Video.FullName
            $NewName = $Prefix + $Video.Name
            $NewFullName = Join-Path $Video.Directory $($Prefix + $Video.Name)
            Rename-Item $Video.FullName $NewFullName
            Write-CustomVerbose "Renaming file $Counter of $($MaxCounter): `"$NewName`"."
        }

        Write-CustomVerbose "Added prefixes."
    }

    <#
    .SYNOPSIS
    Organizes live photos (.mov) by moving them to a subfolder.
    #>
    function Move-LivePhotos {
        param (
            [string]$DestinationFolder
        )

        $AllFiles = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in ".png", ".heic" }
        if ($AllFiles.Count -eq 0) {
            return
        }
        $PossibleMovFileNames = $AllFiles.FullName | ForEach-Object { [System.IO.Path]::ChangeExtension($_, "mov") }

        $Counter = 0

        $MovFilesToMove = @()
        ForEach ($file in $PossibleMovFileNames) {
            if (Test-Path -Path $file -PathType Leaf){
                $MovFilesToMove += $file
            }
        }

        $MaxCounter = $MovFilesToMove.Count

        if ($MaxCounter -eq 0) {
            Write-CustomVerbose "No live photos videos to move."
            return
        }

        Write-CustomVerbose "Moving live photos videos to: `"$DestinationFolder`"..."

        ForEach ($file in $MovFilesToMove) {
            $Counter += 1
            Move-Item -Path $file -Destination $DestinationFolder
            $FileName = Split-Path -Leaf $file
            Write-CustomVerbose "Moving file $Counter of $($MaxCounter): `"$FileName`"."
        }

        Write-CustomVerbose "Live photos moved."
    }
}

process {
    if (-Not ([System.IO.Path]::IsPathRooted($Path))) { $Path = Resolve-Path -Path $Path }
    $Global:DateFormat = "yyyy-MM-dd_HH-mm_"
    $Global:Logging = $false
    $Global:ExecutionLogFile = $null

    $Global:OutputExtension = $Extension -replace "^\."

    if ($PSBoundParameters.ContainsKey("VerboseLogging")) {
        $VerbosePreference = "Continue"
        $Global:Logging = $true
        $ExecutionLogFileName = "$(Get-Date -format $Global:DateFormat)ExecutionLog"
        $Global:ExecutionLogFile = Join-Path $Path "$ExecutionLogFileName.txt"
        New-Item $Global:ExecutionLogFile -Value "iBackupManager`n$ExecutionLogFileName`n" | Out-Null
    }

    if ($PSBoundParameters.ContainsKey("MoveLivePhotos")) {
        $LivePhotosFolder = Join-Path $Path "Live Photos"
        if (-Not (Test-Path -Path $LivePhotosFolder -PathType Container)) {
            New-Item $LivePhotosFolder -ItemType Directory | Out-Null
        }
        Move-LivePhotos $LivePhotosFolder
    }

    Convert-ImagesFiles

    if ($PSBoundParameters.ContainsKey("Replace")) {
        Remove-OriginalFiles
    }

    if ($PSBoundParameters.ContainsKey("Prefix")) {
        Add-Prefix
    }

}
