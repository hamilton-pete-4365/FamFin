#!/usr/bin/env python3
"""Generate realistic FamFin screenshot data - FINAL version."""

import json, random, calendar
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from collections import defaultdict

random.seed(42)

def d(v): return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
def ds(v): return str(d(v))
def iso(dt): return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
def rand_day(y,m,lo,hi):
    mx = min(hi, calendar.monthrange(y,m)[1]); lo = min(lo,mx)
    return datetime(y,m,random.randint(lo,mx),random.randint(8,20),random.randint(0,59),0)
def vary(base,pct=0.08): return d(float(base)*(1+random.uniform(-pct,pct)))

accounts = [
    {"id":"","name":"Joint Current","type":"Current","isBudget":True,"sortOrder":0,"createdAt":"2025-01-15T10:00:00Z"},
    {"id":"","name":"Savings","type":"Savings","isBudget":True,"sortOrder":1,"createdAt":"2025-01-15T10:00:00Z"},
    {"id":"","name":"Credit Card","type":"Credit Card","isBudget":True,"sortOrder":2,"createdAt":"2025-01-15T10:00:00Z"},
    {"id":"","name":"ISA","type":"Savings","isBudget":False,"sortOrder":3,"createdAt":"2025-01-15T10:00:00Z"},
    {"id":"","name":"Mortgage","type":"Mortgage","isBudget":False,"sortOrder":4,"createdAt":"2025-01-15T10:00:00Z"},
]

categories = [
    {"id":"","name":"To Budget","emoji":"\U0001f4b0","isHeader":False,"isSystem":True,"sortOrder":0},
    {"id":"","name":"Bills","emoji":"\U0001f3e0","isHeader":True,"isSystem":False,"sortOrder":1},
    {"id":"","name":"Mortgage Payment","emoji":"\U0001f3e0","isHeader":False,"isSystem":False,"sortOrder":0,"parentName":"Bills"},
    {"id":"","name":"Council Tax","emoji":"\U0001f3db\ufe0f","isHeader":False,"isSystem":False,"sortOrder":1,"parentName":"Bills"},
    {"id":"","name":"Energy","emoji":"\u26a1","isHeader":False,"isSystem":False,"sortOrder":2,"parentName":"Bills"},
    {"id":"","name":"Water","emoji":"\U0001f4a7","isHeader":False,"isSystem":False,"sortOrder":3,"parentName":"Bills"},
    {"id":"","name":"Internet","emoji":"\U0001f4e1","isHeader":False,"isSystem":False,"sortOrder":4,"parentName":"Bills"},
    {"id":"","name":"Mobile Phones","emoji":"\U0001f4f1","isHeader":False,"isSystem":False,"sortOrder":5,"parentName":"Bills"},
    {"id":"","name":"Insurance","emoji":"\U0001f6e1\ufe0f","isHeader":False,"isSystem":False,"sortOrder":6,"parentName":"Bills"},
    {"id":"","name":"Living","emoji":"\U0001f6d2","isHeader":True,"isSystem":False,"sortOrder":2},
    {"id":"","name":"Groceries","emoji":"\U0001f6d2","isHeader":False,"isSystem":False,"sortOrder":0,"parentName":"Living"},
    {"id":"","name":"Eating Out","emoji":"\U0001f37d\ufe0f","isHeader":False,"isSystem":False,"sortOrder":1,"parentName":"Living"},
    {"id":"","name":"Transport","emoji":"\U0001f697","isHeader":False,"isSystem":False,"sortOrder":2,"parentName":"Living"},
    {"id":"","name":"Clothing","emoji":"\U0001f455","isHeader":False,"isSystem":False,"sortOrder":3,"parentName":"Living"},
    {"id":"","name":"Household","emoji":"\U0001f3e1","isHeader":False,"isSystem":False,"sortOrder":4,"parentName":"Living"},
    {"id":"","name":"Personal","emoji":"\U0001f9d1","isHeader":True,"isSystem":False,"sortOrder":3},
    {"id":"","name":"Entertainment","emoji":"\U0001f3ac","isHeader":False,"isSystem":False,"sortOrder":0,"parentName":"Personal"},
    {"id":"","name":"Subscriptions","emoji":"\U0001f4fa","isHeader":False,"isSystem":False,"sortOrder":1,"parentName":"Personal"},
    {"id":"","name":"Health","emoji":"\U0001f48a","isHeader":False,"isSystem":False,"sortOrder":2,"parentName":"Personal"},
    {"id":"","name":"Kids","emoji":"\U0001f476","isHeader":False,"isSystem":False,"sortOrder":3,"parentName":"Personal"},
    {"id":"","name":"Gifts","emoji":"\U0001f381","isHeader":False,"isSystem":False,"sortOrder":4,"parentName":"Personal"},
    {"id":"","name":"Savings Goals","emoji":"\U0001f3af","isHeader":True,"isSystem":False,"sortOrder":4},
    {"id":"","name":"Holiday Fund","emoji":"\u2708\ufe0f","isHeader":False,"isSystem":False,"sortOrder":0,"parentName":"Savings Goals"},
    {"id":"","name":"Emergency Fund","emoji":"\U0001f198","isHeader":False,"isSystem":False,"sortOrder":1,"parentName":"Savings Goals"},
]

SALARY = Decimal("3800.00")

# Total = 3750. Salary - budget = £50 surplus per month → small "To Budget" balance
base_budget = {
    "Mortgage Payment": Decimal("895.00"),
    "Council Tax":      Decimal("165.00"),
    "Energy":           Decimal("140.00"),
    "Water":            Decimal("42.00"),
    "Internet":         Decimal("32.00"),
    "Mobile Phones":    Decimal("45.00"),
    "Insurance":        Decimal("85.00"),
    "Groceries":        Decimal("686.00"),
    "Eating Out":       Decimal("150.00"),
    "Transport":        Decimal("250.00"),
    "Clothing":         Decimal("75.00"),
    "Household":        Decimal("55.00"),
    "Entertainment":    Decimal("75.00"),
    "Subscriptions":    Decimal("35.00"),
    "Health":           Decimal("40.00"),
    "Kids":             Decimal("175.00"),
    "Gifts":            Decimal("55.00"),
    "Holiday Fund":     Decimal("500.00"),
    "Emergency Fund":   Decimal("250.00"),
}
assert sum(base_budget.values()) == Decimal("3750.00")

seasonal = {
    11: {"Energy": Decimal("185.00")},
    12: {"Energy": Decimal("195.00"), "Gifts": Decimal("200.00")},
    1:  {"Energy": Decimal("190.00")},
    2:  {"Energy": Decimal("180.00")},
}

grocery_payees = ["Tesco","Sainsburys","Aldi","Lidl","M&S Food","Waitrose","Co-op"]
eating_payees = ["Nandos","Costa","Pizza Express","The Crown","Wagamama","Greggs","Pret"]
transport_payees = ["BP","Shell","Trainline","TfL","Uber"]
entertainment_payees = ["Vue Cinema","Cineworld","Amazon","Waterstones"]
clothing_payees = ["Next","Primark","John Lewis","H&M","Zara"]
household_payees = ["B&Q","Wilko","IKEA","Dunelm","Robert Dyas"]
kids_payees_regular = ["Nursery Fees"]
kids_payees_extra = ["Smyths Toys","Clarks","Book People","JoJo Maman"]
health_payees = ["Boots","Specsavers","Dentist"]
gifts_payees = ["Amazon","John Lewis","Moonpig","Not On The High Street"]
sub_items = [("Netflix",Decimal("10.99")),("Spotify",Decimal("10.99")),("Disney+",Decimal("7.99")),("iCloud",Decimal("2.99"))]

months_list = []
for yr in [2025,2026]:
    for mo in range(1,13):
        if yr==2025 and mo<2: continue
        if yr==2026 and mo>2: continue
        months_list.append((yr,mo))

budget_months, budget_allocations, transactions, payee_tracker = [], [], [], {}

def track(name, date, cat):
    if name not in payee_tracker: payee_tracker[name] = {"lastDate":date,"count":0,"category":cat}
    payee_tracker[name]["count"] += 1
    if date > payee_tracker[name]["lastDate"]:
        payee_tracker[name]["lastDate"] = date; payee_tracker[name]["category"] = cat

def exp(amt,payee,cat,parent,date,acct="Joint Current",memo=""):
    transactions.append({"id":"","amount":ds(amt),"payee":payee,"memo":memo,"date":iso(date),
        "type":"Expense","isCleared":True,"accountName":acct,"categoryName":cat,"categoryParent":parent})
    track(payee,date,cat)

def inc(amt,payee,date,acct="Joint Current"):
    transactions.append({"id":"","amount":ds(amt),"payee":payee,"memo":"","date":iso(date),
        "type":"Income","isCleared":True,"accountName":acct,"categoryName":"To Budget"})
    track(payee,date,"To Budget")

def xfr(amt,fr,to,date):
    transactions.append({"id":"","amount":ds(amt),"payee":"Transfer","memo":"","date":iso(date),
        "type":"Transfer","isCleared":True,"accountName":fr,"transferToAccountName":to})

for yr,mo in months_list:
    mi = f"{yr}-{mo:02d}-01T00:00:00Z"
    budget_months.append({"id":"","month":mi,"note":""})

    mb = dict(base_budget)
    if mo in seasonal: mb.update(seasonal[mo])

    for cn,a in mb.items():
        p = None
        for c in categories:
            if c["name"]==cn and "parentName" in c: p=c["parentName"]; break
        al = {"id":"","budgeted":ds(a),"categoryName":cn,"month":mi}
        if p: al["categoryParent"]=p
        budget_allocations.append(al)

    # Salary
    sm = mo-1 if mo>1 else 12; sy = yr if mo>1 else yr-1
    sal = SALARY
    if mo==6: sal = Decimal("4100.00")
    elif mo==12: sal = Decimal("4350.00")
    inc(sal, "Employer - Salary", datetime(sy,sm,28,8,0,0))

    cur = (yr==2026 and mo==2); md = 14 if cur else 28

    # Fixed bills
    exp(Decimal("895.00"), "Nationwide BS", "Mortgage Payment", "Bills", datetime(yr,mo,1,7,0))
    exp(Decimal("165.00"), "Bristol City Council", "Council Tax", "Bills", datetime(yr,mo,1,7,30))
    exp(vary(mb.get("Energy",Decimal("140.00")),0.05), "Octopus Energy", "Energy", "Bills", rand_day(yr,mo,3,min(7,md)))
    exp(Decimal("42.00"), "Bristol Water", "Water", "Bills", datetime(yr,mo,min(5,md),8,0))
    exp(Decimal("32.00"), "BT Broadband", "Internet", "Bills", datetime(yr,mo,min(4,md),9,0))
    exp(Decimal("45.00"), "Three Mobile", "Mobile Phones", "Bills", rand_day(yr,mo,8,min(12,md)))
    exp(Decimal("85.00"), "Aviva", "Insurance", "Bills", rand_day(yr,mo,10,min(15,md)))

    # Groceries — target close to budget with realistic variance
    gb = float(mb.get("Groceries",Decimal("686.00")))
    ng = random.randint(5,7) if not cur else 3
    gt = gb * random.uniform(0.88,1.12)  # sometimes over, sometimes under
    gp = gt / ng
    for i in range(ng):
        lo=max(1,1+i*(md//ng)); hi=max(lo,min(lo+(md//ng),md))
        exp(d(gp*random.uniform(0.7,1.3)), random.choice(grocery_payees), "Groceries", "Living",
            rand_day(yr,mo,lo,hi), acct="Credit Card")

    # Eating out — 3-5 visits
    ne = random.randint(3,5) if not cur else 2
    et = float(mb.get("Eating Out",Decimal("150.00"))) * random.uniform(0.75,1.25)
    ep = et/ne
    for _ in range(ne):
        exp(d(ep*random.uniform(0.5,1.5)), random.choice(eating_payees), "Eating Out", "Living",
            rand_day(yr,mo,1,md), acct="Credit Card")

    # Transport — 3-5 items (petrol + travel)
    nt = random.randint(3,5) if not cur else 2
    tt = float(mb.get("Transport",Decimal("250.00"))) * random.uniform(0.7,1.2)
    tp = tt/nt
    for _ in range(nt):
        p = random.choice(transport_payees)
        acct = "Credit Card" if random.random()>0.3 else "Joint Current"
        exp(d(tp*random.uniform(0.5,1.5)), p, "Transport", "Living", rand_day(yr,mo,1,md), acct=acct)

    # Subscriptions
    for sn,sa in sub_items:
        if cur and sn=="Disney+": continue
        exp(sa, sn, "Subscriptions", "Personal", rand_day(yr,mo,1,min(10,md)), acct="Credit Card")

    # Entertainment — most months
    if random.random()>0.15 and md>7:
        exp(d(random.uniform(20,80)), random.choice(entertainment_payees), "Entertainment", "Personal",
            rand_day(yr,mo,5,md), acct="Credit Card")

    # Clothing — about half the months, chunky when it happens
    if random.random()>0.4:
        exp(d(random.uniform(40,120)), random.choice(clothing_payees), "Clothing", "Living",
            rand_day(yr,mo,3,md), acct="Credit Card")

    # Household — about half the months
    if random.random()>0.45:
        exp(d(random.uniform(20,75)), random.choice(household_payees), "Household", "Living",
            rand_day(yr,mo,3,md), acct="Credit Card")

    # Kids — nursery most months + extras
    exp(d(random.uniform(70,95)), "Nursery Fees", "Kids", "Personal", rand_day(yr,mo,1,min(5,md)), acct="Joint Current")
    if random.random()>0.35:
        exp(d(random.uniform(15,65)), random.choice(kids_payees_extra), "Kids", "Personal",
            rand_day(yr,mo,5,md), acct="Credit Card")

    # Health — about 1/3 of months
    if random.random()>0.6:
        exp(d(random.uniform(12,55)), random.choice(health_payees), "Health", "Personal",
            rand_day(yr,mo,1,md), acct="Credit Card")

    # Gifts
    if mo==12:
        for _ in range(4):
            exp(d(random.uniform(25,70)), random.choice(gifts_payees), "Gifts", "Personal",
                rand_day(yr,mo,1,20), acct="Credit Card")
    elif random.random()>0.55:
        exp(d(random.uniform(15,55)), random.choice(gifts_payees), "Gifts", "Personal",
            rand_day(yr,mo,1,md), acct="Credit Card")

    # Transfers
    xfr(Decimal("200.00"), "Joint Current", "Savings", datetime(yr,mo,min(2,md),9,0))
    xfr(Decimal("100.00"), "Joint Current", "ISA", datetime(yr,mo,min(2,md),9,30))

    cc = sum(Decimal(t["amount"]) for t in transactions
             if t.get("accountName")=="Credit Card" and t["date"].startswith(f"{yr}-{mo:02d}") and t["type"]=="Expense")
    if cc>0: xfr(cc, "Joint Current", "Credit Card", datetime(yr,mo,min(20,md),10,0))

payees = []
for name, info in payee_tracker.items():
    p = {"id":"","name":name,"lastUsedDate":iso(info["lastDate"]),"useCount":info["count"]}
    if info["category"]: p["lastUsedCategoryName"]=info["category"]
    payees.append(p)

export = {"exportDate":"2026-02-15T12:00:00Z","appVersion":"1.0","accounts":accounts,
    "transactions":transactions,"categories":categories,"budgetMonths":budget_months,
    "budgetAllocations":budget_allocations,"payees":payees}

with open("screenshot-data.json","w") as f:
    json.dump(export, f, indent=2, ensure_ascii=False)

# Summary
cb = defaultdict(Decimal); cs = defaultdict(Decimal)
for ba in budget_allocations: cb[ba["categoryName"]] += Decimal(ba["budgeted"])
for t in transactions:
    if t["type"]=="Expense" and t.get("categoryName"): cs[t["categoryName"]] += Decimal(t["amount"])

print(f"Transactions: {len(transactions)}")
print(f"\n{'Category':<20} {'Mo Bud':>8} {'13mo Bud':>10} {'13mo Spent':>10} {'Available':>10}")
print("-"*62)
for cn in ["Mortgage Payment","Council Tax","Energy","Water","Internet","Mobile Phones",
           "Insurance","Groceries","Eating Out","Transport","Clothing","Household",
           "Entertainment","Subscriptions","Health","Kids","Gifts","Holiday Fund","Emergency Fund"]:
    b=cb.get(cn,Decimal("0")); s=cs.get(cn,Decimal("0")); mbudget=base_budget.get(cn,Decimal("0"))
    avail = b-s
    flag = " ◀ OVER" if avail < 0 else ""
    print(f"{cn:<20} {mbudget:>8} {b:>10} {s:>10} {avail:>10}{flag}")

ti = sum(Decimal(t["amount"]) for t in transactions if t["type"]=="Income")
tb = sum(Decimal(ba["budgeted"]) for ba in budget_allocations)
te = sum(Decimal(t["amount"]) for t in transactions if t["type"]=="Expense")
print(f"\nIncome: {ti}, Budgeted: {tb}, Expenses: {te}")
print(f"To Budget remaining: {ti-tb}")
print(f"Budget surplus (budgeted-expenses): {tb-te}")
