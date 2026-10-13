#!/usr/bin/env python3
"""Fix links between pages in the generated site."""

from __future__ import annotations

import argparse
import html
import posixpath
import re
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit, urlunsplit


HREF_ATTRIBUTE = re.compile(r"(?P<prefix>\bhref\s*=\s*)(?P<quote>[\"'])(?P<value>.*?)\2", re.IGNORECASE | re.DOTALL)
URL_SAFE = "/:@-._~!$&'()*+,;="


def page_route(path: Path, site: Path) -> str:
    """Return the directory-style public route for an HTML file."""
    relative = path.relative_to(site).as_posix()
    if relative == "index.html":
        return ""
    if relative.endswith("/index.html"):
        return relative[: -len("/index.html")]
    if relative.endswith(".html"):
        return relative[: -len(".html")]
    return relative


def route_from_link_path(path: str) -> str:
    route = posixpath.normpath(path)
    if route in ("", "."):
        return ""
    if route == "index.html":
        return ""
    if route.endswith("/index.html"):
        return route[: -len("/index.html")]
    if route.endswith(".html"):
        return route[: -len(".html")]
    return route.rstrip("/")


def fix_page_link(href: str, source_route: str, routes: set[str]) -> str:
    """Rebase an over-traversing local link when its intended page exists."""
    url = urlsplit(html.unescape(href))
    if url.scheme or url.netloc or not url.path or url.path.startswith("/"):
        return href

    target = route_from_link_path(posixpath.join(source_route, unquote(url.path)))
    if target in routes:
        return href

    candidate = target
    while candidate.startswith("../"):
        candidate = candidate[3:]
        if candidate in routes:
            target_route = candidate
            break
    else:
        target_route = ""

    if not target_route:
        basename = posixpath.basename(target.rstrip("/"))
        matches = [route for route in routes if route and posixpath.basename(route) == basename]
        if len(matches) != 1:
            return href
        target_route = matches[0]

    relative = posixpath.relpath(target_route or ".", start=source_route or ".")
    relative = "./" if relative == "." else relative.rstrip("/") + "/"
    path = quote(relative, safe=URL_SAFE)
    return urlunsplit(("", "", path, url.query, url.fragment))


def fix_page_links(source: str, source_route: str, routes: set[str]) -> tuple[str, int]:
    repaired = 0

    def replace_href(match: re.Match[str]) -> str:
        nonlocal repaired
        old_href = html.unescape(match.group("value"))
        new_href = fix_page_link(old_href, source_route, routes)
        if new_href == old_href:
            return match.group(0)
        repaired += 1
        return "{}{}{}{}".format(
            match.group("prefix"),
            match.group("quote"),
            html.escape(new_href, quote=True),
            match.group("quote"),
        )

    return HREF_ATTRIBUTE.sub(replace_href, source), repaired


def postprocess(site: Path) -> int:
    pages = sorted(site.rglob("*.html"))
    routes = {page_route(page, site) for page in pages}
    links = 0

    for page in pages:
        source = page.read_text(encoding="utf-8")
        source, repaired = fix_page_links(source, page_route(page, site), routes)
        if repaired:
            page.write_text(source, encoding="utf-8")
        links += repaired

    return links


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path, help="Generated Zensical site directory")
    args = parser.parse_args()
    if not args.site.is_dir():
        parser.error("site directory does not exist: {}".format(args.site))

    links = postprocess(args.site)
    print("Repaired {} internal page links.".format(links))


if __name__ == "__main__":
    main()
