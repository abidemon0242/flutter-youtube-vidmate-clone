# Tube Arena - Phone-Only Setup Guide (FREE)

This guide shows you how to build and run Tube Arena on your phone using only free tools.

## Method 1: GitHub Codespaces (Recommended - FREE)

### Step 1: Enable GitHub Codespaces
1. Go to: https://github.com/abidemon0242/flutter-youtube-vidmate-clone
2. Click the green **Code** button
3. Select **Codespaces** tab
4. Click **Create codespace on main**
5. Wait 2-3 minutes for the container to load

### Step 2: Install Flutter in Codespaces

Once Codespaces opens in your browser:

1. Click the **Terminal** at the bottom
2. Copy and paste these commands one by one:

```bash
# Update package manager
sudo apt-get update

# Install dependencies
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev

# Download Flutter SDK
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH
export PATH="$PATH:$HOME/flutter/bin"
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc

# Verify Flutter installation
flutter --version
```

### Step 3: Clone and Setup Project

```bash
# Navigate to project
cd ~/flutter-youtube-vidmate-clone

# Get dependencies
flutter pub get

# Run Flutter doctor
flutter doctor
```

### Step 4: Run the App

```bash
# Start Chrome browser for web (no Android emulator needed)
flutter run -d chrome
```

**This will open the app in a browser window inside Codespaces!**

### Step 5: View on Phone

1. Once the app is running, you'll see output like:
   ```
   Application running on http://localhost:59403
   ```

2. Click the **Ports** tab at the bottom of Codespaces
3. Find port `59403` or the port shown in your output
4. Right-click and select **Open in Browser**
5. This opens a public URL like: `https://xxxxx-tubearena.app.github.dev`
6. Open this URL on your phone's browser and the app runs!

---

## Method 2: Replit (Alternative - FREE)

### Step 1: Fork to Replit
1. Go to: https://replit.com
2. Click **Import from GitHub**
3. Paste: `https://github.com/abidemon0242/flutter-youtube-vidmate-clone`
4. Click **Import**
5. Wait for setup (2-3 minutes)

### Step 2: Run Setup Commands

In the Replit terminal:

```bash
# Install Flutter
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.13.0-stable.tar.xz
tar xf flutter_linux_3.13.0-stable.tar.xz
export PATH="$PATH:$PWD/flutter/bin"

# Get dependencies
flutter pub get

# Run web version
flutter run -d web
```

### Step 3: Open on Phone
1. Replit generates a public URL automatically
2. Share this link with your phone
3. Open the URL and use the app!

---

## Method 3: Gitpod (Alternative - FREE)

### Step 1: Open in Gitpod
1. Go to: https://gitpod.io/#https://github.com/abidemon0242/flutter-youtube-vidmate-clone
2. Sign in with GitHub
3. Click **Continue**
4. Wait for container to load

### Step 2: Install Flutter

```bash
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.13.0-stable.tar.xz
tar xf flutter_linux_3.13.0-stable.tar.xz
export PATH="$PATH:$PWD/flutter/bin"
flutter pub get
flutter run -d web
```

### Step 3: Access on Phone
Gitpod shows a public preview URL → open on your phone

---

## Method 4: Android Studio Remote (Android Phone Only)

If you have access to someone's Android Studio on a shared computer:

1. On the computer, run:
   ```bash
   flutter run
   ```
2. Connect your phone via USB with Developer Mode enabled
3. The app installs on your phone
4. You can then use it standalone

---

## Troubleshooting

### "flutter: command not found"
- Make sure you ran: `export PATH="$PATH:$HOME/flutter/bin"`
- Or add it permanently: `echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc`

### "Chrome not found"
- Chromium is usually pre-installed in Codespaces/Gitpod
- If missing, install: `sudo apt-get install -y chromium-browser`

### "Port blocked"
- The port may be in use; Codespaces auto-selects a new one
- Check the terminal output for the actual port number

### "Package not found"
- Run: `flutter pub get` again
- Or: `flutter clean && flutter pub get`

---

## What You Can Do Once Running

✅ Browse the YouTube-style home feed  
✅ View video cards with thumbnails  
✅ Tap videos to see the watch screen  
✅ View download quality options  
✅ Test batch selection (long-press video)  
✅ Explore the Downloads and Library tabs  
✅ Create/manage custom folders  

❌ *Real video downloading* (requires native Android/iOS)  
❌ *Real lock-screen controls* (web doesn't support)  
❌ *Real ad-blocking* (web doesn't support)  

---

## Next Steps (On a Real Machine)

Once you have access to a Windows/Mac/Linux computer:

```bash
# Clone the repo
git clone https://github.com/abidemon0242/flutter-youtube-vidmate-clone.git
cd flutter-youtube-vidmate-clone

# Install dependencies
flutter pub get

# Run on Android emulator or connected device
flutter run

# Build APK for distribution
flutter build apk --split-per-abi
```

---

## Free Resources

- **GitHub Codespaces**: 120 core-hours/month free  
- **Replit**: Free tier unlimited  
- **Gitpod**: 50 hours/month free  
- **Flutter Docs**: https://flutter.dev/docs  

---

**Recommended Path**: Use **GitHub Codespaces** → it's the easiest and most reliable for a phone-only user.
