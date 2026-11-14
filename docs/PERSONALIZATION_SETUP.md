# Tube Arena feed and personalization

## Public data sources

- Public video search, Bangladesh regional metadata, and public playlist metadata use independently operated Invidious catalog instances.
- Public channel subscriptions use YouTube's public RSS feeds.
- Public channel handles can be resolved through the catalog before subscribing to RSS.
- Private playlists and private YouTube account data are not supported.
- **No YouTube Data API key is used or required.** No Google OAuth setup is needed for these public-data features.

Catalog instances are operated independently, so availability and response quality can vary. Search terms and public URLs are sent to the selected instance.

## Local personalization and privacy

Tube Arena can use in-app searches, video opens, watch duration, likes, saves, and skips to rank recommendations on the device. The app asks for consent before recording personalization activity. Users can inspect interests, turn personalization off, or clear locally stored activity in the personalization settings.

The current app does not implement Google Sign-In, cloud sync, or access to a user's private YouTube watch/search history. Accepting the app's personalization consent does not grant Google account access.
