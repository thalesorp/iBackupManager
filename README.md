# iBackupManager

This tool offers a convenient way for iPhone and Windows PC users to organize and standardize their photo backups. It converts HEIC photos to JPG and inserts the date taken as a prefix in each file name, including MP4 and MOV files.


## 🔧 Dependencies

- [ImageMagick](https://github.com/ImageMagick/ImageMagick) command-line tool added to the system's PATH for converting images.
- [MediaInfo](https://github.com/MediaArea/MediaInfo) command-line tool added to the system's PATH for retrieving video metadata.
- Developed using PowerShell 7.3.4, but the minimum version required is uncertain.


## 🚀 Usage

```powershell
.\iBackupManager.ps1 [-Path <string>] [-VerboseLogging] [-MoveLivePhotos] [-Replace]
.\iBackupManager.ps1 [[-Path] <String>] [-Extension] <String> [-Replace] [-MoveLivePhotos] [-VerboseLogging] [<CommonParameters>]
```


## 🔑 Parameters

- `-Path <string>` (optional): Specifies the path to the directory containing the images to convert. If not provided, the current working directory is used.
- `-Extension <string>`: Inform the desired extension. All extensions that ImageMagick accept is allowed. See [ImageMagick repository](https://github.com/ImageMagick/ImageMagick) for more information.
- `-Replace` (optional):  Replaces the original files with the converted ones if specified.
- `-MoveLivePhotos` (optional):  Moves live photos to a subfolder named "Live Photos" if specified.
- `-VerboseLogging` (optional): Enables verbose logging, displaying step-by-step processing information during execution and storing it in an "ExecutionLog" text file.


## 💡 Detailed Execution

The script first moves live photos (if `-MoveLivePhotos` is passed) and then locates PNG and HEIC image files within the specified directory, converting them to JPEG format using ImageMagick. The converted files are saved in JPEG format. If there are multiple files with the same name, a "New" suffix is added to the file name to avoid overwriting existing files.

After the conversion, the original files are deleted if `-Replace` is present.

The script adds the date and time as prefix to all files based on their metadata:
- For images, the script retrieves the "Date taken" metadata property using `Windows Shell.Application COM object`;
- For videos, the script uses the MediaInfo command-line tool to extract the "Encoded_Date" metadata property and formats it accordingly.
The date prefix follows the format `yyyy-MM-dd_HH-mm_`.

**Note:** The script requires user confirmation before performing each action. However, you can use the `-Confirm` parameter to automate the process without further prompts.


## 🌟 Examples

1. Convert images in the current directory to JPG and prompt for confirmation at each step:
    ```powershell
    .\iBackupManager.ps1 -Extension "jpg"
    ```

2. Convert images in a specific directory, replace original files:
    ```powershell
    .\iBackupManager.ps1 -Path "C:\Images" -Extension "jpg" -Replace
    ```

3. Convert images in the current directory, enable CLI verbose logging, and store detailed processing information in a text file:
    ```powershell
    .\iBackupManager.ps1 -Extension "jpg" -VerboseLogging
    ```


## 📃 License

This code is licensed under the MIT license. See the file LICENSE in the project root for full license information.
