#!/bin/bash
# Quick setup script for GitHub Codespaces / Remote Linux
# Run this to automatically set up Flutter and the app

set -e

echo "🚀 Starting Tube Arena Setup..."

# Update system
echo "📦 Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev 2>/dev/null

# Download and install Flutter
echo "⬇️  Downloading Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
  cd ~
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:$HOME/flutter/bin"
if ! grep -q 'flutter/bin' ~/.bashrc; then
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
fi

# Verify Flutter
echo "✅ Verifying Flutter installation..."
flutter --version

# Navigate to project and get dependencies
echo "📥 Getting Flutter dependencies..."
cd ~/flutter-youtube-vidmate-clone 2>/dev/null || cd . 
flutter pub get

# Run doctor
echo "🏥 Running Flutter doctor..."
flutter doctor

echo ""
echo "✨ Setup complete!"
echo ""
echo "To run the app:"
echo "  flutter run -d chrome"
echo ""
echo "Or on a connected Android device:"
echo "  flutter run"
echo ""
