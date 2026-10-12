# Sales Performance 2026: Excel Dashboard + SQL Deep-Dive

> **An interactive Excel dashboard that shows *what is happening* in the business, plus 12 SQL queries that explain *why*, and what to do about it.**
> 2,707 orders · $645K revenue · 17 countries · 20 products

**Tools:** Excel (PivotTables, slicers, timeline, filled map, KPI cards) · MySQL 8 (CTEs, window functions, data cleaning with views)

![Excel sales dashboard](images/dashboard.png)

---

## 1. The business scenario

*A European retailer of hiking, camping, cycling, travel and fitness gear sells through four channels (online store, retail partners, marketplaces and corporate accounts) in 17 countries. Revenue peaked mid-year and has drifted down since, and discounting has become routine.*

**The brief from the Head of Commercial had two parts:**

> **Part 1, monitoring:** "I want one screen my regional managers can open every week, filter to their own patch, and see how sales are going."
>
> **Part 2, investigation:** "We did about $645K in 2026, but growth has stalled since Q2 and I suspect we are giving margin away. **Where do we actually make money, where are we leaking it, and what should we change?**"

Each part needs a different tool:

| | **Excel dashboard** | **SQL analysis** |
|---|---|---|
| **Type of question** | *What is happening?* (descriptive) | *Why, and where should we act?* (diagnostic) |
| **Audience** | Regional managers, weekly check-in | Commercial leadership, planning decisions |
| **Strength** | Self-serve: filter by region, channel, customer type and date range with one click | Calculations a dashboard can't show easily: margins, growth rates, rankings, cumulative shares, benchmarks |
| **Deliverable** | `Interactive_Excel_Sales_Dashboard.xlsx` | `sales_analysis_mysql.sql` |

Both are built on the same `dataset.csv` and **reconcile to each other**: the dashboard and SQL Q1 agree on $645,223 revenue, $296,384 gross profit and 6,698 units (differences under $1 come from CSV rounding).

## 2. The data

`dataset.csv`: one row per order, 20 columns, 2,707 rows, no nulls, no duplicate IDs.

| Group | Columns |
|---|---|
| Where / how | Region (4), Country (17), Sales Channel (4), Customer Type (3) |
| What | Product Category (5), Product (20) |
| Price & profit | Units Sold, Unit Price, Discount %, Unit Cost, Revenue, COGS, Gross Profit, Gross Margin % |
| When | Order Date, Year, Quarter, MonthNo, Month |

**Cleaning in SQL:** money and percentages arrive as text (`$82.06`, `15%`). The script loads everything as text, then a `sales` view strips the symbols and casts to proper types. All 12 queries run on that view.

**A note on margin:** every margin below is `SUM(profit) / SUM(revenue)`, not an average of the per-order margin column. Averaging percentages would let small orders distort the result.

---

## 3. Part 1: The Excel dashboard (*what is happening?*)

**File:** `Interactive_Excel_Sales_Dashboard.xlsx`

**How it is built:** the `Data` sheet feeds nine PivotTables on the `Analyze` sheet, which drive the KPI cards and four charts on the dashboard. Three slicers (Region, Sales Channel, Customer Type) and an Order Date timeline are connected to **all nine PivotTables**, so one click re-filters everything. A hidden `Detail1` sheet holds a drill-through of the underlying orders behind a figure.

**The questions it answers:**

| # | Question a manager asks | Dashboard element | What it shows |
|---|---|---|---|
| D1 | "How are we doing overall?" | 4 KPI cards | **$645,223** total sales · **$296,384** gross profit · **6,698** units · **$238.35** average revenue per order |
| D2 | "How are revenue and profit moving month to month?" | Line chart: revenue and gross profit by month | Revenue climbs from $35.6K (Feb) to a **$69.5K peak in June**, then slides to $49.1K by October. Profit follows the same shape |
| D3 | "Where in Europe do our sales come from?" | Filled map: revenue by country | The **UK ($74.4K), Germany ($70.0K) and France ($55.1K)** lead; Ireland ($16.6K) is lowest |
| D4 | "Which product categories bring in the revenue?" | Bar chart: revenue by category | Camping **30.8%**, Hiking **27.9%**, Travel **19.2%**, Cycling **13.6%**, Fitness **8.6%** |
| D5 | "What are our best sellers?" | Bar chart: top 5 products by units sold | Trail Boots (449), Summit Backpack 45L (447), Compact Sleeping Bag (433), Hiking Daypack 20L (396), Trail Bike Light (392) |
| D6 | "How does this look for **my** region / channel / customer type / time period?" | 3 slicers + timeline | Every KPI and chart re-filters instantly |

**What the dashboard deliberately does not show:** margin %, discount levels, growth rates, or how channels and customer types compare side by side. Those need calculations that are easier and more reliable in SQL, which is Part 2.

---

## 4. Part 2: The SQL analysis (*why is it happening, and what should we do?*)

**File:** `sales_analysis_mysql.sql`

**How to run it**
1. Open the file in MySQL Workbench.
2. Update the path in the `LOAD DATA LOCAL INFILE` line if your CSV is elsewhere. This needs `local_infile` enabled on the server and `OPT_LOCAL_INFILE=1` on the connection (the script explains how). Alternatively, use Workbench's Table Data Import Wizard on the `sales_raw` table.
3. Run the script top to bottom. `SELECT COUNT(*) FROM sales_raw;` should return **2707**.

### Part A: Size and concentration

**Q1. "Do the headline numbers hold up?"** → *Executive summary KPIs.*
**Answer:** Yes. $645.2K revenue, $296.4K gross profit, a **45.9% gross margin**, 2,707 orders averaging $238. This matches the dashboard exactly, which is the cross-check that both tools are reading the data the same way.

**Q2. "Which regions carry the business, and do any earn worse margins?"** → *Regional performance with share of total (window function over an aggregate).*
**Answer:** Western Europe (30.7%) and Central Europe (29.6%) generate about **60% of revenue**. Margins are nearly identical across regions (45.6–46.3%), so regional differences are about volume, not profitability.

**Q12. "The map shows who is biggest. How concentrated is revenue, exactly?"** → *Pareto analysis (cumulative share with a running window).*
**Answer:** **12 of 17 countries produce 82% of revenue.** The UK (11.5%) and Germany (10.9%) alone account for 22%. Five countries (Belgium, Switzerland, Finland, Czechia, Ireland) form a long tail.

### Part B: Which products earn the money, and which leak it?

**Q3. "The best-seller chart ranks by volume. Which products actually make the profit?"** → *Top 10 products by gross profit.*
**Answer:** Summit Backpack 45L leads on profit ($29.6K), followed by Trail Tent 2P and Trail Boots. Volume and profit tell different stories: Alpine Tent 4P is #2 by revenue but only #5 by profit, and Trail Bike Light, a top-5 seller by units, doesn't make the profit top 10.

**Q11. "Are any big sellers quietly under-earning?"** → *High-revenue, low-margin products (CTEs, benchmark, CASE flag).*
**Answer:** **Alpine Tent 4P** is the clearest leak: $63.7K revenue at a **37.1% margin**, 9 points below company average, with a 6.3% average discount against 5.1% company-wide. **Trail Boots**, the #1 seller by units, earns only **40.9%**. Both are flagged `REVIEW PRICING`.

**Q8. "Camping is our biggest category. Is it also our best?"** → *Category mix within each region (`SUM() OVER (PARTITION BY region)`).*
**Answer:** No. Camping is the top or second category in every region (26–34% of regional revenue) but has the **lowest margins (42–44%)**. Fitness is the smallest category (8–10%) but has the **highest (49–53%)**. The business leans on its lowest-margin category.

**Q9. "What should each regional manager stock first?"** → *Top 3 products per region (`ROW_NUMBER` in a CTE).*
**Answer:** Every region has a different #1: Alpine Tent 4P (Central), Trail Tent 2P (Northern), Compact Sleeping Bag (Southern), Summit Backpack 45L (Western). One pan-European stocking plan would miss local demand.

### Part C: What is the trend?

**Q4. "The line chart shows a peak. How fast did we grow and fall?"** → *Monthly revenue with month-over-month growth (`LAG`).*
**Answer:** Growth ran +25%, +22%, +6%, +19% from March to June, then revenue **fell four months in a row** (−4%, −13%, −7%, −8%). November rebounded 33%, then December dropped 22%.

**Q5. "How do the quarters compare, in revenue and margin?"** → *Quarterly performance with quarter-over-quarter change.*
**Answer:** Q1→Q2 grew **52.7%**, but every quarter since has declined (Q3 −2.6%, Q4 −6.7%). Q4 also has the **lowest margin (44.6%** vs 46.8% in Q3), so volume and profitability are both softening.

**Q10. "Is the slowdown real, or just noise?"** → *Cumulative revenue and 3-month moving average (window frames).*
**Answer:** Real. The moving average peaked at **$64.7K in July** and had fallen to $53.5K by October, so the mid-year slowdown is a trend, not a single bad month.

### Part D: Are our pricing and customer strategies working?

**Q6. "Do discounts pay for themselves?"** → *Discount impact analysis.*
**Answer:** Partly. Bigger discounts lift order size (2.0 units at 0% to 4.5 at 20%), and profit per order rises up to the 15% tier ($100 → $133). But **margin falls from 49.6% to 38.7%**, and the 20% tier earns *less* profit per order ($128) than the 15% tier. Deeper discounts stop paying.

**Q7. "The slicers let me filter by channel and customer type. Which combination is actually most valuable?"** → *Channel × customer-type profitability matrix.*
**Answer:** Corporate accounts place orders averaging **$660–$856**, more than 3× any other channel. Corporate is only **~10% of orders but ~28% of revenue**. It also carries the **deepest discounts (~12%) and the lowest margin (~42%)**. It is the biggest opportunity and the biggest margin risk at once.

---

## 5. Putting them together: what each tool alone would miss

| The dashboard shows... | ...and the SQL reveals |
|---|---|
| **Trail Boots** is the #1 seller by units (449) | It is only #3 by profit, at a **40.9% margin**, and is flagged for pricing review (Q3, Q11) |
| **Trail Bike Light** is a top-5 seller by units | It doesn't make the profit top 10. High volume, low-ticket item (Q3) |
| **Camping** is the biggest category (30.8% of revenue) | It has the **lowest margins (42–44%)**; Fitness, the smallest category, has the highest (Q8) |
| The **UK and Germany** lead the map | They are 22% of revenue, and 12 of 17 countries account for 82% (Q12) |
| Revenue **peaks in June** then declines | The slide is a real trend (moving average, Q10), and Q4 margin is also the lowest (Q5) |
| **Corporate** is one click away in the Sales Channel slicer | It is ~10% of orders, ~28% of revenue, and has the weakest margin (Q7) |

## 6. Recommendations

| # | Action | Evidence |
|---|---|---|
| 1 | **Cap standard discounts at 10%** and require approval above it | Q6: the 20% tier earns less profit per order than 15%, with margins about 11 points below full price |
| 2 | **Reprice or renegotiate cost on Alpine Tent 4P and Trail Boots** | Q11: 37.1% and 40.9% margins on $124K combined revenue; Trail Boots is the #1 seller by units (D5) |
| 3 | **Put discount governance on Corporate accounts** | Q7: 28% of revenue at ~42% margin with ~12% average discounts |
| 4 | **Push higher-margin Fitness and Travel accessories alongside Camping and Hiking purchases** | D4 + Q8: Fitness is only 8.6% of revenue but earns up to 53% margin vs 42% for Camping |
| 5 | **Plan a targeted Q4 campaign and protect Q2–Q3 momentum** | D2 + Q4/Q5/Q10: four consecutive monthly declines after the June peak |
| 6 | **Localise stocking by region** | Q9: each region has a different top seller |
| 7 | **Dashboard v2: add gross margin %, average discount and margin by category** | The dashboard currently shows only revenue and profit totals, so managers can't see the margin problems SQL uncovered |

## 7. Limitations

- **One year of data.** There is no prior year to confirm that the mid-year peak is seasonality and not a one-off, so the trend findings describe a pattern and do not prove a cause.
- **Gross margin only.** Shipping, marketing, returns and overheads are not in the data, so "profit" here means gross profit.
- **Correlation, not causation.** Discounted orders are larger, but the data cannot show whether discounts *caused* the larger orders.
- **Orders dated through December 2026**, later than the date this analysis was written. The data appears to be synthetic or projected, so treat the figures as illustrative.

## 8. Skills demonstrated

**Excel:** PivotTables · slicers and timelines connected across multiple PivotTables · KPI cards · filled map chart · line and bar charts · drill-through to underlying orders · dashboard layout.
**SQL:** data cleaning and type casting · aggregation · CTEs · window functions (`LAG`, `RANK`, `ROW_NUMBER`, running totals, moving averages, partitioned shares) · cumulative share (Pareto) · `CASE` logic · benchmarking against company averages.
**Analysis:** choosing the right tool for the question · cross-validating two tools against each other · translating a business brief into queries and findings into recommendations.

## 9. Repo structure

```
├── README.md
├── Interactive_Excel_Sales_Dashboard.xlsx   # Part 1: dashboard
├── sales_analysis_mysql.sql                 # Part 2: setup + all 12 queries
├── dataset.csv
└── images/
    └── dashboard.png                        # screenshot of the dashboard
```