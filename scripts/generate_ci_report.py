from __future__ import annotations

import html
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def read_junit(path: Path) -> dict[str, int | str]:
    if not path.exists():
        return {"tests": "Unavailable", "passed": "Unavailable", "failures": "Unavailable", "errors": "Unavailable", "skipped": "Unavailable"}

    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else list(root.findall(".//testsuite"))
    tests = sum(int(suite.attrib.get("tests", 0)) for suite in suites)
    failures = sum(int(suite.attrib.get("failures", 0)) for suite in suites)
    errors = sum(int(suite.attrib.get("errors", 0)) for suite in suites)
    skipped = sum(int(suite.attrib.get("skipped", 0)) for suite in suites)
    return {
        "tests": tests,
        "passed": tests - failures - errors - skipped,
        "failures": failures,
        "errors": errors,
        "skipped": skipped,
    }


def read_coverage(path: Path) -> str:
    if not path.exists():
        return "Unavailable"

    line_rate = ET.parse(path).getroot().attrib.get("line-rate")
    if line_rate is None:
        return "Unavailable"
    return f"{float(line_rate) * 100:.1f}%"


def status_label(value: str) -> str:
    return value.replace("success", "passed").replace("failure", "failed").replace("skipped", "skipped")


def report_path(name: str) -> Path:
    downloaded_path = Path("reports") / name
    return downloaded_path if downloaded_path.exists() else Path(name)


def main() -> int:
    report_dir = Path(os.environ.get("REPORT_DIR", "report"))
    report_dir.mkdir(parents=True, exist_ok=True)

    test_result = os.environ.get("TEST_RESULT", "unknown")
    docker_result = os.environ.get("DOCKER_RESULT", "skipped")
    sonar_result = os.environ.get("SONAR_RESULT", "unknown")
    tests = read_junit(report_path("junit.xml"))
    coverage = read_coverage(report_path("coverage.xml"))

    repository = os.environ.get("GITHUB_REPOSITORY", "repository")
    run_url = (
        f"https://github.com/{repository}/actions/runs/"
        f"{os.environ.get('GITHUB_RUN_ID', '')}"
    )
    sonar_url = "https://sonarcloud.io/project/overview?id=fastapi-demo&organization=pjain047"
    docker_username = os.environ.get("DOCKER_USERNAME", "")
    docker_url = f"https://hub.docker.com/r/{docker_username}/fastapi-demo" if docker_username else "Unavailable"
    image = f"{docker_username}/fastapi-demo:${os.environ.get('GITHUB_SHA', 'latest')[:12]}" if docker_username else "Unavailable"

    markdown = f"""## CI report

| Check | Status / value |
| --- | --- |
| Unit tests | {status_label(test_result)} |
| Test count | {tests['tests']} total, {tests['passed']} passed, {tests['failures']} failed, {tests['errors']} errors, {tests['skipped']} skipped |
| Line coverage | {coverage} |
| SonarCloud | {status_label(sonar_result)} |
| Docker build and push | {status_label(docker_result)} |
| Docker image | [{image}]({docker_url}) |
| SonarCloud project | [Open project]({sonar_url}) |
| Workflow run | [Open run]({run_url}) |
| Commit | `{os.environ.get('GITHUB_SHA', 'unknown')}` |

The full HTML report is available in the `ci-report` workflow artifact.
"""

    markdown_path = report_dir / "summary.md"
    html_path = report_dir / "ci-report.html"
    markdown_path.write_text(markdown, encoding="utf-8")

    rows = "\n".join(
        f"<tr><th>{html.escape(label)}</th><td>{value}</td></tr>"
        for label, value in [
            ("Unit tests", html.escape(status_label(test_result))),
            ("Test count", html.escape(f"{tests['tests']} total, {tests['passed']} passed, {tests['failures']} failed, {tests['errors']} errors, {tests['skipped']} skipped")),
            ("Line coverage", html.escape(coverage)),
            ("SonarCloud", f'<a href="{html.escape(sonar_url)}">{html.escape(status_label(sonar_result))}</a>'),
            ("Docker build and push", html.escape(status_label(docker_result))),
            ("Docker image", f'<a href="{html.escape(docker_url)}">{html.escape(image)}</a>'),
            ("SonarCloud project", f'<a href="{html.escape(sonar_url)}">Open project</a>'),
            ("Workflow run", f'<a href="{html.escape(run_url)}">Open run</a>'),
            ("Commit", f"<code>{html.escape(os.environ.get('GITHUB_SHA', 'unknown'))}</code>"),
        ]
    )
    html_document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CI report - {html.escape(repository)}</title>
  <style>
    body {{ background: #f6f8fa; color: #24292f; font: 16px system-ui, sans-serif; margin: 0; padding: 2rem; }}
    main {{ background: white; border: 1px solid #d0d7de; border-radius: 8px; margin: auto; max-width: 900px; padding: 2rem; }}
        h1 {{ margin-top: 0; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border-bottom: 1px solid #d0d7de; padding: .75rem; text-align: left; }}
        th {{ width: 30%; }}
  </style>
</head>
<body><main><h1>CI report</h1><table>{rows}</table></main></body>
</html>
"""
    html_path.write_text(html_document, encoding="utf-8")
    print(markdown)
    return 0


if __name__ == "__main__":
    sys.exit(main())
