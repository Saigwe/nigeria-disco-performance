PY ?= python
DB ?= warehouse/nerc.duckdb
DBT_BIN ?= dbt
DBT = cd dbt && DUCKDB_PATH=../$(DB) $(DBT_BIN)
NERC = https://nerc.gov.ng/wp-content/uploads
REPORTS = 2024/12/2024_Q3-Report.pdf 2025/03/2024_Q4-Report.pdf 2025/07/2025_Q1_Report.pdf 2025/10/2025_Q2-Report.pdf \
          2026/01/2025_Q3-Report.pdf 2026/04/2025_Q4-Report.pdf 2026/07/2026_Q1-Report.pdf 2026/09/2026_Q2_Report.pdf

.PHONY: all download extract dbt test clean

all: download extract dbt test   ## NERC quarterly reports (real, public) -> extracted tables -> dbt -> tests

download:   ## 8 quarterly reports, about 22 MB, from nerc.gov.ng; skipped when present
	mkdir -p data/raw
	for r in $(REPORTS); do f=data/raw/$$(basename $$r); [ -s $$f ] || curl -sL -A "Mozilla/5.0" -o $$f "$(NERC)/$$r"; done

extract:
	$(PY) ingestion/extract_nerc.py --pdfs data/raw --db $(DB)

dbt:
	$(DBT) deps --profiles-dir .
	$(DBT) build --profiles-dir .

test:
	NERC_DB=$(DB) $(PY) -m pytest -q tests

clean:
	rm -rf warehouse dbt/target dbt/logs dbt/dbt_packages
