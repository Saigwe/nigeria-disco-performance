"""Unit tests for the PDF extractor's parsing rules, and checks on a finished run (NERC_DB)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ingestion"))
from extract_nerc import months_for, number  # noqa: E402

DB = os.environ.get("NERC_DB", str(ROOT / "warehouse" / "nerc.duckdb"))


def test_numbers_are_repaired_only_by_explicit_rules():
    issues = []
    assert number("1,824", issues, {}) == 1824.0 and not issues
    assert number("38/02", issues, {}) == 38.02 and issues[-1]["rule"] == "'/' used for '.'"
    assert number("49.3%", issues, {}) == 49.3 and issues[-1]["rule"] == "stray '%'"
    assert number("n/a", issues, {}) is None and issues[-1]["repaired_to"] is None


def test_month_headers_map_to_the_right_quarters():
    text = "Appendix IV\nDisCos Jan Feb Mar Apr May Jun Jan Feb Mar Apr May Jun\nAbuja 1 2 3"
    months = months_for(text, ["2025/Q1", "2025/Q2"])
    assert months == [pd.Timestamp(2025, m, 1) for m in range(1, 7)]
    text = "Oct Nov Dec Jan Feb Mar Oct Nov Dec Jan Feb Mar"
    assert months_for(text, ["2024/Q4", "2025/Q1"])[2:4] == [pd.Timestamp(2024, 12, 1), pd.Timestamp(2025, 1, 1)]


def test_every_month_from_april_2024_to_june_2026_is_covered():
    con = duckdb.connect(DB, read_only=True)
    months = {r[0] for r in con.execute("select distinct month from gold.fct_disco_month where billed_ngn_bn is not null").fetchall()}
    expected = set(pd.date_range("2024-04-01", "2026-06-01", freq="MS").date)
    assert months == expected


def test_scorecard_covers_all_eleven_discos():
    con = duckdb.connect(DB, read_only=True)
    assert con.execute("select count(*) from gold.rpt_scorecard").fetchone()[0] == 11
