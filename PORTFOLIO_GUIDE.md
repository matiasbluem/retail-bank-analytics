# NorthBridge Bank Analytics — Portfolio Packaging Guide

## 1. Resume Bullets

Pick 2–3 depending on space. The first is the master bullet — use it if you can only pick one.

---

**Master bullet (use this one):**

> Designed and delivered a 7-phase retail banking churn analytics engagement for a simulated GTA market — built a 10,000-customer synthetic dataset calibrated to Toronto CMA demographics, trained XGBoost and logistic regression churn models (AUC 0.730), applied SHAP explainability, conducted a fairness audit identifying a 5.7x disparate impact across immigration status groups, and implemented isotonic calibration reducing Brier score by 54%; delivered Python, SQL (25 queries), Power BI DAX model, interactive dashboard, and five formal reports

---

**Shorter version (tight resume, ~2 lines):**

> Built an end-to-end retail banking churn analytics project targeting the GTA market — XGBoost + logistic regression models (AUC 0.730), SHAP explainability, fairness audit, isotonic calibration, CLV-weighted retention targeting; Python, SQL, Power BI, 7 phases of formal deliverables

---

**Bullet emphasizing model risk / governance angle:**

> Conducted a model risk review on a churn prediction model — identified 5.7x disparate flagging rate across immigration status groups, systematic overconfidence (Brier 0.212), and operationally unworkable cost-optimal threshold; implemented fixes reducing disparate impact by 30% and Brier score by 54%; documented in compliance-style model card and risk review reports

---

**Bullet emphasizing technical stack (for ATS-heavy applications):**

> GTA retail banking churn analytics project: Python (pandas, XGBoost, scikit-learn, SHAP, matplotlib), ANSI SQL (PostgreSQL-compatible), Power BI (star schema, DAX), logistic regression, isotonic calibration, disparate impact analysis, CLV modeling, 10,000-customer synthetic dataset calibrated to Statistics Canada demographic signals

---

## 2. Where to Put It on Your Resume

Under **Projects & Leadership** (your current section ordering). The project title should be:

**NorthBridge Bank — Retail Banking Churn Analytics** | *Python · SQL · XGBoost · SHAP · Power BI*

Then 2–3 bullets underneath, not more. Your resume is already at 91/100 ATS — don't expand the section to the point of crowding out your work experience.

---

## 3. GitHub Upload — Step by Step

1. Go to **github.com** → click the **+** icon → **New repository**
2. Name it: `northbridge-bank-analytics`
3. Set to **Public**
4. Do NOT initialize with a README (you have one already)
5. Click **Create repository**
6. On your computer, unzip `northbridge-bank-analytics.zip`
7. Open Terminal in the `repo/` folder that appears
8. Run these commands:

```bash
git init
git add .
git commit -m "Initial commit: NorthBridge Bank retail banking churn analytics"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/northbridge-bank-analytics.git
git push -u origin main
```

9. Go back to GitHub and confirm everything uploaded
10. The README will render automatically on the repo homepage — check that the images load

---

## 4. How to Link It

On your resume, after the project title line, add:
`github.com/YOUR_USERNAME/northbridge-bank-analytics`

On LinkedIn: add it under **Projects** with a link to the repo.

---

## 5. Interview Talking Points (STAR Format)

Use these for "tell me about a project" questions. Adapt the length to the room.

---

### Short version (30 seconds — phone screen)

"I built a seven-phase banking analytics project simulating a churn reduction engagement
for a mid-sized Toronto bank. I built the dataset, trained XGBoost and logistic regression
models, applied SHAP to explain individual predictions, and then did something most portfolio
projects skip — I audited the model for fairness and found a 5.7x disparate flagging rate
across immigration status groups. I implemented fixes, measured the improvement, and documented
a conditional deployment recommendation rather than pretending everything was clean."

---

### Medium version (2 minutes — first-round interview)

**Situation:** A mid-sized Canadian retail bank needs to reduce churn in the GTA market
against Big Five banks and digital challengers. Churn was concentrated among young
professionals and newcomers — the two highest-growth segments.

**Task:** Build an end-to-end analytics engagement: data, segmentation, churn model,
explainability, and a deployment recommendation.

**Action:** Across seven phases — built a 10,000-customer synthetic dataset calibrated to
Toronto CMA demographics, ran SQL-based churn and CLV analytics, trained an XGBoost model
and a logistic regression baseline, applied SHAP for individual-level explanations, then
conducted a full model risk review. The risk review found three problems — calibration
failure, a 5.7x disparate impact across immigration status groups, and a cost-optimal
threshold that recommended contacting 79% of customers. I implemented isotonic calibration,
segment-aware thresholds, and a CLV-weighted contact list, then re-measured each fix
against the same test set.

**Result:** Brier score improved 54%. Disparate impact reduced to 3.97x. CLV-weighted
targeting captured 165.8% more recoverable value per contact. Final recommendation was
conditional deployment — launch for three segments where the fairness gap is smallest,
hold the other two in manual review until the remaining gap closes. I put that in writing
rather than claiming a clean result I hadn't earned.

---

### Key points to hit if they go deep on the fairness finding:

- The model flagged 89-96% of International Students and Refugees vs 16% of Canadian Born
- That's a 5.7x disparate impact ratio — well outside the conventional 4/5 rule threshold
- The root cause was Immigration_Status and correlated features (Region, tenure) doing real
  predictive work — they weren't spurious, they reflected genuine churn-rate differences,
  but the model amplified those differences beyond what the data justified
- Segment-aware thresholds narrowed the gap to 3.97x — real progress, not a full fix
- I documented what would close it further: remove/downweight those features and retrain,
  or use a fairness-constrained training objective
- Why this matters for a Risk Analyst or Data Analyst in Canadian financial services:
  OSFI and FCAC have increasing focus on model risk and fairness in retail banking —
  knowing to check for this, quantify it, and document it honestly is the practical skill

---

### If asked "why did logistic regression beat XGBoost?"

"The churn signal in this dataset is largely linear and monotonic — low balance, few products,
no direct deposit each independently push risk up, with limited interaction effects between
them. XGBoost's advantage is capturing non-linear interactions and threshold effects. When
those don't exist in the data-generating process, the extra model capacity adds variance
without adding signal. XGBoost did win on recall — catching more true churners at its optimal
threshold — which matters when the cost of missing a churner is much higher than the cost
of an unnecessary outreach call. That's a business decision, not a statistical one."

---

### If asked "what would you do differently?"

"Three things. First, I'd want to retrain with a fairness-constrained objective — something
like adversarial debiasing or a Lagrangian fairness constraint — rather than patching the
threshold after the fact. Second, I'd validate the calibration correction on a truly
held-out sample rather than a split of the training data, which would give me more
confidence in the corrected probabilities at high risk scores. Third, I'd want real
campaign data from the first quarter of retention outreach to update the cost assumptions
in the CLV-weighted targeting model — the 20% save rate I used was a planning assumption
from Phase 4, not an empirical measurement."

---

## 6. One-Line Descriptions for LinkedIn / Cover Letters

**Short:**
"End-to-end retail banking churn analytics project — Python, XGBoost, SHAP, SQL, Power BI,
fairness audit, 7 phases of formal deliverables targeting the GTA market."

**With a hook:**
"Built a retail banking churn analytics project that identified a 5.7x disparate impact in
model predictions, implemented a fix, and documented a conditional deployment recommendation
— because a clean result you haven't earned is worse than an honest partial one."

---

*NorthBridge Bank Analytics Portfolio Project — github.com/YOUR_USERNAME/northbridge-bank-analytics*
