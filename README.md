# Where Is Our Profit Going? A SQL Sales Analysis

> **12 SQL queries on 2,707 orders ($645K revenue) to find where a European outdoor-gear retailer makes money, where it leaks margin, and what to do about it.**

**Tools:** MySQL 8 · CTEs · window functions (`LAG`, `RANK`, `ROW_NUMBER`, running totals, moving averages) · data cleaning with views

---

## 1. The business scenario

*A European retailer of hiking, camping, cycling, travel and fitness gear sells through four channels (online store, retail partners, marketplaces and corporate accounts) in 17 countries. Leadership has noticed that revenue peaked mid-year and has drifted down since, and that discounting has become routine.*

**The brief from the Head of Commercial:**

> "We did about $645K in 2026, but growth has stalled since Q2 and I suspect we are giving margin away. Before planning next year, tell me:
> **where do we actually make money, where are we leaking it, and what should we change?**"

This project answers that brief in four parts. Every query below is the direct answer to one specific question.

## 2. The data

`dataset.csv`: one row per order, 20 columns, 2,707 rows, no nulls, no duplicate IDs.

| Group | Columns |
|---|---|
| Where / how | Region (4), Country (17), Sales Channel (4), Customer Type (3) |
| What | Product Category (5), Product (20) |
| Price & profit | Units Sold, Unit Price, Discount %, Unit Cost, Revenue, COGS, Gross Profit, Gross Margin % |
| When | Order Date, Year, Quarter, MonthNo, Month |

**Cleaning:** money and percentages arrive as text (`$82.06`, `15%`). The script loads everything as text, then a `sales` view strips the symbols and casts to proper types. All 12 queries run on that view.

**A note on margin:** every margin in this project is `SUM(profit) / SUM(revenue)`, not an average of the per-order margin column. Averaging percentages would let small orders distort the result.

## 3. How to run it

1. Open `sales_analysis_mysql.sql` in MySQL Workbench.
2. Update the file path in the `LOAD DATA LOCAL INFILE` line if your CSV is elsewhere. This needs `local_infile` enabled on the server and `OPT_LOCAL_INFILE=1` on the connection (the script explains how). Alternatively, use Workbench's Table Data Import Wizard on the `sales_raw` table.
3. Run the script top to bottom. Check that `SELECT COUNT(*) FROM sales_raw;` returns **2707**.

---

## 4. The analysis

### Part A: How big is the business, and where does it come from?

**Q1. "Give me the headline numbers."**
→ *Executive summary query (KPIs).*
**Answer:** $645.2K revenue, $296.4K gross profit, a **45.9% gross margin**, from 2,707 orders averaging $238.

**Q2. "Which regions carry the business, and do any earn worse margins?"**
→ *Regional performance with share of total (window function over an aggregate).*
**Answer:** Western Europe (30.7%) and Central Europe (29.6%) generate about **60% of revenue**. Margins are nearly identical across regions (45.6–46.3%), so regional differences are about volume, not profitability.

**Q12. "How concentrated is revenue? Which countries truly matter?"**
→ *Pareto analysis (cumulative share with a running window).*
**Answer:** **12 of 17 countries produce 82% of revenue.** The UK (11.5%) and Germany (10.9%) alone account for 22%. Five countries (Belgium, Switzerland, Finland, Czechia, Ireland) form a long tail.

### Part B: Which products earn the money, and which leak it?

**Q3. "Which products actually make the profit?"**
→ *Top 10 products by gross profit.*
**Answer:** Summit Backpack 45L leads on profit ($29.6K), followed by Trail Tent 2P and Trail Boots. Ranking by profit instead of revenue matters here because Alpine Tent 4P is #2 by revenue but only #5 by profit.

**Q11. "Are any big sellers quietly under-earning?"**
→ *High-revenue, low-margin products (CTEs, benchmark, CASE flag).*
**Answer:** **Alpine Tent 4P** is the clearest leak: $63.7K revenue at a **37.1% margin**, 9 points below company average, and it carries a 6.3% average discount against 5.1% company-wide. **Trail Boots** (40.9%) is next. Both are flagged `REVIEW PRICING`.

**Q8. "Does the product mix differ by region, and does mix affect margin?"**
→ *Category mix within each region (`SUM() OVER (PARTITION BY region)`).*
**Answer:** Camping is the top or second category everywhere (26–34% of regional revenue) but has the **lowest margins (42–44%)**. Fitness is the smallest category (8–10%) but has the **highest (49–53%)**. The business leans on its lowest-margin category.

**Q9. "What should each regional manager stock first?"**
→ *Top 3 products per region (`ROW_NUMBER` in a CTE).*
**Answer:** Every region has a different #1: Alpine Tent 4P (Central), Trail Tent 2P (Northern), Compact Sleeping Bag (Southern), Summit Backpack 45L (Western). One pan-European stocking plan would miss local demand.

### Part C: What is the trend?

**Q4. "Are we growing, and is there seasonality?"**
→ *Monthly revenue with month-over-month growth (`LAG`).*
**Answer:** Revenue climbed from $35.6K in February to a **June peak of $69.5K**, then fell four months in a row (to $49.1K in October). November rebounded to $65.5K, then December dropped 22%.

**Q5. "How do the quarters compare, in revenue and margin?"**
→ *Quarterly performance with quarter-over-quarter change.*
**Answer:** Q1→Q2 grew **52.7%**, but every quarter since has declined (Q3 −2.6%, Q4 −6.7%). Q4 also has the **lowest margin (44.6%** vs 46.8% in Q3), so volume and profitability are both softening.

**Q10. "Strip out the noise: what is the underlying trend and how are we tracking year to date?"**
→ *Cumulative revenue and 3-month moving average (window frames).*
**Answer:** The moving average peaked at **$64.7K in July** and had fallen to $53.5K by October, confirming that the mid-year slowdown is a trend and not a single bad month. Year-to-date reaches $645K by December.

### Part D: Are our pricing and customer strategies working?

**Q6. "Do discounts pay for themselves?"**
→ *Discount impact analysis.*
**Answer:** Partly. Bigger discounts do lift order size (2.0 units at 0% to 4.5 at 20%) and profit per order rises up to the 15% tier ($100 → $133). But **margin falls from 49.6% to 38.7%**, and the 20% tier earns *less* profit per order ($128) than the 15% tier. Deeper discounts stop paying.

**Q7. "Which channel and customer combination is most valuable, and most risky?"**
→ *Channel × customer-type profitability matrix.*
**Answer:** Corporate accounts place orders averaging **$660–$856**, more than 3× any other channel. Corporate is only **~10% of orders but ~28% of revenue**. It also carries the **deepest discounts (~12%) and the lowest margin (~42%)**. It is the biggest opportunity and the biggest margin risk at once.

---

## 5. Recommendations

| # | Action | Evidence |
|---|---|---|
| 1 | **Cap standard discounts at 10%** and require approval above it | Q6: 20% tier earns less profit per order than 15%, with margins about 11 points lower than full price |
| 2 | **Reprice or renegotiate cost on Alpine Tent 4P and Trail Boots** | Q11: 37.1% and 40.9% margins on $124K combined revenue |
| 3 | **Put discount governance on Corporate accounts** | Q7: 28% of revenue at ~42% margin, with ~12% average discounts |
| 4 | **Push higher-margin Fitness and Travel accessories alongside Camping and Hiking purchases** | Q8: Fitness margins reach 53% vs 42% for Camping |
| 5 | **Plan a targeted Q4 campaign and protect Q2–Q3 momentum** | Q4/Q5/Q10: four consecutive monthly declines after the June peak |
| 6 | **Localise stocking by region** | Q9: each region has a different top seller |

## 6. Limitations

- **One year of data.** There is no prior year to confirm that the mid-year peak is seasonality and not a one-off, so Q4, Q5 and Q10 describe a pattern and do not prove a cause.
- **Gross margin only.** Shipping, marketing, returns and overheads are not in the data, so "profit" here means gross profit.
- **Correlation, not causation.** Discounted orders are larger, but the data cannot show whether discounts *caused* the larger orders.
- **Orders dated through December 2026**, which is later than the date this analysis was written. The data appears to be synthetic or projected, so treat the figures as illustrative.

## 7. Skills demonstrated

Data cleaning and type casting · aggregation · CTEs · window functions (`LAG`, `RANK`, `ROW_NUMBER`, running totals, moving averages, partitioned shares) · cumulative share (Pareto) · CASE logic · benchmarking against company averages · translating a business brief into queries and findings into recommendations.

## 8. Repo structure

```
├── README.md
├── sales_analysis_mysql.sql   # setup + all 12 queries
└── dataset.csv
```
