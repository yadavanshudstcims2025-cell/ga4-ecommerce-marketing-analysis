# E-commerce Marketing Analytics: GA4 Sample Data (BigQuery SQL)

An end-to-end marketing analysis of about 360,000 website sessions from the Google Merchandise Store. I used BigQuery SQL to measure channel performance, the purchase funnel, and visitor segments, then used hypothesis tests to check which differences are statistically real.

**Status:** Analysis complete. Looker Studio dashboard: *planned (not built yet)*.

## Business questions

1. Which traffic channels bring sessions, purchases and revenue?
2. Where do shoppers drop out of the purchase funnel?
3. Do returning visitors convert better than new visitors? Does device matter?
4. Is paid search converting differently from organic search?

## Data

- Source: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` (Google's public GA4 sample, Google Merchandise Store)
- Period: 1 Nov 2020 to 31 Jan 2021
- Size: about 360K sessions, 4,848 purchase sessions, $362,165 revenue, overall session conversion about 1.35%
- The data is obfuscated sample data from Google, not a real company's private data.

## Tools

BigQuery (free sandbox) and Standard SQL (CTEs, `UNNEST` of `event_params`, `COUNT(DISTINCT IF(...))`, wildcard tables), Google Sheets for result tables, Python (`math` only) for statistical tests.

## Method

1. Built a session ID from `user_pseudo_id` + `ga_session_id`.
2. Ran four SQL queries (`ga4_queries.sql`): daily overview, channel performance, funnel, user segments.
3. Cross-checked totals: daily revenue sums exactly to $362,165. Daily purchase sessions (4,851) differ slightly from the total (4,848) because a few sessions cross midnight.
4. Compared conversion rates with two-proportion z-tests and 95% confidence intervals (`analysis_tests.py`).

Conversion rate = purchase sessions / sessions.

## Results

### Channels (by first-visit source / medium)

| Source / medium | Sessions | Conversion | Share of revenue |
|---|---:|---:|---:|
| google / organic | 112,678 | 1.11% | 26.4% |
| (direct) / (none) | 83,459 | 1.29% | 22.0% |
| (data deleted) | 22,233 | 3.14% | 13.8% |
| shop.googlemerchandisestore.com / referral | 28,849 | 2.03% | 12.8% |
| \<Other\> / referral | 34,672 | 1.36% | 10.2% |
| \<Other\> / \<Other\> | 52,057 | 0.97% | 9.8% |
| google / cpc | 15,617 | 0.98% | 2.5% |
| \<Other\> / organic | 10,163 | 0.95% | 2.3% |

### Purchase funnel

| Step | Sessions | % of all sessions | Lost vs previous step |
|---|---:|---:|---:|
| Session start | 354,857 | 100% | |
| View item | 77,020 | 21.70% | 78.3% |
| Add to cart | 15,188 | 4.28% | 80.3% |
| Begin checkout | 11,106 | 3.13% | 26.9% |
| Purchase | 4,848 | 1.37% | **56.3%** |

### Segments

| Segment | Sessions | Conversion | Revenue / session | Share of revenue |
|---|---:|---:|---:|---:|
| New visitors | 261,238 | 0.68% | $0.47 | 33.6% |
| Returning visitors | 98,891 | 3.10% | $2.43 | 66.4% |
| Desktop | 208,942 | 1.32% | $1.00 | 57.7% |
| Mobile | 143,185 | 1.39% | $1.03 | 40.5% |
| Tablet | 8,002 | 1.30% | $0.82 | 1.8% |

### Monthly trend

| Month | Sessions | Conversion | Revenue | Revenue / session |
|---|---:|---:|---:|---:|
| Nov 2020 | 108,688 | 1.49% | $144,260 | $1.33 |
| Dec 2020 | 133,668 | 1.58% | $160,555 | $1.20 |
| Jan 2021 | 118,618 | 0.94% | $57,350 | $0.48 |

Other patterns: best revenue day was 30 Nov ($11,990, Cyber Monday period); purchases roughly halve on 19 to 20 Dec (a possible shipping-cutoff effect, which is a hypothesis, not tested); Sunday is the weakest day.

### Statistical tests (two-proportion z-test, 95% CI for difference)

| Comparison | Rates | Difference (95% CI) | Result |
|---|---|---|---|
| Returning vs new | 3.10% vs 0.68% | +2.42 pp (+2.31 to +2.53) | z = 56.3, p < 0.001 |
| Desktop vs mobile | 1.32% vs 1.39% | -0.08 pp (-0.16 to 0.00) | z = -1.96, p = 0.050 (borderline, tiny effect) |
| Desktop vs mobile, new visitors | 0.66% vs 0.71% | -0.05 pp (-0.11 to +0.02) | p = 0.145, not significant |
| Desktop vs mobile, returning visitors | 3.05% vs 3.18% | -0.13 pp (-0.36 to +0.09) | p = 0.246, not significant |
| Paid search vs organic search | 0.98% vs 1.11% | -0.13 pp (-0.30 to +0.04) | p = 0.144, not significant |

## Key findings and recommendations

1. **Returning visitors are the most valuable segment.** They are 27.5% of sessions but 66.4% of revenue and convert about 4.5x more than new visitors. Retention (email, remarketing, loyalty offers) is a strong lever.
2. **Checkout is the largest late-funnel leak.** 56% of sessions that begin checkout do not purchase. Investigate checkout friction (shipping costs, payment options, form length) and consider cart-recovery emails.
3. **Device is not a meaningful driver of conversion.** Mobile and desktop convert almost equally, so mobile traffic should not be treated as a problem on this evidence.
4. **No evidence that paid search converts worse than organic.** The difference is within noise; the paid sample is also small (15.6K sessions). A cost-based (ROAS) comparison needs ad spend data, which this dataset lacks.
5. **January revenue per session fell sharply** after the holiday season (see data-quality note about late January).

## Data quality notes and limitations

- **Observational data.** Differences describe association, not causation. Returning visitors may simply be more motivated buyers.
- **First-visit source.** `traffic_source` in this dataset is the user's first-visit source, not the source of each session, so channel results show acquisition source rather than last-click attribution.
- **Masked values.** `(data deleted)` and `<Other>` are obfuscated by Google and cannot be interpreted. `(data deleted)` converts at 3.14% but its meaning is unknown.
- **Order IDs missing early on.** The `orders` count is 0 to 1 per day for 1 to 10 Nov (missing transaction IDs), so order counts are unreliable for that period. Purchase sessions are used instead.
- **Revenue near zero 26 to 31 Jan** while purchase sessions stay steady, so late-January revenue is incomplete and inflates the apparent January drop.
- **Session count mismatch.** `session_start` events give 354,857 sessions versus about 360K sessions by session ID, because some sessions do not have a `session_start` in the window. The funnel uses the former.
- **Sessions are not independent** (one user can have many sessions), so z-test p-values are somewhat optimistic. The returning-vs-new result is so large that it is unaffected; the borderline device result should be read cautiously.
- **Own-site referral.** The store's own domain appears as a referral source, which reflects tracking setup rather than a real marketing channel.
- Many significance tests were run; the borderline p = 0.050 should not be over-interpreted.

## Dashboard (planned)

A Looker Studio dashboard (overview, channels, funnel, segments) is planned. It is not built yet and will be linked here when complete.

## Repository contents

| File | Description |
|---|---|
| `ga4_queries.sql` | The four BigQuery queries used |
| `analysis_tests.py` | Z-tests, confidence intervals, funnel percentages (`python analysis_tests.py`) |
| `README.md` | This report |

## How to reproduce

1. Open [BigQuery](https://console.cloud.google.com/bigquery) (the free sandbox is enough).
2. Run each query in `ga4_queries.sql` and export results to CSV or Google Sheets.
3. Run `python analysis_tests.py` (Python 3, no extra packages).

## Author

Anshu Yadav, M.Sc. Statistics and Computing, Banaras Hindu University.
