# MarketCo Customer Behaviour Analysis (SQL, BigQuery)

An analysis of 21,618 customers and 143,785 contracts for MarketCo, an anonymised omnichannel retailer. Using SQL in Google BigQuery, the project compares Gold Members with non-members, profiles customers by age, state, gender and technology, and turns the findings into four recommendations.

The full written analysis is in [`report.md`](report.md). Every query behind it is in [`queries.sql`](queries.sql).

## Business questions

- Do customers who hold, or once held, a Gold Membership behave differently from customers who never did?
- How do spending, contract volume and communication vary by age, tenure, state, gender, operating system and browser?
- What should MarketCo do differently, and what data is missing?

## Data

Two tables, linked by `Cost_ID`:

| Table | Rows | Contents |
|---|---|---|
| `customer` | 21,618 | Age, gender, state, tenure, affluence level, inbound and outbound communication counts (24 and 60 months), operating system, browser |
| `contract` | 143,785 | Product, amount paid, start and end dates, one row per contract |

The data was supplied for a university unit and is not redistributed in this repository. To reproduce the analysis, load the two tables into a BigQuery dataset named `mis784` (as `customer` and `contract`) and run `queries.sql` in order.

## Approach

- **Aggregate before joining.** A customer can hold many contracts, so contract data is summarised to one row per customer before it is joined to customer attributes. Joining first would repeat each customer's attributes once per contract and distort every average.
- **Keep customers with no contracts.** Averages use a `LEFT JOIN` from the customer table with `COALESCE(..., 0)`, so the 4,734 customers who never bought are counted rather than silently dropped.
- **Three Gold Membership groups instead of two.** Customers are split into Active, Former and Never members. A simple member versus non-member split would mix former members into the comparison group and hide the fact that they are the weakest group.
- **Test explanations rather than assume them.** Each pattern was checked against alternative explanations (tenure, income, product mix, price per contract) before being reported.

SQL techniques used: CTEs, `CASE` bucketing, conditional counting with `COUNTIF`, `LEFT JOIN` versus `JOIN`, subqueries, `NOT EXISTS`, `STDDEV`, and per-customer decomposition by product.

## Key findings

- **Contract volume drives spending.** The number of contracts a customer holds explains spending differences by age, state and market. Value per contract is almost fixed within each product.
- **Age.** Customers over 55 spend up to 4.6 times as much as customers aged 18 to 30, because they hold more contracts (8.43 versus 2.39 on average) and have longer tenure. Income level does not explain the gap.
- **Gold Membership.** The 1,363 former members are the least active group on every measure, below even customers who never tried the membership.
- **Communication does not predict spending.** International customers communicate the most but spend 36% less than customers in Australian states, because they transact less often.
- **Technology.** Operating system and browser show little difference in customer value.
- **Gender.** Female customers hold more contracts, but male customers spend about 10% more, mainly through more cruise contracts.

## Recommendations

1. Run a dedicated win-back campaign for former Gold Members.
2. Encourage early transactions among customers under 30.
3. Collect bounce and conversion rates by platform before investing in any one operating system or browser.
4. Pilot on a small scale before expanding international marketing.

## Limitations

About 10% of contracts (14,574) have no matching customer record and differ from linked contracts in product mix and value, so the customer-level findings describe the linked 90%. The analysis is observational, several groups are small (International has 190 customers), and the data holds no website performance measures. Details are in the Limitations section of the report.

## Skills demonstrated

SQL analysis in BigQuery, join design for one-to-many data, checking data quality and coverage, testing alternative explanations, and writing findings for a non-technical audience.
