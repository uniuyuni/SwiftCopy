# SwiftCopy

SwiftCopy is a powerful and intuitive macOS utility for comparing and copying files between two directories. Built with SwiftUI, it offers a modern two-pane interface similar to Finder, allowing users to easily visualize differences and synchronize folders with intelligent date-based comparison logic.

## Features

### Core Functionality
- **Two-Pane Comparison**: Side-by-side view of Source and Destination folders.
- **Intelligent Comparison**: Automatically identifies files that need updating based on modification dates.
    - **Copy (->)**: Source file is newer or missing in destination.
    - **Skip (==)**: Files are identical.
    - **Newer in Dest (<-)**: Destination file is newer than source.
- **Recursive Scanning**:
    - **Enabled**: Deeply scans all subfolders and includes them in the comparison/copy operation.
    - **Disabled**: Displays folder structure but only compares and copies files in the top-level directory.
- **Smart Selection**: Quickly select only the files that need updating ("Smart Select") or toggle all files.

### User Interface
- **Drag & Drop**: Easily set Source and Destination paths by dragging folders onto the window.
- **Real-time Updates**: Changing settings (like Overwrite Rules or Recursive Scan) immediately reflects in the file list without manual refreshing.
- **Sortable Columns**: Sort files by Name, Date, or Size.
- **Progress Tracking**: Visual progress bar and status updates during copy operations.
- **Error Logging**: Detailed error log view for any issues encountered during the copy process.

### Settings & Customization
- **Overwrite Rules**:
    - *Overwrite if Newer* (Default): Only copies if the source file is newer.
    - *Always Overwrite*: Replaces destination files regardless of date.
    - *Never Overwrite*: Skips files that already exist in the destination.
- **Copy Hidden Files**: Toggle to include or exclude hidden files (e.g., `.git`, `.DS_Store`).
- **Preserve Attributes**: Option to preserve original file modification and creation dates.
- **Path Persistence**: Remembers your last used folders and settings between sessions.
- **Auto-Resolution**: If a saved folder path is missing, the app automatically navigates up to the nearest existing parent folder.

## Installation & Building

### Requirements
- macOS 12.0 or later
- Xcode 15+ (for building)

### Build Instructions
1. Clone the repository.
2. Open the project directory in a terminal.
3. Run the following command to build the release version:
   ```bash
   swift build -c release
   ```
4. The executable will be located in `.build/release/SwiftCopy`.
5. Alternatively, open the project in Xcode and run the `SwiftCopy` scheme.

## Usage

1. **Select Folders**:
   - Click "Select..." or drag a folder into the **Source** pane (Left).
   - Click "Select..." or drag a folder into the **Destination** pane (Right).
2. **Review Differences**:
   - The app will automatically scan and compare files.
   - Icons indicate the status of each file.
3. **Configure Settings** (Optional):
   - Click the "Settings" button (Gear icon) to adjust Overwrite Rules, Recursive Scan, etc.
4. **Select Files**:
   - Use the checkbox in the header to "Smart Select" all copyable files.
   - Or manually check/uncheck specific files.
5. **Copy**:
   - Click the "Copy to Destination" button to start the operation.
   - Wait for the progress bar to complete.

## Technical Details

- **Language**: Swift 5.9
- **Framework**: SwiftUI, AppKit, Combine
- **Architecture**: MVVM (Model-View-ViewModel)
- **Concurrency**: Background threads for scanning and copying to ensure a responsive UI.
