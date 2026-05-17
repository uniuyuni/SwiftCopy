# SwiftCopy

SwiftCopy is a powerful and intuitive macOS utility for comparing and copying files between two directories. Built with SwiftUI, it offers a modern three-pane interface similar to Finder, allowing users to easily visualize differences and synchronize folders with intelligent date-based (or checksum-based) comparison logic.

## Features

### Core Functionality
- **Three-Pane Comparison**: Side-by-side view of Source, Status, and Destination columns.
- **Intelligent Comparison**: Automatically identifies files that need updating.
    - **Copy (->)**: Source file is newer or missing in destination.
    - **Skip (==)**: Files are identical.
    - **Newer in Dest (<-)**: Destination file is newer than source.
- **Checksum Comparison**: Optional SHA-256 hash-based comparison for byte-perfect accuracy (slower than date comparison).
- **Recursive Scanning**:
    - **Enabled**: Deeply scans all subfolders and includes them in the comparison/copy operation.
    - **Disabled**: Displays folder structure but only compares and copies files in the top-level directory.
- **Smart Selection**: Automatically selects only the files that need updating (add/update), with ancestor folders included automatically.
- **Forced Copy**: Manually selecting a file will force-copy it regardless of comparison status.

### User Interface
- **Drag & Drop**: Easily set Source and Destination paths by dragging folders onto the header buttons or the file list panes.
- **Search / Filter**: Filter the file list in real-time using the search field in the toolbar.
- **Expand / Collapse All**: Toggle all folder trees at once with the indent-list button in the column header.
- **Real-time Updates**: Changing settings (Overwrite Rules, Recursive Scan, Checksum Comparison, etc.) immediately re-scans without manual refresh.
- **Sortable Columns**: Sort files by Name, Date, or Size (click column headers; click again to reverse order).
- **Progress Tracking**: Visual progress bar with current file name, transfer speed (MB/s), and estimated time remaining.
- **Status Bar**: Shows source and destination item counts, plus the number of files to add and update.
- **Error Logging**: Detailed error log view for any issues encountered during the copy process.

### Finder Integration
- **Context Menu**: Right-click any folder in Finder to open it directly as the Source in SwiftCopy via the "Open with SwiftCopy" menu item (requires enabling the SwiftCopy Finder Extension in System Settings → Privacy & Security → Extensions → Finder Extensions).
- **URL Scheme**: Launch SwiftCopy and set the source folder programmatically using the custom URL scheme:
  ```
  swiftcopy://set-source?path=/path/to/folder
  ```
  SwiftCopy will open the folder as the Source and automatically prompt you to select a Destination.

### Command-Line Launch
You can launch SwiftCopy with pre-set folders from the terminal:
```bash
open -a SwiftCopy --args -source /path/to/source -dest /path/to/destination
```
- `-source <path>` — Sets the Source folder.
- `-dest <path>` (or `-target <path>`) — Sets the Destination folder.

If both are provided, scanning starts automatically. If only `-source` is provided, SwiftCopy prompts for a Destination on launch.

### Settings & Customization
- **Overwrite Rules**:
    - *If Newer* (Default): Only copies if the source file is newer.
    - *Always*: Replaces destination files regardless of date.
    - *Never*: Skips files that already exist in the destination.
- **Copy Hidden Files**: Toggle to include or exclude hidden files (e.g., `.git`, `.DS_Store`).
- **Recursive Scan**: Enable or disable deep directory traversal.
- **Preserve File Attributes**: Option to preserve original file modification and creation dates. When disabled, copied files receive the current timestamp.
- **Checksum Comparison (Slow)**: Uses SHA-256 hashing instead of modification dates for comparison.
- **Path Persistence**: Remembers your last used folders and settings between sessions.
- **Auto-Resolution**: If a saved folder path is missing, the app automatically navigates up to the nearest existing parent folder.

## Installation & Building

### Requirements
- macOS 12.0 or later
- Xcode 15+ (for building with the Finder Extension)

### Build via Xcode (Recommended)
1. Clone the repository.
2. Open `SwiftCopy.xcodeproj` in Xcode.
3. Select the `SwiftCopy` scheme and build/run.

### Build via Swift Package Manager (App only, no Finder Extension)
1. Clone the repository.
2. Run the following command to build the release version:
   ```bash
   swift build -c release
   ```
3. The executable will be located at `.build/release/SwiftCopy`.

## Usage

1. **Select Folders**:
   - Click **Source: Select** or drag a folder into the Source pane.
   - Click **Dest: Select** or drag a folder into the Destination pane.
   - Or right-click a folder in Finder and choose **Open with SwiftCopy**.
2. **Review Differences**:
   - The app automatically scans and compares files.
   - Status icons indicate whether each file needs to be added, updated, or is already up to date.
3. **Configure Settings** (Optional):
   - Open **SwiftCopy → Settings** (or ⌘,) to adjust Overwrite Rules, Recursive Scan, Checksum Comparison, etc.
4. **Select Files**:
   - Smart selection is applied automatically after scanning.
   - Click the checkmark icon in the header to toggle between Smart Select and Deselect All.
   - Manually check/uncheck individual files or folders.
5. **Copy**:
   - Click **Start Copy** to begin the operation.
   - The progress bar shows the current file, transfer speed, and estimated time remaining.
   - Any errors are surfaced via the error log button in the toolbar.

## Technical Details

- **Language**: Swift 5.9
- **Framework**: SwiftUI, AppKit, Combine, FinderSync
- **Architecture**: MVVM (Model-View-ViewModel)
- **Concurrency**: Background threads for scanning and copying to keep the UI responsive.
- **Extensions**: Finder Sync Extension for Finder context menu integration.
