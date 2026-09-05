#!/usr/bin/env python3
"""Scan release ZIP assets with VirusTotal and update the GitHub release body."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path


GITHUB_API = "https://api.github.com"
VIRUSTOTAL_API = "https://www.virustotal.com/api/v3"
REPORT_START = "<!-- virustotal-report:start -->"
REPORT_END = "<!-- virustotal-report:end -->"
POLL_SECONDS = 30
POLL_TIMEOUT_SECONDS = 30 * 60
MAX_UPLOAD_BYTES = 650 * 1024 * 1024
VT_MIN_REQUEST_INTERVAL_SECONDS = 16
_last_vt_request = 0.0


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required environment variable {name} is not set")
    return value


def json_request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: object | None = None,
    data: bytes | None = None,
) -> dict:
    request_headers = {"User-Agent": "mpv-anime-build-release-scanner"}
    if headers:
        request_headers.update(headers)
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        request_headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        url, data=data, headers=request_headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        safe_url = urllib.parse.urlsplit(url)._replace(query="", fragment="").geturl()
        raise RuntimeError(
            f"{method} {safe_url} returned HTTP {error.code}: {details[:1000]}"
        ) from error

    if not raw:
        return {}
    return json.loads(raw)


def github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def vt_headers(api_key: str) -> dict[str, str]:
    return {"x-apikey": api_key, "Accept": "application/json"}


def throttle_vt_request() -> None:
    """Stay within the default public API rate even when processing many assets."""
    global _last_vt_request
    elapsed = time.monotonic() - _last_vt_request
    if _last_vt_request and elapsed < VT_MIN_REQUEST_INTERVAL_SECONDS:
        time.sleep(VT_MIN_REQUEST_INTERVAL_SECONDS - elapsed)
    _last_vt_request = time.monotonic()


def download_asset(url: str, destination: Path) -> str:
    digest = hashlib.sha256()
    request = urllib.request.Request(
        url, headers={"User-Agent": "mpv-anime-build-release-scanner"}
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        with destination.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                digest.update(chunk)
    return digest.hexdigest()


def get_vt_file_report(sha256: str, api_key: str) -> dict | None:
    throttle_vt_request()
    request = urllib.request.Request(
        f"{VIRUSTOTAL_API}/files/{sha256}",
        headers={
            "User-Agent": "mpv-anime-build-release-scanner",
            **vt_headers(api_key),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"VirusTotal file lookup returned HTTP {error.code}: {details[:1000]}"
        ) from error


def upload_to_virustotal(path: Path, api_key: str) -> str:
    if path.stat().st_size > MAX_UPLOAD_BYTES:
        raise RuntimeError(f"{path.name} exceeds VirusTotal's 650 MB upload limit")

    throttle_vt_request()
    upload_response = json_request(
        f"{VIRUSTOTAL_API}/files/upload_url", headers=vt_headers(api_key)
    )
    upload_url = upload_response.get("data")
    if not isinstance(upload_url, str) or not upload_url.startswith("https://"):
        raise RuntimeError("VirusTotal did not return a valid large-file upload URL")

    boundary = f"----mpvAnimeBuild{uuid.uuid4().hex}"
    prefix = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        "Content-Type: application/zip\r\n\r\n"
    ).encode("utf-8")
    suffix = f"\r\n--{boundary}--\r\n".encode("ascii")

    # Release archives are currently small enough to submit in one request.
    body = prefix + path.read_bytes() + suffix
    throttle_vt_request()
    response = json_request(
        upload_url,
        method="POST",
        headers={
            **vt_headers(api_key),
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        data=body,
    )
    analysis_id = response.get("data", {}).get("id")
    if not analysis_id:
        raise RuntimeError("VirusTotal upload did not return an analysis ID")
    return analysis_id


def wait_for_analysis(analysis_id: str, api_key: str) -> None:
    deadline = time.monotonic() + POLL_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        throttle_vt_request()
        analysis = json_request(
            f"{VIRUSTOTAL_API}/analyses/{urllib.parse.quote(analysis_id, safe='')}",
            headers=vt_headers(api_key),
        )
        status = analysis.get("data", {}).get("attributes", {}).get("status")
        if status == "completed":
            return
        print(f"VirusTotal analysis status: {status or 'unknown'}; waiting...")
        time.sleep(POLL_SECONDS)
    raise RuntimeError("VirusTotal analysis did not complete within 30 minutes")


def markdown_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("`", "\\`").replace("|", "\\|")


def format_scan(asset_name: str, sha256: str, report: dict) -> str:
    attributes = report.get("data", {}).get("attributes", {})
    stats = attributes.get("last_analysis_stats", {})
    results = attributes.get("last_analysis_results", {})
    malicious = int(stats.get("malicious", 0))
    suspicious = int(stats.get("suspicious", 0))
    undetected = int(stats.get("undetected", 0))
    harmless = int(stats.get("harmless", 0))
    total = sum(int(value) for value in stats.values() if isinstance(value, int))
    analysis_timestamp = attributes.get("last_analysis_date")
    if analysis_timestamp:
        scanned = datetime.fromtimestamp(
            int(analysis_timestamp), tz=timezone.utc
        ).strftime("%Y-%m-%d %H:%M UTC")
    else:
        scanned = "Unavailable"

    report_url = f"https://www.virustotal.com/gui/file/{sha256}/detection"
    lines = [
        f"### `{markdown_escape(asset_name)}`",
        "",
        f"- **SHA-256:** `{sha256}`",
        f"- **Result:** **{malicious} malicious**, **{suspicious} suspicious**, "
        f"{undetected} undetected and {harmless} harmless out of {total} engine results",
        f"- **Scanned:** {scanned}",
        f"- **Report:** [View the complete VirusTotal analysis]({report_url})",
    ]

    detections = []
    for engine, result in sorted(results.items(), key=lambda item: item[0].lower()):
        if result.get("category") in {"malicious", "suspicious"}:
            label = result.get("result") or result.get("category")
            detections.append(
                f"  - **{markdown_escape(engine)}:** `{markdown_escape(str(label))}`"
            )
    if detections:
        lines.extend(["", "**Flagged engines:**", "", *detections])
    else:
        lines.extend(
            [
                "",
                "No participating engine classified this archive as malicious or suspicious.",
            ]
        )
    return "\n".join(lines)


def build_report(scans: list[str]) -> str:
    return "\n".join(
        [
            REPORT_START,
            "## 🛡️ Automated VirusTotal checks",
            "",
            "These results are generated automatically from the downloadable release ZIP. "
            "They provide scanner transparency but are not an absolute guarantee of safety.",
            "",
            "\n\n".join(scans),
            REPORT_END,
        ]
    )


def update_release_body(body: str, report: str) -> str:
    pattern = re.compile(
        rf"{re.escape(REPORT_START)}.*?{re.escape(REPORT_END)}", re.DOTALL
    )
    if pattern.search(body):
        return pattern.sub(report, body, count=1)
    if body.strip():
        return f"{body.rstrip()}\n\n---\n\n{report}\n"
    return f"{report}\n"


def main() -> int:
    repository = required_env("GITHUB_REPOSITORY")
    release_tag = required_env("RELEASE_TAG")
    github_token = required_env("GH_TOKEN")
    vt_api_key = required_env("VIRUSTOTAL_API_KEY")

    encoded_tag = urllib.parse.quote(release_tag, safe="")
    release_url = f"{GITHUB_API}/repos/{repository}/releases/tags/{encoded_tag}"
    release = json_request(release_url, headers=github_headers(github_token))
    assets = [
        asset
        for asset in release.get("assets", [])
        if asset.get("name", "").lower().endswith(".zip")
    ]
    if not assets:
        raise RuntimeError(
            f"Release {release_tag} has no ZIP asset to scan"
        )

    scans: list[str] = []
    with tempfile.TemporaryDirectory(prefix="mpv-anime-build-vt-") as temp_dir:
        for asset in assets:
            name = asset["name"]
            if Path(name).name != name:
                raise RuntimeError(f"Unsafe release asset name: {name}")
            path = Path(temp_dir, name)
            print(f"Downloading {name}...")
            sha256 = download_asset(asset["browser_download_url"], path)
            print(f"SHA-256: {sha256}")

            report = get_vt_file_report(sha256, vt_api_key)
            if report is None:
                print("No existing VirusTotal report; uploading the release asset...")
                analysis_id = upload_to_virustotal(path, vt_api_key)
                wait_for_analysis(analysis_id, vt_api_key)
                # Allow VirusTotal's file report to settle after analysis completion.
                time.sleep(POLL_SECONDS)
                report = get_vt_file_report(sha256, vt_api_key)
                if report is None:
                    raise RuntimeError("VirusTotal completed analysis but returned no file report")
            else:
                print("Using the existing VirusTotal report for this exact SHA-256.")

            scans.append(format_scan(name, sha256, report))

    generated_report = build_report(scans)
    updated_body = update_release_body(release.get("body") or "", generated_report)
    release_id = release["id"]
    json_request(
        f"{GITHUB_API}/repos/{repository}/releases/{release_id}",
        method="PATCH",
        headers=github_headers(github_token),
        payload={"body": updated_body},
    )
    print(f"Updated VirusTotal report in release {release_tag}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1)
