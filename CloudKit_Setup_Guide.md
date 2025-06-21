# CloudKit Setup Guide for Plates App

## Issue Resolution

The "Server Rejected Request" error indicates that CloudKit is not properly configured. Follow these steps to resolve the issue:

## Step 1: Apple Developer Account Setup

1. **Sign in to Apple Developer Portal**
   - Go to [developer.apple.com](https://developer.apple.com)
   - Sign in with your Apple Developer account

2. **Enable CloudKit**
   - Navigate to "Certificates, Identifiers & Profiles"
   - Select "Identifiers" from the left sidebar
   - Find your app's identifier (com.taiwuict.Plates)
   - Click on it to edit

3. **Configure CloudKit Container**
   - Scroll down to "CloudKit" section
   - Check the box to enable CloudKit
   - Click "Configure" next to CloudKit
   - Create a new container or select existing one
   - Container ID should be: `iCloud.com.taiwuict.Plates`

## Step 2: Xcode Project Configuration

1. **Update Bundle Identifier**
   - Open your Xcode project
   - Select the project in the navigator
   - Select your target
   - In "General" tab, ensure Bundle Identifier matches: `com.taiwuict.Plates`

2. **Verify Entitlements**
   - Check that `Plates.entitlements` contains:
   ```xml
   <key>com.apple.developer.icloud-container-identifiers</key>
   <array>
       <string>iCloud.com.taiwuict.Plates</string>
   </array>
   <key>com.apple.developer.icloud-services</key>
   <array>
       <string>CloudKit</string>
   </array>
   ```

3. **Team and Signing**
   - Ensure you're signed in with the correct Apple Developer account
   - Select the correct team for signing
   - Verify the provisioning profile includes CloudKit entitlements

## Step 3: CloudKit Dashboard Configuration

1. **Access CloudKit Dashboard**
   - Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard/)
   - Select your container: `iCloud.com.taiwuict.Plates`

2. **Create Schema**
   - Go to "Schema" tab
   - Create a new Record Type called "PlateImage"
   - Add fields:
     - `imageAsset` (Type: Asset)
     - `filename` (Type: String)
     - `uploadDate` (Type: Date/Time)

3. **Set Permissions**
   - In "Schema" tab, select "PlateImage" record type
   - Set "World" permissions to "None" (private data)
   - Set "Authenticated" permissions to "Read/Write"

## Step 4: Device/Simulator Setup

1. **iCloud Sign-in**
   - Ensure the device/simulator is signed into iCloud
   - Go to Settings > Apple ID > iCloud
   - Enable iCloud Drive
   - Enable CloudKit for your app

2. **Network Requirements**
   - Ensure device has internet connection
   - CloudKit requires HTTPS connections

## Step 5: Testing

1. **Clean Build**
   - In Xcode: Product > Clean Build Folder
   - Delete app from device/simulator
   - Rebuild and install

2. **Check Logs**
   - Monitor Xcode console for CloudKit availability messages
   - Look for "CloudKit is available for user" message

## Troubleshooting

### Common Issues:

1. **"Server Rejected Request"**
   - Verify CloudKit is enabled in Apple Developer Portal
   - Check container ID matches exactly
   - Ensure proper entitlements

2. **"Not Authenticated"**
   - Sign into iCloud on device
   - Check iCloud Drive is enabled
   - Verify app has CloudKit permission

3. **"Quota Exceeded"**
   - Check iCloud storage space
   - Free up space if needed

4. **Network Issues**
   - Ensure stable internet connection
   - Check firewall settings
   - Try on different network

### Alternative Solutions:

If CloudKit setup is complex, the app will work with local storage only:
- Images are saved locally for immediate access
- App functions normally without cloud sync
- Data persists between app launches (but not reinstalls)

## Verification

After setup, you should see:
- No "Server Rejected Request" errors
- "CloudKit is available for user" message in console
- Images upload to cloud successfully
- iCloud sync indicator in app

## Support

If issues persist:
1. Check Apple Developer account status
2. Verify CloudKit container configuration
3. Test with a fresh app installation
4. Contact Apple Developer Support if needed 