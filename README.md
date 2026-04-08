# 📊 Subscription LTV Analysis

![SQL](https://img.shields.io/badge/SQL-PostgreSQL-blue)
![Python](https://img.shields.io/badge/Python-Pandas-yellow)
![Tableau](https://img.shields.io/badge/Visualization-Tableau-orange)
![Status](https://img.shields.io/badge/Project-Completed-brightgreen)
![Focus](https://img.shields.io/badge/Focus-LTV%20%26%20Retention-purple)

---

## 🚀 Overview

This project replicates a real-world product analytics task: estimating **Customer Lifetime Value (LTV)** for a subscription-based mobile application.

The analysis includes:

* LTV calculation using a **probabilistic model**
* Retention and churn analysis
* End-to-end data pipeline
* Visualization of user behavior

---

## 💼 Business Problem

The product follows a subscription model:

* 7-day free trial
* Weekly subscription: **$4.99**
* Apple Store commission: **30%**
* Users can churn at any time

👉 Goal:

* Calculate **LTV over a 6-week horizon**
* Understand **user retention behavior**
* Support **marketing and growth decisions**

---

## 📂 Repository Structure

```
subscription_ltv_analysis/
├── data/
├── sql/
│   └── subscription_probabilistic_ltv.sql
├── notebooks/
│   └── sankey_ltv_data_for_generation.ipynb
├── results/
│   └── sankey_ltv_data.csv
├── visualizations/
│   └── ltv_sankey_final.png
└── presentation/
```

---

## 🧠 Analytical Approach

Instead of simply summing payments, this project uses a **probabilistic LTV model**:

* Each payment step is weighted by its conversion rate
* LTV reflects expected user behavior
* Based on real cohort transitions

---

## 📐 LTV Formula

**LTV = Σ (Conversion Rate × Payment Value)**

Where:

* Payment Value = **$4.99 × 0.7 = $3.493**
* Conversion rates are calculated between each step

---

## 🧮 SQL Logic (Core Calculation)

```sql
WITH user_payments AS (
    SELECT
        user_id,
        LEAST(COUNT(*), 5) AS payments
    FROM subscription_payment
    GROUP BY user_id
)

SELECT
    AVG(payments * 4.99 * 0.7) AS ltv
FROM user_payments;
```

---

## 🔄 Data Pipeline

```
Raw Data → SQL → Python → CSV → Tableau
```

* **SQL** → LTV calculation
* **Python (Jupyter)** → data preparation for Sankey
* **Tableau** → visualization

---

## 📊 Visualization

### 🔗 Interactive Dashboard (Tableau Public)

👉 https://public.tableau.com/views/ProbabilisticExpectedLTV/Sankey?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

---

### 📉 User Flow (Sankey Diagram)

![LTV Flow](visualizations/sankey_ltv_tableau.png)

---

## 📈 Key Metrics

* Trial → 1st payment: **35%**
* 1st → 2nd payment: **74%**
* 2nd → 3rd payment: **83%**
* 3rd → 4th payment: **86%**
* 4th → 5th payment: **89%**

👉 Early-stage churn is the main bottleneck
👉 Retention improves for paying users

---

## 💡 Key Insights

* The largest drop occurs at **trial → first payment**
* Users who convert once are highly likely to continue paying
* Revenue is driven by a small cohort of retained users
* LTV growth depends more on **retention than acquisition**

---

## 💼 Business Impact

This analysis helps:

* Estimate **Customer Acquisition Cost (CAC) thresholds**
* Identify **critical churn points**
* Improve **trial-to-paid conversion**
* Support **data-driven growth decisions**

---

## 🔬 Future Improvements

* Cohort-based retention analysis
* LTV by country (geo segmentation)
* Retention curves
* A/B testing for trial optimization

---

## 🛠 Tech Stack

* SQL (PostgreSQL)
* Python (Pandas, Jupyter)
* Tableau
* LaDataViz

---

## ⚙️ Reproducibility

1. Run SQL script in `/sql`
2. Execute notebook in `/notebooks`
3. Generate dataset in `/results`
4. Build dashboard in Tableau

---

## 🎯 What This Project Demonstrates

* Strong SQL and data modeling skills
* Product thinking (LTV, retention, churn)
* End-to-end analytics pipeline
* Data visualization & storytelling

---

## 👨‍💻 Author

Artem Liakh
