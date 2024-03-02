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
Convert images in the current directory to JPG and prompt for confirmation at each step:
.\iBackupManager.ps1 -Extension "jpg"

.EXAMPLE
Convert images in a specific directory, replace original files:
.\iBackupManager.ps1 -Path "C:\Images" -Extension "jpg" -Replace

.EXAMPLE
Convert images in the current directory, enable CLI verbose logging, and store detailed processing information in a text file:
.\iBackupManager.ps1 -Extension "jpg" -VerboseLogging

.NOTES
Author: Thales Pinto
Version: 0.2.1
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

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Specifies the extension to which images will be converted, accpeting any extension supported by Magick."
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ($(magick identify -list format | Select-String -Pattern $($_ -replace "^\.")) -eq $null) { throw "Invalid extension or Magick can't convert to it." }
        $true
    })]
    [string]$Extension,

    [Parameter(HelpMessage = "Replace the original files with the new converted ones.")]
    [Switch]$Replace,

    [Parameter(HelpMessage = "Organizes live photos (.mov) by moving them to a subfolder.")]
    [Switch]$MoveLivePhotos,

    [Parameter(HelpMessage = "Enables verbose logging, capturing step-by-step processing information during script execution.")]
    [Switch]$VerboseLogging
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
        $files = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in ".heic", ".png", ".jpg", ".mp4", ".mov" }

        $Counter = 0

        Write-CustomVerbose "Adding prefix on each file..."

        ForEach ($file in $files) {
            $Counter += 1

            if (".heic", ".png", ".jpg" -contains $file.Extension) {
                $prefix = Get-ImageDate $file.FullName
            }
            if (".mp4", ".mov" -contains $file.Extension) {
                $prefix = Get-VideoDate $file.FullName
            }

            if ($prefix -eq $null) {
                Write-CustomVerbose "Renaming file $Counter of $($files.Count): `"$($file.Name)`" NOT RENAMED due to missing date on metadata."
                continue
            }

            $newName = $prefix + $file.Name
            $newFullName = Join-Path $file.Directory $newName
            Rename-Item $file.FullName $newFullName
            Write-CustomVerbose "Renaming file $Counter of $($files.Count): `"$newName`"."
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

        $files = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -eq ".mov" }
        if ($files.Count -eq 0) {
            Write-CustomVerbose "No live photos videos to move."
            return
        }

        Write-CustomVerbose "Moving live photos videos to: `"$DestinationFolder`"..."

        ForEach ($file in $files) {
            $Counter += 1
            Move-Item -Path $file -Destination $DestinationFolder
            Write-CustomVerbose "Moving file $Counter of $($files.Count): `"$(Split-Path -Leaf $file)`"."
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

    Add-Prefix

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


}
