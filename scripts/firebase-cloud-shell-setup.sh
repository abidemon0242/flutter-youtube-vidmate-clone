#!/usr/bin/env bash
# Tube Arena Firebase bootstrap for Google Cloud Shell.
# Creates a separate Firebase project, registers the Android app,
# creates Firestore, deploys this repository's Firestore rules, and
# downloads the generated google-services.json into the Android app.
set -Eeuo pipefail

REPO="https://github.com/abidemon0242/flutter-youtube-vidmate-clone.git"
BRANCH="feature/complete-tube-arena"
PACKAGE_NAME="com.tubearena.app"
DISPLAY_NAME="Tube Arena"
REGION="asia-south1"
WORKDIR="$HOME/tube-arena-firebase-setup"

echo "=== Tube Arena Firebase setup ==="
echo "This creates a NEW Google Cloud/Firebase project."
echo "It does not touch your Abid's Web Studio Firebase project."
echo "No billing account will be attached by this script."
echo

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud is not installed. Open this in Google Cloud Shell."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed."
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Installing Firebase CLI..."
  npm install -g firebase-tools
fi

echo "Checking Google Cloud authorization..."
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo "Google Cloud login is required. A browser authorization step will open."
  gcloud auth login
fi

echo "Checking Firebase CLI authorization..."
if ! firebase projects:list >/dev/null 2>&1; then
  echo "Firebase login is required. Complete the browser authorization."
  firebase login --no-localhost
fi

echo
echo "Choose a globally unique Firebase project ID."
DEFAULT_ID="tube-arena-$(date +%y%m%d)-$((100000 + RANDOM % 900000))"
read -r -p "Project ID [$DEFAULT_ID]: " PROJECT_ID
PROJECT_ID="${PROJECT_ID:-$DEFAULT_ID}"

if ! [[ "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{5,29}$ ]]; then
  echo "ERROR: Invalid project ID. Use 6-30 lowercase letters, digits or hyphens; start with a letter."
  exit 1
fi

echo
echo "The following resources will be created:"
echo "  Firebase project: $PROJECT_ID"
echo "  Android package:  $PACKAGE_NAME"
echo "  Firestore region: $REGION"
echo
read -r -p "Type CREATE to authorize project creation and deployment: " CONFIRM
if [[ "$CONFIRM" != "CREATE" ]]; then
  echo "Cancelled. No project was created."
  exit 0
fi

mkdir -p "$WORKDIR"
if [[ -d "$WORKDIR/.git" ]]; then
  git -C "$WORKDIR" fetch origin "$BRANCH"
  git -C "$WORKDIR" checkout "$BRANCH"
  git -C "$WORKDIR" reset --hard "origin/$BRANCH"
else
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$WORKDIR"
fi
cd "$WORKDIR"

if [[ ! -f firebase.json || ! -f firestore.rules || ! -f android/app/build.gradle.kts ]]; then
  echo "ERROR: Expected Tube Arena Firebase files were not found in the repository."
  exit 1
fi

echo
echo "Creating Firebase project..."
firebase projects:create "$PROJECT_ID" --display-name "$DISPLAY_NAME"

echo
echo "Registering Android app ($PACKAGE_NAME)..."
APP_LOG="$(mktemp)"
if ! firebase apps:create ANDROID "$DISPLAY_NAME Android" \
  --package-name="$PACKAGE_NAME" --project="$PROJECT_ID" 2>&1 | tee "$APP_LOG"; then
  echo "Android app registration failed. The Firebase project may still exist."
  echo "Review the error above; rerunning this script with the same project ID may require cleanup."
  exit 1
fi

APP_ID="$(sed -nE 's/.*App ID:[[:space:]]*(1:[0-9]+:android:[[:alnum:]]+).*/\1/p' "$APP_LOG" | tail -n1)"
rm -f "$APP_LOG"

if [[ -z "$APP_ID" ]]; then
  echo "Could not automatically read the Android App ID from the CLI output."
  echo "Project created: $PROJECT_ID"
  echo "Open Firebase Console > Project settings > Your apps to inspect the Android app."
  exit 1
fi

echo
echo "Downloading Android Firebase configuration..."
firebase apps:sdkconfig ANDROID "$APP_ID" --project="$PROJECT_ID" \
  > android/app/google-services.json

if [[ ! -s android/app/google-services.json ]] || ! grep -q '"project_id"' android/app/google-services.json; then
  echo "ERROR: The downloaded google-services.json did not pass validation."
  exit 1
fi

echo
echo "Creating Firestore database in $REGION..."
if ! firebase firestore:databases:create "(default)" --location="$REGION" --project="$PROJECT_ID"; then
  echo "Firestore creation did not complete. Check Firebase Console for an existing database or region conflict."
  exit 1
fi

echo
echo "Deploying Firestore rules and indexes..."
firebase deploy --only firestore:rules,firestore:indexes --project="$PROJECT_ID"

echo
echo "=== Firebase bootstrap completed ==="
echo "Project ID: $PROJECT_ID"
echo "Android App ID: $APP_ID"
echo "Package name: $PACKAGE_NAME"
echo "Firebase config: $WORKDIR/android/app/google-services.json"
echo "Rules deployed: firestore.rules"
echo
echo "IMPORTANT: Google sign-in provider and Android SHA fingerprints still need to be enabled/added in Firebase Console."
echo "Do not publish or commit private service-account keys. google-services.json is client configuration, not a service-account key."
echo
echo "Try downloading the config to your device from Cloud Shell:"
if command -v cloudshell >/dev/null 2>&1; then
  cloudshell download "$WORKDIR/android/app/google-services.json" || true
else
  echo "Use the Cloud Shell file browser to download the file at the path shown above."
fi
