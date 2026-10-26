# 3-minute walkthrough: Nigerian DisCo Performance Scorecard

A timed script for a Loom recording of about 3 minutes (screen plus camera bubble, 1080p). Say it in your own words; the lines are a guide, not a teleprompter.

**Open these tabs before you press record:** README, one NERC quarterly report PDF on its appendix table, `ingestion/extract_nerc.py` (the repair rules), the architecture diagram, the "Checks on the regulator's tables" section, the 2026/Q2 scorecard, GitHub Actions.

| Time | On screen | What to say |
|---|---|---|
| 0:00–0:20 | Portfolio card, then the README title | Nigeria's eleven electricity distribution companies lose about a third of the value of the power they receive. The regulator publishes the figures as tables inside 90-page PDFs, one quarter at a time. This turns eight reports into one monthly scorecard. |
| 0:20–0:40 | README intro | I spent five years at Ikeja Electric, one of the eleven. As its BI analyst I reported billing and collection efficiency on priority feeders. This is the sector-wide view of the same measures, from public data only. |
| 0:40–1:05 | The PDF appendix, then `extract_nerc.py` | The extractor finds each table by its title, because the appendix numbers change, and takes a DisCo's row only if every month is there. Malformed numbers are repaired only by logged rules, like a "38/02" typo carried from one report into the next. |
| 1:05–1:30 | Architecture, then the Tests section | dbt recomputes every efficiency from the naira and energy figures instead of trusting the printed percentages. My ATC&C matches NERC's published figure within 0.15 points, and 54 of 55 within 0.05. |
| 1:30–1:55 | "Checks on the regulator's tables" | The checks are rounding-aware, and they still find 18 places where the reports don't add up: an "All DisCos" row that isn't the sum of the eleven, and printed quarterly percentages that disagree with the report's own months. NERC also changed the billing basis from energy to money in 2025; the models keep it beside every figure. |
| 1:55–2:30 | 2026/Q2 scorecard | In Q2 2026 no DisCo met its target: the sector lost 36.3% against targets of 13.5 to 29%. Over four quarters that's ₦1,325bn not recovered, ₦724bn before billing and ₦601bn billed but unpaid. For 9 of 11 billing is the bigger loss, which points to metering. Kano and Jos collect under 55%. |
| 2:30–2:45 | GitHub Actions | CI downloads the reports from nerc.gov.ng and rebuilds everything. Adding a quarter is one line in the Makefile. |
| 2:45–3:00 | Back to the README top | For a board, investor or regulator: each DisCo's loss against its target, whether to spend on meters or enforcement, and which printed figures to trust. Links are under the video. |

## Recording checklist
- Close email, chat and notifications. Zoom the browser to 125% so tables are readable.
- Open the PDF at the appendix page before recording; scrolling a 90-page report on camera wastes time.
- Keep to one take per section; Loom lets you trim. Aim for 2:45 to 3:10.
- Show real numbers on screen as you say them; never estimate on camera.
- Keep any Ikeja Electric detail to what the README says; the project uses no employer data.

## After recording
1. Copy the Loom share link.
2. In `README.md`, replace the roadmap line with `- [x] [3-minute Loom walkthrough](<your Loom link>)` and add the link under the title.
3. Add the link to this project's card on saigwe.github.io.
