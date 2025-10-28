# Gen-mod AI Assistant Instructions

## Project Overview
Gen-mod is a cross-platform tracker music conversion tool that converts legacy music modules (MOD, XM, IT, etc.) to FLAC files with proper metadata. The system supports both Windows (PowerShell + OpenMPT123) and Linux (Bash + XMP) workflows.

## Architecture & Key Components

### Cross-Platform Implementation
- **Windows**: `gen-mod.ps1` - Uses OpenMPT123.exe, FFmpeg, and Thimeo WatchCat for audio normalization
- **Linux**: `gen-mod.sh` - Uses XMP, normalize-audio, and FFmpeg for conversion
- **Bulk Processing**: `Bulk-convert.ps1` - Batch processing for existing CSV databases

### Core Workflow Pattern
1. **File Discovery**: Scan ingress directory for supported tracker modules
2. **Batch Management**: Auto-generate monthly batch folders (format: `TERN-{month}{year}-{increment}`)
3. **Conversion Pipeline**: Extract metadata → Convert to FLAC → Apply normalization → Move to organized folders
4. **Deduplication**: API validation against existing radio station database

## Critical Directory Structure (Windows)
```
C:\Projekt\Tools\OpenMPT\
├── Ingress/           # Input modules and organized output batches
├── Process/           # Working directory for conversions
├── Logdir/            # Timestamped logs
└── Process/Catdip/    # Thimeo WatchCat processing pipeline
    ├── Ready/         # Normalized output files
    └── Processed/     # WatchCat completion tracking
```

## Key Development Patterns

### Metadata Extraction & Tagging
- **Windows**: Uses OpenMPT123's `--info` flag to extract internal module metadata
- **Linux**: Parses XMP verbose output for module names and comments
- **Override System**: External artist/title files in `ArtistImport/` and `TitleImport/` directories
- **Album Convention**: `"OriginalName: {file} Imported: {date} ({batch})"`

### Error Handling & Logging
- Centralized `Logwrite()` function with timestamped console + file output
- Separate collections for processing errors (`$Errors`) and duplicates (`$Dups`)
- Graceful continuation on individual file failures
- CSV export of all processed tracks with success/failure status

### Platform-Specific Audio Processing
- **Amiga MOD files**: Force mono output (`--stereo 0` in OpenMPT123, `-m` in XMP)
- **Other formats**: Stereo preservation
- **Windows**: Two-stage process (OpenMPT123 → FFmpeg metadata → WatchCat normalization)
- **Linux**: Single-stage with normalize-audio integration

### API Integration
- `Read-exists()` function validates against radio station database
- Hardcoded Station ID and password-protected endpoints
- Duplicate detection prevents re-importing existing tracks

## Development Workflow Commands

### Windows Setup Requirements
```powershell
# Dependencies check
Get-Command openmpt123.exe, ffmpeg.exe
# Verify WatchCat service status
```

### Linux Setup Requirements
```bash
# Dependencies check  
which xmp normalize-audio ffmpeg id3v2
# Test module conversion
xmp sample.mod -o test.wav
```

### Common Development Tasks
- **Add new format support**: Extend file filtering in both scripts' main loops
- **Modify batch naming**: Update `$subfolderstem` (PS1) or date format logic (SH)
- **Change output paths**: Update hardcoded directory declarations section
- **API integration**: Modify `Read-exists()` function and endpoint URLs

## File Naming Conventions
- **Log files**: `{timestamp}_Log.txt`
- **Batch folders**: `TERN-{mmm}{yyyy}-{0n}` (e.g., `TERN-oct2025-01`)
- **Output structure**: `{batch}/{original_files}` and `{batch}/selected/{converted_flacs}`
- **CSV exports**: `tracklist-{batch}.csv`

## Testing & Debugging
- Monitor `Logdir` for detailed processing logs
- Check `resp.txt` for API response debugging
- Validate WatchCat processing by monitoring `Catdip/Ready/` directory
- Use `--force` flag in OpenMPT123 to override existing files during development