# Find with Sadhguru

A standalone website prototype for discovering public Sadhguru content from official Isha sources.

## Open it

The page needs to be served over HTTP to load the full generated catalog. From the repository root, run:

```powershell
python -m http.server 8000
```

Then open `http://localhost:8000`. If you open `index.html` directly as a file, the browser cannot fetch `catalog.json` and will show only the small fallback sample.

## What works in this prototype

- Text search with basic relevance scoring and related-term matching.
- Voice input in browsers that support the Web Speech Recognition API. The browser may ask for microphone access after the visitor presses the microphone button.
- Filters for videos, articles, and audio.
- Results that link directly to the original official Isha/Sadhguru pages and the verified Sadhguru YouTube channel.
- Direct profile links for the official Sadhguru YouTube, Instagram, Facebook, LinkedIn, and X accounts, verified through Isha's [official digital handles directory](https://isha.sadhguru.org/en/official-digital-handles).
- A generated catalog of 4,008 public Isha Wisdom article, video and audio pages, loaded by the page when served over HTTP.
- An ingestion script that reads sitemap references from Isha's `robots.txt`, visits only official Isha Wisdom pages, and writes title/description metadata to `catalog.json`.

## Current scope

The embedded catalog is a small fallback sample. The generated `catalog.json` currently contains 4,008 pages, including 67 whose indexed title, summary or tags mention soil. Run `python ingest_catalog.py` to build or refresh the Isha Wisdom index. The script uses only Python's standard library, follows sitemap URLs published by the official site's `robots.txt`, limits its crawl to Isha Wisdom article/video/audio paths, and stores public page metadata rather than page bodies or media. The browser verifies that loaded results link to the official Isha host.

YouTube appears as a direct search link into the official Sadhguru channel. The YouTube Data API's current policies restrict public aggregation of API data and require non-authorized data to be refreshed or deleted within 30 days. A public cross-source index should therefore not silently collect and combine YouTube API records; a fuller integration needs an approach approved for the channel/content owner and YouTube's terms. See the [YouTube Data API search documentation](https://developers.google.com/youtube/v3/docs/search/list) and [Developer Policies](https://developers.google.com/youtube/terms/developer-policies).

For production, the GitHub Actions workflow refreshes the Isha index daily and publishes the website and `catalog.json` through GitHub Pages. The website does not copy or host source media. See `android-app/README.md` for the Android app setup and publication prerequisites.

