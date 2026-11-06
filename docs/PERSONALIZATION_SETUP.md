# Tube Arena personalization setup

## What is included

- Local activity tracking for searches, video opens, in-app watch duration, likes/dislikes, saves and skips.
- A lightweight, on-device interest profile and recommendation ranking.
- Public YouTube playlist import using the official YouTube Data API v3.
- Local privacy screen to inspect detected interests and clear stored activity.
- Imported playlist metadata is stored locally in the app's private documents directory.

## Enable public playlist import

The app deliberately does not scrape YouTube pages or extract private browser sessions. Public playlist metadata is fetched through YouTube Data API v3.

1. Create a Google Cloud project and enable **YouTube Data API v3**.
2. Create an API key and restrict it to the Android application package/signing certificate used for your release.
3. Build with the key supplied at compile time:

```bash
flutter build apk --release --dart-define=YOUTUBE_DATA_API_KEY=YOUR_RESTRICTED_API_KEY
```

Do not commit the key to the repository. The API key is a client-side identifier, not a user OAuth credential; restrict its API and Android application usage in Google Cloud Console. Private playlist access and personal watch/search history are not provided by this public-data flow.

## Recommendation data and privacy

Personalization is computed locally from activity generated inside Tube Arena and metadata from imported public playlists. The current prototype does not implement Google Sign-In, OAuth consent, cloud sync, or access to a user's private YouTube watch/search history. Those require a separately configured identity/OAuth flow and approved scopes. The app must not imply that accepting its Terms grants Google account access.
