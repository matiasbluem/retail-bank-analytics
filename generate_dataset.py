import pandas as pd
import numpy as np
from datetime import date, timedelta
import os

rng = np.random.default_rng(42)
N = 10_000

SEGMENTS = {
    "Young Professionals": 3152,
    "Families":            2586,
    "Newcomers to Canada": 2216,
    "Students":            1181,
    "Affluent Customers":   865,
}

REGIONS = ["Downtown Toronto","North York","Scarborough","Etobicoke",
           "Mississauga","Brampton","Markham","Richmond Hill","Vaughan","Other GTA"]
REGION_WEIGHTS = [0.18,0.12,0.12,0.08,0.14,0.10,0.08,0.07,0.07,0.04]

OCCUPATIONS = {
    "Young Professionals": ["Software Engineer","Financial Analyst","Marketing Manager","Nurse","Accountant","Engineer","Sales Manager","HR Specialist"],
    "Families":            ["Teacher","Police Officer","Tradesperson","Nurse","Engineer","Business Owner","Accountant","Government Worker"],
    "Newcomers to Canada": ["Driver","Warehouse Worker","Customer Service Rep","Caregiver","IT Specialist","Healthcare Worker","Restaurant Worker","Student"],
    "Students":            ["Student","Part-time Retail","Part-time Food Service","Intern","Tutor","TA"],
    "Affluent Customers":  ["Executive","Partner","Physician","Lawyer","Investment Banker","Business Owner","CFO"],
}
INCOME_BANDS = {
    "Young Professionals": ["$50K-$75K","$75K-$100K","$100K-$150K"],
    "Families":            ["$75K-$100K","$100K-$150K","$150K+"],
    "Newcomers to Canada": ["Under $30K","$30K-$50K","$50K-$75K"],
    "Students":            ["Under $30K","$30K-$50K"],
    "Affluent Customers":  ["$150K+","$200K+"],
}
IMMIGRATION = {
    "Young Professionals": ["Canadian Born","Permanent Resident","Temporary Resident"],
    "Families":            ["Canadian Born","Permanent Resident"],
    "Newcomers to Canada": ["Permanent Resident","Temporary Resident","International Student","Refugee"],
    "Students":            ["Canadian Born","International Student"],
    "Affluent Customers":  ["Canadian Born","Permanent Resident"],
}
CHURN_BASE = {
    "Students":0.2591,"Newcomers to Canada":0.2319,
    "Young Professionals":0.0933,"Families":0.0275,"Affluent Customers":0.0162,
}
PRODUCTS = ["Chequing","Savings","Credit Card","Student Account","Mortgage",
            "Personal Loan","Line of Credit","TFSA","RRSP","GIC","Investment Account"]
PRODUCT_PROBS = {
    "Students":            [0.90,0.70,0.45,0.85,0.00,0.05,0.05,0.20,0.05,0.10,0.05],
    "Young Professionals": [0.95,0.80,0.75,0.00,0.20,0.15,0.20,0.65,0.50,0.20,0.35],
    "Families":            [0.95,0.85,0.75,0.00,0.65,0.25,0.35,0.60,0.65,0.25,0.25],
    "Newcomers to Canada": [0.92,0.78,0.55,0.00,0.08,0.12,0.10,0.35,0.10,0.30,0.10],
    "Affluent Customers":  [0.90,0.85,0.80,0.00,0.45,0.10,0.30,0.85,0.85,0.60,0.90],
}
BAL = {
    "Chequing":           {"Students":(800,400),"Young Professionals":(3500,2000),"Families":(5000,2500),"Newcomers to Canada":(1500,800),"Affluent Customers":(12000,6000)},
    "Savings":            {"Students":(500,300),"Young Professionals":(8000,5000),"Families":(18000,10000),"Newcomers to Canada":(3000,1500),"Affluent Customers":(50000,30000)},
    "Credit Card":        {"Students":(600,400),"Young Professionals":(3500,2000),"Families":(5000,2500),"Newcomers to Canada":(1200,700),"Affluent Customers":(8000,4000)},
    "Student Account":    {"Students":(400,200),"Young Professionals":(0,0),"Families":(0,0),"Newcomers to Canada":(0,0),"Affluent Customers":(0,0)},
    "Mortgage":           {"Students":(0,0),"Young Professionals":(380000,80000),"Families":(520000,120000),"Newcomers to Canada":(310000,70000),"Affluent Customers":(750000,200000)},
    "Personal Loan":      {"Students":(3000,1500),"Young Professionals":(15000,8000),"Families":(22000,10000),"Newcomers to Canada":(8000,4000),"Affluent Customers":(30000,15000)},
    "Line of Credit":     {"Students":(2000,1000),"Young Professionals":(20000,10000),"Families":(35000,15000),"Newcomers to Canada":(10000,5000),"Affluent Customers":(80000,40000)},
    "TFSA":               {"Students":(1500,800),"Young Professionals":(18000,10000),"Families":(35000,15000),"Newcomers to Canada":(5000,3000),"Affluent Customers":(75000,30000)},
    "RRSP":               {"Students":(500,300),"Young Professionals":(25000,15000),"Families":(60000,30000),"Newcomers to Canada":(8000,4000),"Affluent Customers":(200000,100000)},
    "GIC":                {"Students":(2000,1000),"Young Professionals":(10000,5000),"Families":(20000,10000),"Newcomers to Canada":(8000,4000),"Affluent Customers":(80000,40000)},
    "Investment Account": {"Students":(1000,500),"Young Professionals":(30000,20000),"Families":(45000,25000),"Newcomers to Canada":(5000,3000),"Affluent Customers":(250000,150000)},
}

def revenue(prod, bal):
    if prod in ("Chequing","Student Account"): return round(rng.uniform(3,16),2)
    if prod == "Savings": return round(bal*rng.uniform(0.001,0.003),2)
    if prod == "Credit Card": return round(bal*rng.uniform(0.015,0.025),2)
    if prod == "Mortgage": return round(bal*rng.uniform(0.0015,0.003),2)
    if prod in ("Personal Loan","Line of Credit"): return round(bal*rng.uniform(0.005,0.015),2)
    return round(bal*rng.uniform(0.003,0.008),2)

# --- Customer Master ---
rows = []
cid = 1000001
for seg, count in SEGMENTS.items():
    for _ in range(count):
        if seg=="Students": age=int(rng.integers(18,27))
        elif seg=="Young Professionals": age=int(rng.integers(24,40))
        elif seg=="Families": age=int(rng.integers(30,55))
        elif seg=="Newcomers to Canada": age=int(rng.integers(22,50))
        else: age=int(rng.integers(40,75))
        tenure=round(float(rng.uniform(0.25,15)),2)
        hs_p=[0.3,0.3,0.2,0.15,0.05] if seg!="Families" else [0.05,0.15,0.30,0.35,0.15]
        rows.append({
            "Customer_ID":cid,"Segment":seg,"Age":age,
            "Gender":rng.choice(["Male","Female","Non-binary/Other"],p=[0.48,0.49,0.03]),
            "Occupation":rng.choice(OCCUPATIONS[seg]),
            "Income_Band":rng.choice(INCOME_BANDS[seg]),
            "Immigration_Status":rng.choice(IMMIGRATION[seg]),
            "Region":rng.choice(REGIONS,p=REGION_WEIGHTS),
            "Household_Size":int(rng.choice([1,2,3,4,5],p=hs_p)),
            "Relationship_Status":rng.choice(["Single","Married","Common-law","Divorced","Widowed"],p=[0.40,0.35,0.15,0.08,0.02]),
            "Years_With_Bank":tenure,
            "Has_Direct_Deposit":int(rng.random()<(0.75 if seg in ("Young Professionals","Families","Affluent Customers") else 0.55)),
            "Churn_Flag":int(rng.random()<CHURN_BASE[seg]),
        })
        cid+=1
cm=pd.DataFrame(rows)
print(f"Customers: {len(cm)} | Churn: {cm.Churn_Flag.mean():.2%}")

# --- Product Holdings ---
ph=[]
for _,r in cm.iterrows():
    seg=r.Segment
    for prod,prob in zip(PRODUCTS,PRODUCT_PROBS[seg]):
        if rng.random()<prob:
            bp=BAL[prod][seg]
            bal=max(0,round(rng.normal(bp[0],bp[1]),2)) if bp[1]>0 else 0.0
            od=(date(2025,1,1)-timedelta(days=int(r.Years_With_Bank*365))).strftime("%Y-%m-%d")
            ph.append({"Customer_ID":r.Customer_ID,"Product":prod,"Balance":bal,
                       "Monthly_Revenue_Estimate":revenue(prod,bal),"Open_Date":od})
ph=pd.DataFrame(ph)
print(f"Products: {len(ph)}")

# --- Transaction Summary ---
txn_p={
    "Students":{"dep":(1200,500),"sp":(900,400),"bills":(3,2),"etr":(4,2)},
    "Young Professionals":{"dep":(4500,1500),"sp":(3200,1200),"bills":(6,2),"etr":(5,2)},
    "Families":{"dep":(7000,2500),"sp":(5500,2000),"bills":(9,3),"etr":(4,2)},
    "Newcomers to Canada":{"dep":(2500,1000),"sp":(2000,800),"bills":(5,2),"etr":(6,3)},
    "Affluent Customers":{"dep":(12000,5000),"sp":(8000,3500),"bills":(8,3),"etr":(3,2)},
}
txn=[]
for _,r in cm.iterrows():
    p=txn_p[r.Segment]
    for mo in range(1,13):
        txn.append({"Customer_ID":r.Customer_ID,"Year":2025,"Month":mo,
            "Total_Deposits":max(0,round(rng.normal(p["dep"][0],p["dep"][1]),2)),
            "Total_Spend":max(0,round(rng.normal(p["sp"][0],p["sp"][1]),2)),
            "Bill_Payments":max(0,int(rng.normal(p["bills"][0],p["bills"][1]))),
            "eTransfer_Count":max(0,int(rng.normal(p["etr"][0],p["etr"][1]))),
            "ATM_Withdrawals":max(0,int(rng.integers(0,5))),
        })
txn=pd.DataFrame(txn)
print(f"Transactions: {len(txn)}")

# --- Digital Engagement ---
dig_p={
    "Students":{"mob":(82,10),"onl":(70,12),"log":(18,6),"app":0.90},
    "Young Professionals":{"mob":(85,8),"onl":(78,10),"log":(22,7),"app":0.90},
    "Families":{"mob":(65,15),"onl":(60,15),"log":(14,5),"app":0.70},
    "Newcomers to Canada":{"mob":(72,12),"onl":(65,12),"log":(16,6),"app":0.75},
    "Affluent Customers":{"mob":(55,18),"onl":(52,18),"log":(10,5),"app":0.60},
}
dig=[]
for _,r in cm.iterrows():
    p=dig_p[r.Segment]
    dig.append({"Customer_ID":r.Customer_ID,
        "Mobile_Usage_Score":float(np.clip(round(rng.normal(p["mob"][0],p["mob"][1]),1),0,100)),
        "Online_Banking_Score":float(np.clip(round(rng.normal(p["onl"][0],p["onl"][1]),1),0,100)),
        "Monthly_Logins":max(0,int(rng.normal(p["log"][0],p["log"][1]))),
        "Uses_Mobile_App":int(rng.random()<p["app"]),
        "Uses_Online_Banking":int(rng.random()<0.78),
        "Has_eTransfer_Setup":int(rng.random()<(0.85 if r.Segment=="Young Professionals" else 0.70)),
        "Digital_Onboarding_Completed":int(rng.random()<(0.92 if r.Segment!="Affluent Customers" else 0.75)),
    })
dig=pd.DataFrame(dig)
print(f"Digital: {len(dig)}")

# --- Branch Interactions ---
br_p={
    "Students":{"vis":(2,2),"adv":(0.5,0.8),"cmp":(0.3,0.6)},
    "Young Professionals":{"vis":(3,2),"adv":(1.2,1.0),"cmp":(0.4,0.7)},
    "Families":{"vis":(4,2),"adv":(2.0,1.5),"cmp":(0.3,0.6)},
    "Newcomers to Canada":{"vis":(5,3),"adv":(1.5,1.2),"cmp":(0.8,1.0)},
    "Affluent Customers":{"vis":(4,2),"adv":(3.0,2.0),"cmp":(0.2,0.5)},
}
br=[]
for _,r in cm.iterrows():
    p=br_p[r.Segment]
    br.append({"Customer_ID":r.Customer_ID,
        "Branch_Visits_Annual":max(0,int(rng.normal(p["vis"][0],p["vis"][1]))),
        "Advisor_Meetings_Annual":max(0,int(rng.normal(p["adv"][0],p["adv"][1]))),
        "Service_Tickets":max(0,int(rng.integers(0,4))),
        "Complaints_Filed":max(0,int(rng.normal(p["cmp"][0],p["cmp"][1]))),
        "Product_Inquiries":max(0,int(rng.integers(0,5))),
    })
br=pd.DataFrame(br)
print(f"Branch: {len(br)}")

# --- Customer Satisfaction ---
nps_base={"Students":32,"Young Professionals":38,"Families":45,"Newcomers to Canada":28,"Affluent Customers":52}
sat=[]
for _,r in cm.iterrows():
    comp=int(br.loc[br.Customer_ID==r.Customer_ID,"Complaints_Filed"].values[0])
    nps=int(np.clip(rng.normal(nps_base[r.Segment]-comp*8,15),-100,100))
    csat=round(float(np.clip(rng.normal(3.6-comp*0.3,0.6),1,5)),1)
    sat.append({"Customer_ID":r.Customer_ID,"NPS_Score":nps,"CSAT_Score":csat,
        "Complaint_Count":comp,
        "Avg_Resolution_Days":max(0,round(float(rng.normal(3.5+comp*1.5,1.5)),1)),
        "Last_Survey_Month":int(rng.integers(1,13)),
    })
sat=pd.DataFrame(sat)
print(f"Satisfaction: {len(sat)}")

os.makedirs("/home/claude/data",exist_ok=True)
cm.to_csv("/home/claude/data/customer_master.csv",index=False)
ph.to_csv("/home/claude/data/product_holdings.csv",index=False)
txn.to_csv("/home/claude/data/transaction_summary.csv",index=False)
dig.to_csv("/home/claude/data/digital_engagement.csv",index=False)
br.to_csv("/home/claude/data/branch_interaction.csv",index=False)
sat.to_csv("/home/claude/data/customer_satisfaction.csv",index=False)
print("Done.")
