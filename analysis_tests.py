"""Statistical tests for the GA4 e-commerce analysis.

The counts below are copied from the BigQuery result tables (see ga4_queries.sql).
Each test is a two-proportion z-test on session conversion rate
(purchase sessions / sessions) with a 95% confidence interval for the difference.

Run:  python analysis_tests.py
"""
import math


def norm_cdf(x):
    return 0.5 * math.erfc(-x / math.sqrt(2))


def two_prop_test(n1, x1, n2, x2):
    p1, p2 = x1 / n1, x2 / n2
    pooled = (x1 + x2) / (n1 + n2)
    se_pooled = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    z = (p1 - p2) / se_pooled
    p_value = 2 * (1 - norm_cdf(abs(z)))
    se_diff = math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    ci = (p1 - p2 - 1.96 * se_diff, p1 - p2 + 1.96 * se_diff)
    return p1, p2, z, p_value, ci


def report(title, label1, n1, x1, label2, n2, x2):
    p1, p2, z, p, ci = two_prop_test(n1, x1, n2, x2)
    print(title)
    print(f"  {label1}: {x1:,} / {n1:,} = {p1:.3%}")
    print(f"  {label2}: {x2:,} / {n2:,} = {p2:.3%}")
    print(f"  difference ({label1} - {label2}): {p1 - p2:+.3%}  (95% CI {ci[0]:+.3%} to {ci[1]:+.3%})")
    p_text = "p < 0.001" if p < 0.001 else f"p = {p:.3f}"
    print(f"  z = {z:.2f}, {p_text}\n")


# (sessions, purchase_sessions, revenue) from the new-vs-returning-by-device query
segments = {
    ("New", "desktop"): (151750, 1006, 70730),
    ("New", "mobile"): (103615, 737, 49502),
    ("New", "tablet"): (5873, 37, 1436),
    ("Returning", "desktop"): (57192, 1743, 138085),
    ("Returning", "mobile"): (39570, 1258, 97266),
    ("Returning", "tablet"): (2129, 67, 5146),
}


def total(match):
    n = x = r = 0
    for key, (s, p, rev) in segments.items():
        if match(key):
            n, x, r = n + s, x + p, r + rev
    return n, x, r


new = total(lambda k: k[0] == "New")
ret = total(lambda k: k[0] == "Returning")
desk = total(lambda k: k[1] == "desktop")
mob = total(lambda k: k[1] == "mobile")

report("1. Returning vs new visitors", "returning", ret[0], ret[1], "new", new[0], new[1])
report("2. Desktop vs mobile (all visitors)", "desktop", desk[0], desk[1], "mobile", mob[0], mob[1])

for user_type in ("New", "Returning"):
    d = segments[(user_type, "desktop")]
    m = segments[(user_type, "mobile")]
    report(f"3. Desktop vs mobile within {user_type.lower()} visitors",
           "desktop", d[0], d[1], "mobile", m[0], m[1])

# (sessions, purchase_sessions) from the channel query
organic = (112678, 1250)   # google / organic
paid = (15617, 153)        # google / cpc
report("4. Paid search vs organic search", "google / cpc", paid[0], paid[1],
       "google / organic", organic[0], organic[1])

print("Revenue share of returning visitors: "
      f"{ret[2] / (ret[2] + new[2]):.1%}; session share: {ret[0] / (ret[0] + new[0]):.1%}")

# Funnel (sessions reaching each step)
funnel = [("Session start", 354857), ("View item", 77020), ("Add to cart", 15188),
          ("Begin checkout", 11106), ("Purchase", 4848)]
print("\nFunnel")
for i, (name, n) in enumerate(funnel):
    pct_start = n / funnel[0][1]
    lost = "" if i == 0 else f", lost vs previous step: {1 - n / funnel[i - 1][1]:.1%}"
    print(f"  {name}: {n:,} ({pct_start:.2%} of sessions{lost})")
