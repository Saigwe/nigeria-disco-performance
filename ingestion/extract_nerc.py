"""Extract DisCo monthly performance tables from NERC quarterly report PDFs (REAL, public: nerc.gov.ng).

Each report's appendices give, per DisCo and month, for the previous and current quarter:
  revenue     "Monthly revenue performance and collection efficiency":  billed (NGN bn), collected (NGN bn)
  energy_gwh  "Monthly energy offtake and energy billed" (to 2025/Q1):    offtake (GWh), billed (GWh)
  energy_ngn  "Energy billed and Billing efficiency (BE)" (from 2025/Q2): received (NGN bn), billed (NGN bn)
plus the quarterly efficiency the report prints at the end of each row, which dbt uses as a reconciliation check,
and, from "ATC&C Loss Performance" (2025/Q2 onwards), each DisCo's MYTO target and the published ATC&C loss.

Nothing is guessed. A token that isn't a clean number is repaired only by an explicit rule ("38/02" -> 38.02 when
"/" stands in for ".", "49.3%" -> 49.3) and every repair is logged with its page in bronze.nerc_extraction_issues.
A row with the wrong number of values is rejected and logged, not padded.

Usage: python ingestion/extract_nerc.py --pdfs data/raw --db warehouse/nerc.duckdb
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import duckdb
import pandas as pd
import pdfplumber

TABLES = {
    "revenue": (r"Monthly revenue performance and collection efficiency", ("billed_ngn_bn", "collected_ngn_bn"), "collection_efficiency"),
    "energy_gwh": (r"Monthly energy offtake and energy billed", ("energy_offtake_gwh", "energy_billed_gwh"), "billing_efficiency_gwh"),
    "energy_ngn": (r"Energy billed and Billing efficiency \(BE\)", ("energy_received_ngn_bn", "energy_billed_ngn_bn"), "billing_efficiency_ngn"),
}
DISCOS = {"abuja": "Abuja", "benin": "Benin", "eko": "Eko", "enugu": "Enugu", "ibadan": "Ibadan", "ikeja": "Ikeja",
          "jos": "Jos", "kaduna": "Kaduna", "kano": "Kano", "p/harcourt": "Port Harcourt", "p/ harcourt": "Port Harcourt",
          "port harcourt": "Port Harcourt", "ph": "Port Harcourt", "yola": "Yola", "all discos": "All DisCos"}
MONTHS = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8,
          "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12}
ROW = re.compile(r"^(All DisCos|P/ ?Harcourt|Port Harcourt|PH|Abuja|Benin|Eko|Enugu|Ibadan|Ikeja|Jos|Kaduna|Kano|Yola)\s+(.*)$")


def number(token: str, issues: list, context: dict) -> float | None:
    clean = token.replace(",", "")
    if re.fullmatch(r"-?\d+(\.\d+)?", clean):
        return float(clean)
    for pattern, repl, rule in ((r"^(\d+)/(\d+)$", r"\1.\2", "'/' used for '.'"), (r"^(\d+(\.\d+)?)%$", r"\1", "stray '%'")):
        if re.fullmatch(pattern, clean):
            fixed = re.sub(pattern, repl, clean)
            issues.append({**context, "token": token, "repaired_to": fixed, "rule": rule})
            return float(fixed)
    issues.append({**context, "token": token, "repaired_to": None, "rule": "not a number: value rejected"})
    return None


def months_for(text: str, quarters: list[str]) -> list[pd.Timestamp]:
    header = next(l for l in text.splitlines() if sum(w.lower().strip(".") in MONTHS for w in l.split()) >= 3)
    names = [w.lower().strip(".") for w in header.split() if w.lower().strip(".") in MONTHS]
    names = names[: len(names) // 2] if len(names) > 6 or len(names) == len(quarters) * 6 else names
    out = []
    for i, name in enumerate(names):
        year, q = quarters[min(i // 3, len(quarters) - 1)].split("/Q")
        out.append(pd.Timestamp(int(year), MONTHS[name], 1))
    return out


def extract_atcc(text: str, report_quarter: str, page_no: int, issues: list) -> list[dict]:
    head = re.search(r"Table \d+: ATC&C Loss Performance[^\n]*\n", text)
    if not head or "....." in text[head.start():head.end() + 5]:
        return []
    seg = text[head.start():]
    year = re.search(r"(\d{4}) MYTO", seg)
    quarters = re.search(r"(\d{4}/Q\d) (\d{4}/Q\d)", seg)
    prev_q, cur_q = quarters.groups() if quarters else (None, report_quarter)
    if prev_q is None:  # the header lists only the current quarter's years; derive the previous quarter
        y, q = map(int, report_quarter.split("/Q"))
        prev_q = f"{y - (q == 1)}/Q{4 if q == 1 else q - 1}"
    rows = []
    for line in seg.splitlines():
        m = ROW.match(line.strip())
        if not m or m.group(1) == "All DisCos":
            continue
        ctx = {"report_quarter": report_quarter, "table": "atcc", "page": page_no, "disco": DISCOS[m.group(1).lower()]}
        nums = [number(t, issues, ctx) for t in m.group(2).split()[:3]]
        if len(nums) < 3 or None in nums:
            continue
        rows.append({**ctx, "target_year": int(year.group(1)), "myto_target_pct": nums[0],
                     "atcc_prev_quarter": prev_q, "atcc_prev_pct": nums[1], "atcc_quarter": cur_q, "atcc_pct": nums[2]})
    return rows


def extract(pdf_path: Path) -> tuple[list[dict], list[dict], list[dict], list[dict]]:
    report = re.search(r"(\d{4})_Q(\d)", pdf_path.name)
    report_quarter = f"{report.group(1)}/Q{report.group(2)}"
    values, quarterly, issues, atcc = [], [], [], []
    with pdfplumber.open(pdf_path) as pdf:
        for page_no, page in enumerate(pdf.pages, start=1):
            text = page.extract_text() or ""
            if not atcc:
                atcc = extract_atcc(text, report_quarter, page_no, issues)
            for table, (title, measures, pct_name) in TABLES.items():
                head = re.search(rf"^Appendix [IVX]+:\s*{title}[^\n]*", text, re.M)
                if not head:
                    continue
                quarters = sorted(set(re.findall(r"(\d{4}) ?/Q([1-4])", head.group(0))))
                quarters = [f"{y}/Q{q}" for y, q in quarters]
                months = months_for(text, quarters)
                n = len(months)
                for line in text.splitlines():
                    m = ROW.match(line.strip())
                    if not m:
                        continue
                    disco = DISCOS[m.group(1).lower()]
                    tokens = m.group(2).split()
                    ctx = {"report_quarter": report_quarter, "table": table, "page": page_no, "disco": disco}
                    if len(tokens) != 2 * n + len(quarters):
                        issues.append({**ctx, "token": " ".join(tokens), "repaired_to": None,
                                       "rule": f"expected {2 * n + len(quarters)} values, found {len(tokens)}: row rejected"})
                        continue
                    nums = [number(t, issues, ctx) for t in tokens]
                    for k, measure in enumerate(measures):
                        for i, month in enumerate(months):
                            v = nums[k * n + i]
                            if v is not None:
                                values.append({**ctx, "month": month.date(), "measure": measure, "value": v})
                    for j, q in enumerate(quarters):
                        v = nums[2 * n + j]
                        if v is not None:
                            quarterly.append({**ctx, "quarter": q, "measure": pct_name, "published_pct": v})
    return values, quarterly, issues, atcc


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pdfs", type=Path, default=Path("data/raw"))
    ap.add_argument("--db", default="warehouse/nerc.duckdb")
    args = ap.parse_args()
    values, quarterly, issues, atcc = [], [], [], []
    for pdf in sorted(args.pdfs.glob("*.pdf")):
        v, q, i, a = extract(pdf)
        values += v
        quarterly += q
        issues += i
        atcc += a
        print(f"{pdf.name:<24} {len(v):>5} monthly values  {len(q):>3} quarterly %  {len(a):>2} ATC&C rows  {len(i):>2} issues")
    Path(args.db).parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(args.db)
    con.execute("create schema if not exists bronze")
    for name, rows in (("nerc_monthly_values", values), ("nerc_quarterly_published", quarterly),
                       ("nerc_extraction_issues", issues), ("nerc_atcc_published", atcc)):
        df = pd.DataFrame(rows)
        con.execute(f"create or replace table bronze.{name} as select * from df")
    print(f"{len(values):,} monthly values, {len(quarterly)} published quarterly percentages, {len(issues)} issues logged")


if __name__ == "__main__":
    main()
