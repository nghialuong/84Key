#!/usr/bin/env python3
"""Insert one release <item> into the Sparkle appcast feed.

84Key hosts the appcast on GitHub Pages but serves the actual DMGs from GitHub
Releases (each release under its own tag URL). Sparkle's bundled
`generate_appcast` expects every archive to live in one directory and rewrites
all download URLs from a single prefix — and it *prunes* items whose archive is
absent. Neither fits our "DMG stays on GitHub Releases" model, so instead we
sign the new DMG with `sign_update` and splice a single <item> into the existing
feed here, preserving every prior item's own per-tag download URL.

Inputs (environment):
  APPCAST          path to appcast.xml to update (created if missing)
  DOWNLOAD_URL     full https URL of the DMG on GitHub Releases
  SHORT_VERSION    marketing version, e.g. "0.1.0" (CFBundleShortVersionString)
  BUILD_VERSION    CFBundleVersion — what Sparkle compares to decide "newer"
  MIN_SYSTEM       minimum macOS version, e.g. "14.0"
  SIG_ATTRS        raw output of `sign_update <dmg>`, i.e.
                   sparkle:edSignature="…" length="…"
  RELEASE_PAGE     URL of the GitHub release page (used as the item <link>)
  PUBDATE          RFC-822 date (optional; falls back to now in UTC)
  CHANNEL          optional Sparkle channel name (omitted for stable)

Re-running with a BUILD_VERSION already present replaces that item (idempotent).
"""

import os
import re
import sys
import datetime
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def env(name, required=True, default=None):
    val = os.environ.get(name, default)
    if required and not val:
        sys.exit(f"update_appcast: missing required env var {name}")
    return val


def parse_sig_attrs(raw):
    """Pull edSignature + length out of sign_update's output."""
    sig = re.search(r'sparkle:edSignature="([^"]+)"', raw)
    length = re.search(r'length="([^"]+)"', raw)
    if not sig or not length:
        sys.exit(f"update_appcast: could not parse SIG_ATTRS: {raw!r}")
    return sig.group(1), length.group(1)


def empty_feed():
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "84Key"
    ET.SubElement(channel, "link").text = "https://raw.githubusercontent.com/nghialuong/84Key/gh-pages/appcast.xml"
    ET.SubElement(channel, "description").text = "84Key — Vietnamese input method for macOS"
    ET.SubElement(channel, "language").text = "en"
    return ET.ElementTree(rss)


def load_feed(path):
    if path and os.path.exists(path) and os.path.getsize(path) > 0:
        return ET.parse(path)
    return empty_feed()


def sub(parent, tag, text=None, attrib=None):
    el = ET.SubElement(parent, tag, attrib or {})
    if text is not None:
        el.text = text
    return el


def main():
    appcast = env("APPCAST")
    download_url = env("DOWNLOAD_URL")
    short_version = env("SHORT_VERSION")
    build_version = env("BUILD_VERSION")
    min_system = env("MIN_SYSTEM")
    sig_attrs = env("SIG_ATTRS")
    release_page = env("RELEASE_PAGE", required=False, default="")
    channel = env("CHANNEL", required=False, default="")
    pubdate = os.environ.get("PUBDATE") or (
        datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    )

    ed_signature, length = parse_sig_attrs(sig_attrs)

    tree = load_feed(appcast)
    channel_el = tree.getroot().find("channel")
    if channel_el is None:
        sys.exit("update_appcast: feed has no <channel>")

    # Drop any existing item with the same build version so re-runs are idempotent.
    sparkle_version = f"{{{SPARKLE_NS}}}version"
    for item in list(channel_el.findall("item")):
        ver = item.find(sparkle_version)
        if ver is not None and (ver.text or "").strip() == build_version:
            channel_el.remove(item)

    item = ET.Element("item")
    sub(item, "title", f"Version {short_version}")
    if release_page:
        sub(item, "link", release_page)
    sub(item, f"{{{SPARKLE_NS}}}version", build_version)
    sub(item, f"{{{SPARKLE_NS}}}shortVersionString", short_version)
    sub(item, f"{{{SPARKLE_NS}}}minimumSystemVersion", min_system)
    if channel:
        sub(item, f"{{{SPARKLE_NS}}}channel", channel)
    sub(item, "pubDate", pubdate)
    sub(item, "enclosure", attrib={
        "url": download_url,
        "type": "application/octet-stream",
        f"{{{SPARKLE_NS}}}edSignature": ed_signature,
        "length": length,
    })

    # Newest first: insert above the first existing <item> (after channel metadata).
    first_item = channel_el.find("item")
    if first_item is not None:
        idx = list(channel_el).index(first_item)
        channel_el.insert(idx, item)
    else:
        channel_el.append(item)

    ET.indent(tree, space="  ")
    tree.write(appcast, encoding="UTF-8", xml_declaration=True)
    print(f"update_appcast: wrote {short_version} (build {build_version}) -> {appcast}")


if __name__ == "__main__":
    main()
