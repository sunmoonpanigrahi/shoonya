# Find with Sadhguru — Android app

Native Android app project for searching public content from official Isha and Sadhguru sources. Search and matching work offline using a small bundled starter catalog. The app checks for updates when opened, supports a manual refresh, and schedules a daily background refresh after a live catalog URL is configured.

## Live catalog

The bundled offline starter catalog contains 36 curated Isha Wisdom pages. The live catalog is generated from Isha's official sitemap and currently contains 4,008 pages. The app accepts refreshed JSON in the existing `catalog.json` format and only keeps article, video, and audio results whose URLs are on `https://isha.sadhguru.org/`.

The `.github/workflows/refresh-and-publish.yml` workflow crawls Isha's public sitemap daily and publishes the site plus `catalog.json` to GitHub Pages. Set GitHub Pages to use **GitHub Actions** as its build source. The catalog URL will be the resulting Pages address followed by `/catalog.json`.

The separate `.github/workflows/build-android.yml` workflow builds a preview APK and an Android App Bundle, then makes them downloadable as GitHub Actions artifacts. It derives the GitHub Pages catalog URL from the repository name, so no catalog secret is needed.

After the Pages address is known, configure it when building the app:

```text
CATALOG_URL=https://YOUR-ACCOUNT.github.io/YOUR-REPOSITORY/catalog.json
```

In Android Studio, open this `android-app` folder and add `CATALOG_URL` as a Gradle project property before creating the signed Android App Bundle. The workflow's release bundle is unsigned; sign it with your Play upload key before submitting. Do not ship a build while the property is blank: it will remain offline-only with the bundled snapshot.

The Android Gradle Plugin is pinned to 8.13.2 (Gradle 8.13, JDK 17) and targets API 36. New Google Play submissions require API 36 from August 31, 2026. See [Google Play's target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

## Sources and behavior

- Isha catalog records link to the original official Isha Wisdom pages. The app does not copy or host source media.
- Official profile buttons link to the previously verified Sadhguru YouTube, Instagram, Facebook, LinkedIn, and X profiles.
- Search results include a direct search in Sadhguru's official YouTube channel. YouTube records are not copied into this app's catalog. To list YouTube records inside the app requires an approved YouTube Data API setup and its API data refresh/deletion rules.
- The other social profiles are direct official links, not indexed search results. Adding their posts to the searchable catalog requires each platform's permitted official access and any account-owner authorization it requires.
- Voice search invokes Android's speech-recognition activity. The app does not request a raw microphone permission or save audio.
- The app is an independent discovery product and does not claim endorsement by Sadhguru or Isha Foundation.
- Review `../privacy-policy.html` and replace its contact placeholder before publishing. The final Play listing also needs the publisher's identity, support details, screenshots, and signed app bundle.

## Build setup

Open this folder in Android Studio with JDK 17 and Android SDK Platform 36 installed. The workspace currently has no Android SDK/JDK, so an APK or Play-ready Android App Bundle has not been built here.

