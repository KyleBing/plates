# Plates - License Plate Management App

A SwiftUI app for managing license plate images with local and cloud storage support.

## Features

- **Local Storage**: Images are saved locally for fast access
- **Cloud Storage**: Images are automatically backed up to iCloud using CloudKit
- **Cross-Device Sync**: Images persist across app installations and devices
- **Image Management**: Add, edit, and delete license plate images
- **Image Viewer**: Full-screen image viewing with zoom and brightness controls

## Cloud Storage Setup

### Requirements

1. **Apple Developer Account**: You need an Apple Developer account to use CloudKit
2. **iCloud Container**: The app uses the default iCloud container
3. **Entitlements**: CloudKit entitlements are already configured in `Plates.entitlements`

### How It Works

1. **Image Upload**: When you add a new image, it's saved both locally and to iCloud
2. **Image Loading**: The app tries to load from local storage first, then falls back to cloud storage
3. **Migration**: Existing local images are automatically uploaded to cloud storage on first launch
4. **Deletion**: Images are deleted from both local and cloud storage when removed

### CloudKit Schema

The app creates a `PlateImage` record type in CloudKit with the following fields:
- `imageAsset`: CKAsset containing the image data
- `filename`: Original filename for reference
- `uploadDate`: Timestamp of when the image was uploaded

## Usage

1. **Adding Images**: Tap the + button to add a new license plate image
2. **Viewing Images**: Tap on any item in the list to view the full image
3. **Editing**: Use the edit button in the image viewer to modify plate information
4. **Deleting**: Swipe left on any item in the list to delete it

## Technical Details

### Key Components

- `PlateItem.swift`: Data model with cloud storage integration
- `CloudStorageService.swift`: Handles all CloudKit operations
- `PlateViewModel.swift`: Manages data and coordinates local/cloud operations
- `PlateEditView.swift`: UI for adding/editing plate information
- `PlateDetailView.swift`: Full-screen image viewer
- `PlateListView.swift`: Main list view with migration handling

### Async Operations

All cloud operations are asynchronous to prevent UI blocking:
- Image upload/download
- Migration of existing data
- Loading images in list and detail views

### Error Handling

The app gracefully handles cloud storage errors:
- Falls back to local storage if cloud is unavailable
- Continues working offline
- Logs errors for debugging

## Privacy

- Images are stored in your private iCloud container
- Data is only accessible on your devices
- No data is shared with third parties

## Troubleshooting

If images aren't syncing:
1. Check that iCloud is enabled on your device
2. Ensure you're signed into iCloud with the same account
3. Check your internet connection
4. Verify that CloudKit is enabled in your Apple Developer account 