#!/usr/bin/env python3
"""Export and batch-check the bundled WakeUp school library.

Examples:
    python tool/school_library.py export
    python tool/school_library.py check --concurrency 16 --timeout 12
    python tool/school_library.py check --include-unsupported --resume
    python tool/school_library.py check --retry-failed
    python tool/school_library.py check --retry-failed --only-category ssl_error,timeout
    python tool/school_library.py all --include-unsupported

Supported type sets and URL overrides are read from
lib/features/timetable/import/data/wakeup_school_repository.dart so the report
always matches the shipping app. Output defaults to build/school_library/.

The batch check is intentionally a separate command: run it yourself and let it
finish in the background. Results are written incrementally, so --resume can
continue an interrupted run.
"""

from __future__ import annotations

import argparse
import csv
import ipaddress
import json
import re
import socket
import ssl
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

DEFAULT_ASSET = Path("assets/wakeup_schools.json")
DEFAULT_DART_SOURCE = Path(
    "lib/features/timetable/import/data/wakeup_school_repository.dart"
)
DEFAULT_OUT_DIR = Path("build/school_library")
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
BLOCKED_STATUSES = {401, 403, 405, 406, 407, 412, 418, 420, 421, 429, 451, 468, 483, 488}
FAILED_CATEGORIES = ("client_error", "blocked", "server_error", "timeout", "ssl_error", "network_error")

FAMILY_LABELS = {
    "zhengfang": "正方",
    "qiangzhi": "强智",
    "qingguo": "青果",
    "chengfang": "乘方",
    "jinzhi": "金智",
    "shuweiMtt": "树维",
    "shuweiEams": "树维",
    "urp": "URP",
    "chaoxing": "超星",
}
FAMILY_ORDER = (
    "zhengfang",
    "qiangzhi",
    "qingguo",
    "chengfang",
    "jinzhi",
    "shuweiMtt",
    "shuweiEams",
    "urp",
    "chaoxing",
)

EXPORT_COLUMNS = [
    "name",
    "initial",
    "type",
    "type_label",
    "family",
    "can_import",
    "url",
    "scheme",
    "host",
]

CHECK_COLUMNS = [
    "school_names",
    "school_count",
    "families",
    "types",
    "url",
    "host_kind",
    "category",
    "ok",
    "http_status",
    "method",
    "final_url",
    "elapsed_ms",
    "error",
]


@dataclass
class DartConfig:
    type_sets: dict[str, set[str]]
    url_overrides: dict[str, str]


@dataclass
class SchoolRow:
    name: str
    initial: str
    type: str
    type_label: str
    family: str
    can_import: bool
    url: str
    scheme: str
    host: str


@dataclass
class CheckTarget:
    url: str
    names: list[str] = field(default_factory=list)
    families: set[str] = field(default_factory=set)
    types: set[str] = field(default_factory=set)
    internal: bool = False

    def add(self, school: SchoolRow) -> None:
        if school.name not in self.names:
            self.names.append(school.name)
        if school.family:
            self.families.add(school.family)
        if school.type:
            self.types.add(school.type)


@dataclass
class ProbeResult:
    url: str
    category: str
    ok: bool
    status: int | None
    method: str
    final_url: str
    elapsed_ms: int
    error: str


def parse_dart_config(path: Path) -> DartConfig:
    text = path.read_text(encoding="utf-8")
    type_sets: dict[str, set[str]] = {}
    for match in re.finditer(
        r"const Set<String>\s+_(\w+)Types\s*=\s*\{(.*?)\};",
        text,
        re.DOTALL,
    ):
        type_sets[match.group(1)] = set(re.findall(r"'([^']*)'", match.group(2)))

    missing = {"zhengfang", "qingguo", "urp", "chaoxing"} - set(type_sets)
    if missing:
        raise SystemExit(
            f"ERROR: could not read type sets {sorted(missing)} from {path}; "
            "the Dart source layout changed."
        )

    overrides: dict[str, str] = {}
    override_match = re.search(
        r"const Map<String, String>\s+_schoolUrlOverrides\s*=\s*\{(.*?)\};",
        text,
        re.DOTALL,
    )
    if override_match:
        overrides = dict(
            re.findall(r"'([^']*)'\s*:\s*'([^']*)'", override_match.group(1))
        )

    return DartConfig(type_sets=type_sets, url_overrides=overrides)


def normalize_url(raw: object) -> str | None:
    value = str(raw or "").strip()
    if not value:
        return None
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", value):
        value = f"https://{value}"

    try:
        parsed = urllib.parse.urlsplit(value)
    except ValueError:
        return None
    if parsed.scheme not in ("http", "https"):
        return None
    if not parsed.hostname:
        return None
    if parsed.username or parsed.password:
        return None
    return value


def family_for_type(type_name: str, config: DartConfig) -> str | None:
    if type_name.startswith("qz") or type_name == "jlict_qz_old":
        return "qiangzhi"
    for family in FAMILY_ORDER:
        if type_name in config.type_sets.get(family, set()):
            return family
    return None


def type_label(type_name: str, family: str | None) -> str:
    if family:
        return FAMILY_LABELS[family]
    if type_name.startswith("qz") or type_name == "jlict_qz_old":
        return "强智"
    if type_name == "kingo_new":
        return "青果"
    if type_name == "jz":
        return "金智"
    if type_name.startswith("shuwei") or "_shuwei" in type_name:
        return "树维"
    if type_name in ("cf", "cf_new"):
        return "乘方"
    if type_name == "south_soft":
        return "南软"
    return type_name or "未知"


def load_schools(asset_path: Path, config: DartConfig) -> tuple[list[SchoolRow], dict]:
    raw = json.loads(asset_path.read_text(encoding="utf-8-sig"))
    data = raw.get("data") if isinstance(raw, dict) else None
    if not isinstance(data, list):
        raise SystemExit(f"ERROR: {asset_path} does not contain a 'data' list.")

    schools: list[SchoolRow] = []
    skipped: list[dict[str, str]] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        raw_url = config.url_overrides.get(name, item.get("url"))
        url = normalize_url(raw_url)
        if not name or url is None:
            skipped.append(
                {
                    "name": name,
                    "type": str(item.get("type") or "").strip(),
                    "url": str(item.get("url") or "").strip(),
                }
            )
            continue

        sort_key = str(item.get("sortKey") or "").strip()
        initial = sort_key.upper() if re.fullmatch(r"[A-Za-z]", sort_key) else "#"
        type_name = str(item.get("type") or "").strip()
        family = family_for_type(type_name, config)
        parsed = urllib.parse.urlsplit(url)
        schools.append(
            SchoolRow(
                name=name,
                initial=initial,
                type=type_name,
                type_label=type_label(type_name, family),
                family=family or "",
                can_import=family is not None,
                url=url,
                scheme=parsed.scheme,
                host=parsed.hostname or "",
            )
        )

    schools.sort(
        key=lambda row: (
            1 if row.initial == "#" else 0,
            row.initial,
            row.name,
        )
    )
    meta = {key: raw.get(key) for key in ("format", "version", "source", "sourceUrl", "count")}
    meta["skipped_invalid"] = skipped
    return schools, meta


def write_csv(path: Path, columns: list[str], rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    tmp.replace(path)


def build_summary(schools: list[SchoolRow], meta: dict, asset_path: Path) -> dict:
    importable = [row for row in schools if row.can_import]
    by_family: Counter[str] = Counter(row.family for row in importable)
    by_type: Counter[str] = Counter(row.type or "(empty)" for row in schools)
    by_label: Counter[str] = Counter(row.type_label for row in schools)

    name_counts = Counter(row.name for row in schools)
    url_counts = Counter(row.url for row in schools)
    duplicate_names = {
        name: count for name, count in name_counts.items() if count > 1
    }
    duplicate_urls = {
        url: count for url, count in url_counts.items() if count > 1
    }

    return {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "asset": str(asset_path),
        "asset_meta": {key: value for key, value in meta.items() if key != "skipped_invalid"},
        "counts": {
            "total": len(schools),
            "importable": len(importable),
            "unsupported": len(schools) - len(importable),
            "duplicate_names": len(duplicate_names),
            "duplicate_urls": len(duplicate_urls),
            "skipped_invalid": len(meta.get("skipped_invalid", [])),
        },
        "by_family": dict(sorted(by_family.items())),
        "by_type_label": dict(sorted(by_label.items(), key=lambda kv: (-kv[1], kv[0]))),
        "by_type": dict(sorted(by_type.items(), key=lambda kv: (-kv[1], kv[0]))),
        "duplicate_names": dict(sorted(duplicate_names.items(), key=lambda kv: (-kv[1], kv[0]))),
        "duplicate_urls": dict(sorted(duplicate_urls.items(), key=lambda kv: (-kv[1], kv[0]))),
        "skipped_invalid": meta.get("skipped_invalid", []),
    }


def export_library(
    schools: list[SchoolRow],
    meta: dict,
    asset_path: Path,
    out_dir: Path,
    write_csv_files: bool = True,
    write_json: bool = True,
) -> dict[str, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: dict[str, Path] = {}

    if write_csv_files:
        all_path = out_dir / "wakeup_schools.csv"
        supported_path = out_dir / "wakeup_schools_supported.csv"
        write_csv(all_path, EXPORT_COLUMNS, (row.__dict__ for row in schools))
        write_csv(
            supported_path,
            EXPORT_COLUMNS,
            (row.__dict__ for row in schools if row.can_import),
        )
        paths["all_csv"] = all_path
        paths["supported_csv"] = supported_path

    if write_json:
        summary_path = out_dir / "wakeup_school_summary.json"
        summary = build_summary(schools, meta, asset_path)
        summary_path.write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        paths["summary_json"] = summary_path

    return paths


def host_kind(host: str) -> str:
    value = (host or "").strip().lower()
    if not value:
        return "unknown"
    if value == "localhost" or value.endswith(".local"):
        return "internal"
    try:
        ip = ipaddress.ip_address(value)
    except ValueError:
        return "hostname"
    if (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_reserved
        or ip.is_unspecified
    ):
        return "internal"
    if isinstance(ip, ipaddress.IPv4Address) and ip in ipaddress.ip_network(
        "100.64.0.0/10"
    ):
        return "internal"
    return "public_ip"


def is_internal_url(url: str) -> bool:
    return host_kind(urllib.parse.urlsplit(url).hostname or "") == "internal"


def build_targets(
    schools: list[SchoolRow],
    include_unsupported: bool,
    limit: int | None,
    match: str | None = None,
) -> list[CheckTarget]:
    query = (match or "").strip().lower()
    targets: dict[str, CheckTarget] = {}
    for school in schools:
        if not include_unsupported and not school.can_import:
            continue
        if query and query not in school.name.lower():
            continue
        target = targets.setdefault(
            school.url,
            CheckTarget(url=school.url, internal=is_internal_url(school.url)),
        )
        target.add(school)

    ordered = sorted(
        targets.values(),
        key=lambda target: (target.names[0] if target.names else target.url),
    )
    if limit is not None:
        ordered = ordered[:limit]
    return ordered


def _ssl_context(insecure: bool) -> ssl.SSLContext:
    context = ssl.create_default_context()
    if insecure:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    return context


def _request(
    url: str,
    method: str,
    timeout: float,
    insecure: bool,
    proxy: str | None = None,
) -> tuple[int, str, int]:
    handlers: list[urllib.request.BaseHandler] = [
        urllib.request.HTTPSHandler(context=_ssl_context(insecure))
    ]
    if proxy:
        handlers.append(
            urllib.request.ProxyHandler({"http": proxy, "https": proxy})
        )
    opener = urllib.request.build_opener(*handlers)
    request = urllib.request.Request(
        url,
        method=method,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": (
                "text/html,application/xhtml+xml,application/xml;q=0.9,"
                "image/avif,image/webp,*/*;q=0.8"
            ),
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Connection": "close",
        },
    )
    started = time.perf_counter()
    with opener.open(request, timeout=timeout) as response:
        status = response.status
        final_url = response.geturl()
        try:
            response.read(1)
        except Exception:
            pass
    return status, final_url, int((time.perf_counter() - started) * 1000)


def _classify_status(status: int) -> tuple[str, bool]:
    if status < 400:
        return "ok", True
    if status in BLOCKED_STATUSES:
        return "blocked", False
    if status < 500:
        return "client_error", False
    return "server_error", False


def _result(
    url: str,
    *,
    category: str,
    status: int | None = None,
    method: str = "",
    final_url: str = "",
    elapsed_ms: int = 0,
    error: str = "",
) -> ProbeResult:
    return ProbeResult(
        url=url,
        category=category,
        ok=category in ("ok", "ok_insecure"),
        status=status,
        method=method,
        final_url=final_url,
        elapsed_ms=elapsed_ms,
        error=error,
    )


def _error_result(url: str, error: BaseException, elapsed_ms: int) -> ProbeResult:
    reason = getattr(error, "reason", error)
    if isinstance(reason, (socket.timeout, TimeoutError)):
        category = "timeout"
    elif isinstance(reason, ssl.SSLError):
        category = "ssl_error"
    else:
        category = "network_error"
    text = str(reason).strip() or reason.__class__.__name__
    return _result(
        url,
        category=category,
        elapsed_ms=elapsed_ms,
        error=text,
    )


def _attempt(
    url: str,
    method: str,
    *,
    timeout: float,
    insecure: bool,
    proxy: str | None,
) -> ProbeResult:
    started = time.perf_counter()
    try:
        status, final_url, elapsed = _request(
            url, method, timeout, insecure, proxy
        )
        category, _ = _classify_status(status)
        return _result(
            url,
            category=category,
            status=status,
            method=method,
            final_url=final_url,
            elapsed_ms=elapsed,
        )
    except urllib.error.HTTPError as error:
        category, _ = _classify_status(error.code)
        return _result(
            url,
            category=category,
            status=error.code,
            method=method,
            final_url=error.geturl() or url,
            elapsed_ms=int((time.perf_counter() - started) * 1000),
            error=str(error.reason or ""),
        )
    except (urllib.error.URLError, OSError) as error:
        result = _error_result(
            url, error, int((time.perf_counter() - started) * 1000)
        )
        if result.category == "ssl_error" and not insecure:
            try:
                status, final_url, elapsed = _request(
                    url, method, timeout, True, proxy
                )
                category, _ = _classify_status(status)
                if category == "ok":
                    return _result(
                        url,
                        category="ok_insecure",
                        status=status,
                        method=method,
                        final_url=final_url,
                        elapsed_ms=elapsed,
                        error="TLS verification failed but the host is reachable",
                    )
            except (urllib.error.HTTPError, urllib.error.URLError, OSError):
                pass
        return result


def probe(
    url: str,
    *,
    method: str,
    timeout: float,
    retries: int,
    insecure: bool,
    proxy: str | None = None,
) -> ProbeResult:
    attempts = max(1, retries + 1)
    verbs = {
        "head": ("HEAD",),
        "get": ("GET",),
        "head-get": ("HEAD", "GET"),
    }[method]
    last_result: ProbeResult | None = None

    for attempt in range(attempts):
        if attempt:
            time.sleep(min(2.0, 0.5 * attempt))

        for verb in verbs:
            result = _attempt(
                url,
                verb,
                timeout=timeout,
                insecure=insecure,
                proxy=proxy,
            )
            if result.category in ("ok", "ok_insecure"):
                return result
            if result.category in ("client_error", "blocked", "server_error"):
                if verb == "HEAD" and method == "head-get":
                    last_result = result
                    continue
                return result
            last_result = result

    return last_result or _result(url, category="network_error", error="no attempt")


def _check_row(target: CheckTarget, result: ProbeResult) -> dict:
    return {
        "school_names": " | ".join(target.names),
        "school_count": len(target.names),
        "families": ",".join(sorted(target.families)),
        "types": ",".join(sorted(target.types)),
        "url": target.url,
        "host_kind": host_kind(
            urllib.parse.urlsplit(target.url).hostname or ""
        ),
        "category": result.category,
        "ok": "1" if result.ok else "0",
        "http_status": str(result.status) if result.status is not None else "",
        "method": result.method,
        "final_url": result.final_url,
        "elapsed_ms": result.elapsed_ms,
        "error": result.error,
    }


def load_existing_results(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def check_library(
    targets: list[CheckTarget],
    out_dir: Path,
    *,
    concurrency: int,
    timeout: float,
    retries: int,
    insecure: bool,
    method: str,
    proxy: str | None,
    resume: bool,
    retry_failed: bool,
    only_categories: list[str] | None,
    quiet: bool,
) -> list[dict]:
    out_dir.mkdir(parents=True, exist_ok=True)
    output_path = out_dir / "wakeup_schools_check.csv"

    rows: dict[str, dict] = {}
    if resume or retry_failed:
        for row in load_existing_results(output_path):
            url = row.get("url") or ""
            if url:
                row["host_kind"] = row.get("host_kind") or host_kind(
                    urllib.parse.urlsplit(url).hostname or ""
                )
                rows[url] = row

    target_urls = {target.url for target in targets}
    stale = [url for url in rows if url not in target_urls]
    for url in stale:
        rows.pop(url, None)

    for target in targets:
        existing = rows.get(target.url)
        if existing is None:
            continue
        existing["school_names"] = " | ".join(target.names)
        existing["school_count"] = len(target.names)
        existing["families"] = ",".join(sorted(target.families))
        existing["types"] = ",".join(sorted(target.types))

    retry_categories = set(only_categories or FAILED_CATEGORIES)
    internal_targets = [target for target in targets if target.internal]
    network_targets = [target for target in targets if not target.internal]

    if retry_failed:
        pending = [
            target
            for target in network_targets
            if target.url not in rows
            or rows[target.url].get("category") in retry_categories
        ]
    elif resume:
        pending = [target for target in network_targets if target.url not in rows]
    else:
        rows = {}
        pending = network_targets

    skipped = len(network_targets) - len(pending)
    if not quiet:
        print(
            f"Checking {len(pending)} URLs"
            + (f" ({skipped} kept from previous results)" if skipped else "")
            + f" with concurrency={concurrency}, timeout={timeout}s, method={method}",
            file=sys.stderr,
        )
        if internal_targets:
            print(
                f"Marked {len(internal_targets)} intranet URLs as internal (not checked).",
                file=sys.stderr,
            )
        if stale:
            print(
                f"Dropped {len(stale)} stale rows whose URL is no longer in the catalog.",
                file=sys.stderr,
            )

    lock = threading.Lock()
    completed = 0
    started_at = time.perf_counter()

    def persist() -> None:
        ordered = sorted(rows.values(), key=lambda row: (row.get("url") or ""))
        write_csv(output_path, CHECK_COLUMNS, ordered)

    def record(target: CheckTarget, result: ProbeResult) -> None:
        nonlocal completed
        with lock:
            rows[target.url] = _check_row(target, result)
            completed += 1
            if completed % 25 == 0:
                persist()
                if not quiet:
                    elapsed = time.perf_counter() - started_at
                    rate = completed / elapsed if elapsed else 0
                    print(
                        f"  {completed}/{len(pending)} done "
                        f"({rate:.1f}/s, ok={sum(1 for item in rows.values() if item.get('ok') == '1')})",
                        file=sys.stderr,
                    )

    for target in internal_targets:
        rows[target.url] = _check_row(
            target,
            _result(
                target.url,
                category="internal",
                error="intranet address; only reachable on campus",
            ),
        )
    if internal_targets:
        persist()

    interrupted = False
    with ThreadPoolExecutor(max_workers=max(1, concurrency)) as executor:
        futures = {
            executor.submit(
                probe,
                target.url,
                method=method,
                timeout=timeout,
                retries=retries,
                insecure=insecure,
                proxy=proxy,
            ): target
            for target in pending
        }
        try:
            for future in as_completed(futures):
                target = futures[future]
                try:
                    result = future.result()
                except Exception as error:  # pragma: no cover - defensive
                    result = _error_result(target.url, error, 0)
                record(target, result)
        except KeyboardInterrupt:
            interrupted = True
            for future in futures:
                future.cancel()
            if not quiet:
                print("\nInterrupted; writing partial results.", file=sys.stderr)

    persist()

    results = list(rows.values())
    summary = summarize_check(results)
    summary_path = out_dir / "wakeup_schools_check_summary.json"
    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not quiet:
        print(
            f"Wrote {output_path} and {summary_path}"
            + (" (partial)" if interrupted else ""),
            file=sys.stderr,
        )
    return results


def summarize_check(rows: list[dict]) -> dict:
    categories = Counter(row.get("category") or "unknown" for row in rows)
    statuses = Counter(str(row.get("http_status") or "-") for row in rows)
    counts = {
        "targets": len(rows),
        "ok": categories.get("ok", 0),
        "ok_insecure": categories.get("ok_insecure", 0),
        "reachable": categories.get("ok", 0) + categories.get("ok_insecure", 0),
        "internal": categories.get("internal", 0),
        "blocked": categories.get("blocked", 0),
        "client_error": categories.get("client_error", 0),
        "server_error": categories.get("server_error", 0),
        "timeout": categories.get("timeout", 0),
        "ssl_error": categories.get("ssl_error", 0),
        "network_error": categories.get("network_error", 0),
    }
    counts["actionable"] = sum(
        counts[key]
        for key in (
            "client_error",
            "server_error",
            "timeout",
            "ssl_error",
            "network_error",
        )
    )
    return {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "counts": counts,
        "by_category": dict(sorted(categories.items(), key=lambda kv: (-kv[1], kv[0]))),
        "by_http_status": dict(
            sorted(statuses.items(), key=lambda kv: (-kv[1], str(kv[0])))
        ),
    }


def _add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--asset",
        type=Path,
        default=DEFAULT_ASSET,
        help=f"WakeUp school JSON (default: {DEFAULT_ASSET})",
    )
    parser.add_argument(
        "--dart-source",
        type=Path,
        default=DEFAULT_DART_SOURCE,
        help=f"Repository Dart source used for type sets (default: {DEFAULT_DART_SOURCE})",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help=f"Output directory (default: {DEFAULT_OUT_DIR})",
    )
    parser.add_argument("--quiet", action="store_true", help="Suppress progress output.")


def _add_check_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--include-unsupported",
        action="store_true",
        help="Also check schools without a generic adapter mapping.",
    )
    parser.add_argument("--limit", type=int, default=None, help="Only check the first N URLs.")
    parser.add_argument(
        "--match",
        default=None,
        help="Only check schools whose name contains this text (case-insensitive).",
    )
    parser.add_argument("--concurrency", type=int, default=12, help="Parallel requests (default: 12).")
    parser.add_argument("--timeout", type=float, default=12.0, help="Per-request timeout in seconds.")
    parser.add_argument("--retries", type=int, default=1, help="Retries per URL (default: 1).")
    parser.add_argument(
        "--method",
        choices=("head-get", "get", "head"),
        default="head-get",
        help="Probe strategy (default: HEAD then GET for non-2xx).",
    )
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Skip TLS certificate verification (useful for broken campus certs).",
    )
    parser.add_argument(
        "--proxy",
        default=None,
        help="HTTP(S) proxy URL, for example http://127.0.0.1:7890.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Keep rows already present in wakeup_schools_check.csv.",
    )
    parser.add_argument(
        "--retry-failed",
        action="store_true",
        help="Re-check only rows whose category is in --only-category (default: all failures).",
    )
    parser.add_argument(
        "--only-category",
        default=None,
        help=(
            "Comma-separated categories to retry with --retry-failed "
            f"({', '.join(FAILED_CATEGORIES)})."
        ),
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Export and batch-check the WakeUp school library.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    export_parser = subparsers.add_parser("export", help="Write CSV and summary JSON.")
    _add_common_arguments(export_parser)
    export_parser.add_argument("--no-csv", action="store_true")
    export_parser.add_argument("--no-json", action="store_true")

    check_parser = subparsers.add_parser("check", help="Batch-check school URLs.")
    _add_common_arguments(check_parser)
    _add_check_arguments(check_parser)

    all_parser = subparsers.add_parser("all", help="Export, then batch-check.")
    _add_common_arguments(all_parser)
    _add_check_arguments(all_parser)

    args = parser.parse_args(argv)

    if not args.asset.exists():
        print(f"ERROR: asset not found: {args.asset}", file=sys.stderr)
        return 2
    if not args.dart_source.exists():
        print(f"ERROR: Dart source not found: {args.dart_source}", file=sys.stderr)
        return 2

    config = parse_dart_config(args.dart_source)
    schools, meta = load_schools(args.asset, config)

    if not args.quiet:
        importable = sum(1 for row in schools if row.can_import)
        print(
            f"Loaded {len(schools)} schools ({importable} importable, "
            f"{len(schools) - importable} unsupported) from {args.asset}",
            file=sys.stderr,
        )

    if args.command in ("export", "all"):
        paths = export_library(
            schools,
            meta,
            args.asset,
            args.out_dir,
            write_csv_files=not args.no_csv,
            write_json=not args.no_json,
        )
        if not args.quiet:
            for label, path in paths.items():
                print(f"  {label}: {path}", file=sys.stderr)

    if args.command in ("check", "all"):
        only_categories = None
        if args.only_category:
            only_categories = [
                item.strip()
                for item in args.only_category.split(",")
                if item.strip()
            ]
            unknown = sorted(set(only_categories) - set(FAILED_CATEGORIES))
            if unknown:
                print(
                    f"ERROR: unknown --only-category values: {', '.join(unknown)}",
                    file=sys.stderr,
                )
                return 2
            if not args.retry_failed:
                print(
                    "ERROR: --only-category requires --retry-failed.",
                    file=sys.stderr,
                )
                return 2

        targets = build_targets(
            schools,
            include_unsupported=args.include_unsupported,
            limit=args.limit,
            match=args.match,
        )
        check_library(
            targets,
            args.out_dir,
            concurrency=args.concurrency,
            timeout=args.timeout,
            retries=args.retries,
            insecure=args.insecure,
            method=args.method,
            proxy=args.proxy,
            resume=args.resume,
            retry_failed=args.retry_failed,
            only_categories=only_categories,
            quiet=args.quiet,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

