# iBackupManager

This tool offers a convenient way for iPhone and Windows PC users to organize and standardize their photo backups. It converts HEIC photos to JPG and inserts the date taken as a prefix in each file name, including MP4 and MOV files.


## 🔧 Dependencies

- [ImageMagick](https://github.com/ImageMagick/ImageMagick) command-line tool added to the system's PATH for converting images.
- [MediaInfo](https://github.com/MediaArea/MediaInfo) command-line tool added to the system's PATH for retrieving video metadata.
- Developed using PowerShell 7.3.4, I'm uncertain about the minimum version required.


## 🚀 Usage

```powershell
.\iBackupManager.ps1 [-Path <string>] [-Replace] [-Confirm] [-Verbose]
```


## 🔑 Parameters

- `-Path <string>` (optional): Specifies the path to the directory containing the images to convert. If not provided, the current working directory is used.
- `-Replace` (optional): If specified, the original files will be replaced with the converted ones.
- `-Confirm` (optional): By using this parameter, all actions will be performed without further prompts or confirmations.
- `-Verbose` (optional): Enables verbose output, providing detailed information during the execution of the script.


## 💡 Detailed Execution

The script locates PNG and HEIC image files within the specified directory and converts them to JPEG format using ImageMagick. The converted files are saved in the JPEG format. If there are multiple files with the same name, a "New" suffix is added to the file name to avoid overwriting existing files.

After the conversion, the script offers an option to delete the original image files. If confirmed, the original files (PNG and HEIC) are permanently deleted from the specified directory.

The script adds the date as prefix to all files based on their metadata:
- For images, the script retrieves the "Date taken" metadata property using `Windows Shell.Application COM object`;
- For videos, the script uses the MediaInfo command-line tool to extract the "Encoded_Date" metadata property and formats it accordingly.
The date prefix follows the format `yyyy-MM-dd_HH-mm_`.

**Note:** The script requires user confirmation before performing each action. However, you can use the `-Confirm` parameter to automate the process without further prompts.


## 🌟 Examples

1. Convert images in the current directory and prompt for confirmation at each step:
    ```powershell
    .\iBackupManager.ps1
    ```

2. Convert images in a specific directory, replace original files, and confirm all actions:
    ```powershell
    .\iBackupManager.ps1 -Path "C:\Images" -Replace -Confirm
    ```

3. Convert images in the current directory, showing detailed information about the execution:
    ```powershell
    .\iBackupManager.ps1 -Verbose
    ```


## 📃 License

This code is licensed under the MIT license. See the file LICENSE in the project root for full license information.
