"""Build a searchable catalog from official Isha Wisdom sitemap pages.

Only public page metadata is indexed. Page bodies and media are not copied.
The crawler discovers sitemap URLs from the site's robots.txt and restricts
requests and result links to the official isha.sadhguru.org host.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import re
import sys
import threading
import time
import gzip
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urljoin, urlparse, urlsplit, urlunsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
ROBOTS_URL = "https://isha.sadhguru.org/robots.txt"
ALLOWED_HOST = "isha.sadhguru.org"
USER_AGENT = "FindWithSadhguruCatalog/0.1 (+public metadata index)"
MAX_SITEMAPS = 200
MAX_PAGES = 5000
REQUEST_DELAY_SECONDS = 0.2
PAGE_WORKERS = 8
_request_lock = threading.Lock()
_next_request_at = 0.0


class PageMetadata(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title = ""
        self.in_title = False
        self.meta: dict[str, str] = {}
        self.canonical = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs = [(key.lower(), value or "") for key, value in attrs]
        values = dict(attrs)
        if tag.lower() == "title":
            self.in_title = True
        elif tag.lower() == "meta":
            key = values.get("property") or values.get("name")
            content = values.get("content", "").strip()
            if key and content:
                self.meta[key.lower()] = content
        elif tag.lower() == "link" and "canonical" in values.get("rel", "").lower().split():
            self.canonical = values.get("href", "").strip()

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title += data


def fetch(url: str, timeout: int = 20) -> tuple[bytes, str]:
    global _next_request_at
    with _request_lock:
        wait = _next_request_at - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        _next_request_at = time.monotonic() + REQUEST_DELAY_SECONDS
    parsed = urlsplit(url)
    safe_url = urlunsplit((parsed.scheme, parsed.netloc, quote(parsed.path, safe="/%:@!$&'()*+,;=-._~%"), quote(parsed.query, safe="=&%:@!$'()*+,;/?-._~"), ""))
    request = Request(safe_url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,application/xml,*/*"})
    with urlopen(request, timeout=timeout) as response:
        body = response.read()
        if safe_url.lower().endswith(".gz") or response.headers.get("Content-Encoding", "").lower() == "gzip":
            body = gzip.decompress(body)
        return body, response.headers.get_content_type()


def official_url(url: str) -> bool:
    parsed = urlparse(url)
    return parsed.scheme == "https" and parsed.hostname == ALLOWED_HOST and not parsed.username


def sitemap_roots() -> list[str]:
    body, _ = fetch(ROBOTS_URL)
    found = []
    for line in body.decode("utf-8", "replace").splitlines():
        match = re.match(r"\s*sitemap:\s*(\S+)", line, flags=re.IGNORECASE)
        if match and official_url(match.group(1)):
            found.append(match.group(1))
    if not found:
        raise RuntimeError("robots.txt did not advertise an official Isha sitemap.")
    return list(dict.fromkeys(found))


def sitemap_pages(roots: list[str]) -> list[str]:
    pending = list(roots)
    seen_sitemaps: set[str] = set()
    pages: list[str] = []
    while pending and len(seen_sitemaps) < MAX_SITEMAPS and len(pages) < MAX_PAGES:
        sitemap = pending.pop(0)
        if sitemap in seen_sitemaps or not official_url(sitemap):
            continue
        seen_sitemaps.add(sitemap)
        try:
            body, _ = fetch(sitemap)
            root = ET.fromstring(body)
        except (HTTPError, URLError, TimeoutError, ET.ParseError) as exc:
            print(f"Skipping sitemap {sitemap}: {exc}", file=sys.stderr)
            continue
        for loc in root.iter():
            if loc.tag.rsplit("}", 1)[-1] != "loc" or not loc.text:
                continue
            url = loc.text.strip()
            if not official_url(url):
                continue
            path = urlparse(url).path.lower()
            if path.endswith(".xml") or path.endswith(".xml.gz"):
                if url not in seen_sitemaps:
                    pending.append(url)
            elif re.search(r"/wisdom/(article|video|audio)/", path):
                pages.append(url)
                if len(pages) >= MAX_PAGES:
                    break
        time.sleep(REQUEST_DELAY_SECONDS)
    return list(dict.fromkeys(pages))


def page_record(url: str) -> dict[str, str] | None:
    try:
        body, content_type = fetch(url)
        if "html" not in content_type:
            return None
    except (HTTPError, URLError, TimeoutError) as exc:
        print(f"Skipping page {url}: {exc}", file=sys.stderr)
        return None

    parser = PageMetadata()
    parser.feed(body.decode("utf-8", "replace"))
    canonical = urljoin(url, parser.canonical) if parser.canonical else url
    if not official_url(canonical):
        return None
    path = urlparse(canonical).path.lower()
    match = re.search(r"/wisdom/(article|video|audio)/", path)
    if not match:
        return None
    kind = match.group(1)
    title = (parser.meta.get("og:title") or parser.title).strip()
    description = (parser.meta.get("og:description") or parser.meta.get("description") or "").strip()
    if not title:
        return None
    title = re.sub(r"\s*[|–-]\s*(Sadhguru|Isha).*$", "", title, flags=re.IGNORECASE).strip()
    description = re.sub(r"\s+", " ", description)
    published = parser.meta.get("article:published_time", "")
    return {
        "type": kind,
        "title": title,
        "summary": description[:420],
        "url": canonical,
        "source": "Isha • Wisdom",
        "date": published[:10] if published else "",
        "tags": "",
        "terms": "",
    }


def main() -> int:
    cli = argparse.ArgumentParser(description="Index public metadata from official Isha Wisdom pages.")
    cli.add_argument("--limit", type=int, default=MAX_PAGES, help=f"Maximum sitemap pages to visit (default: {MAX_PAGES}).")
    args = cli.parse_args()
    if args.limit < 1:
        cli.error("--limit must be at least 1")
    print("Reading official sitemap references from Isha robots.txt…")
    pages = sitemap_pages(sitemap_roots())
    if not pages:
        raise RuntimeError("No Isha Wisdom article, video, or audio pages were found in the sitemap.")
    pages = pages[:args.limit]
    print(f"Found {len(pages)} official Wisdom pages to read; using {PAGE_WORKERS} workers…")
    records = []
    with ThreadPoolExecutor(max_workers=PAGE_WORKERS) as pool:
        for number, record in enumerate(pool.map(page_record, pages), start=1):
            if record:
                records.append(record)
            if number % 100 == 0:
                print(f"Read {number}/{len(pages)} pages; indexed {len(records)}")

    catalog = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "https://isha.sadhguru.org",
        "item_count": len(records),
        "items": records,
    }
    output = ROOT / "catalog.json"
    output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(records)} official metadata records to {output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (HTTPError, URLError, TimeoutError, RuntimeError) as exc:
        print(f"Catalog update failed: {exc}", file=sys.stderr)
        raise SystemExit(1)

