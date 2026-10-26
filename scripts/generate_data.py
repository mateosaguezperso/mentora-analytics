"""
Synthetic data generator for the Mentora analytics project.

Mentora is a FICTIONAL B2B2C EdTech marketplace:
  - Companies pay a monthly subscription (employer branding) so that their
    employees can act as mentors on the platform.
  - Students sign up and book career-orientation conversations with mentors.

The generator is fully deterministic (fixed seed) and deliberately injects
the kind of data-quality issues you meet in real production sources, so the
staging layer has real work to do:
  - bookings are exported as a CDC-style log (one row per status change)
  - inconsistent casing / trailing spaces on status and email fields
  - a few exact duplicate rows in reviews
  - prices stored in cents, timestamps stored as strings

Usage:
    python scripts/generate_data.py            # writes CSVs into seeds/
"""

from __future__ import annotations

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

SEED = 42
START = datetime(2024, 1, 1)
END = datetime(2026, 9, 30, 23, 59, 59)  # last loaded timestamp (= var analysis_end_date - 1s)

N_COMPANIES = 80
N_STUDENTS = 6_000

OUT_DIR = Path(__file__).resolve().parents[1] / "seeds"
rng = random.Random(SEED)


# --------------------------------------------------------------------------- helpers
def ts(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S")


def rand_dt(start: datetime, end: datetime) -> datetime:
    if end <= start:
        return start
    return start + timedelta(seconds=rng.randint(0, int((end - start).total_seconds())))


def month_add(d: datetime, months: int) -> datetime:
    y, m = divmod(d.month - 1 + months, 12)
    return d.replace(year=d.year + y, month=m + 1, day=1)


def noisy_status(s: str) -> str:
    """~3% of statuses come with bad casing / trailing whitespace."""
    r = rng.random()
    if r < 0.015:
        return s.capitalize()
    if r < 0.03:
        return s + " "
    return s


def write(name: str, header: list[str], rows: list[list]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with open(OUT_DIR / f"{name}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {name:<22} {len(rows):>7,} rows")


# --------------------------------------------------------------------------- reference data
INDUSTRIES = ["Banking", "Consulting", "Tech", "Retail", "Energy", "Healthcare",
              "Media", "Industry", "Public sector", "Luxury"]
SIZES = ["50-249", "250-999", "1000-4999", "5000+"]
PLANS = {  # plan -> (mrr_cents, mentor seats range)
    "starter": (49_900, (3, 6)),
    "growth": (129_000, (6, 14)),
    "enterprise": (290_000, (14, 25)),
}
PLAN_ORDER = ["starter", "growth", "enterprise"]
JOB_FAMILIES = ["Data", "Engineering", "Finance", "Marketing", "Sales", "HR",
                "Product", "Legal", "Operations", "Design"]
CHANNELS = {  # channel -> (weight, propensity to book)
    "school_partnership": (0.30, 0.75),
    "organic": (0.25, 0.55),
    "seo": (0.20, 0.45),
    "paid_social": (0.15, 0.30),
    "referral": (0.10, 0.80),
}
LEVELS = ["high_school", "bac+1", "bac+2", "bac+3", "bac+4", "bac+5"]
CITIES = ["Paris", "Lyon", "Marseille", "Lille", "Bordeaux", "Nantes",
          "Toulouse", "Rennes", "Strasbourg", "Nice"]


def main() -> None:
    print(f"Generating Mentora synthetic data (seed={SEED}) -> {OUT_DIR}")

    # ------------------------------------------------------------- companies & subscriptions
    companies, subscriptions, mentors = [], [], []
    company_windows: dict[int, list[tuple[datetime, datetime | None, str]]] = {}
    sub_id = 1
    mentor_id = 1

    for cid in range(1, N_COMPANIES + 1):
        created = rand_dt(START, datetime(2026, 6, 30))
        companies.append([cid, f"Company {cid:03d}", rng.choice(INDUSTRIES),
                          rng.choice(SIZES), ts(created)])

        # subscription history: start at a plan, maybe upgrade / downgrade / churn
        plan_idx = rng.choices([0, 1, 2], weights=[0.55, 0.35, 0.10])[0]
        start = month_add(created, 1) if created.day > 1 else created.replace(day=1)
        start = start.replace(hour=0, minute=0, second=0)
        windows = []
        while start <= END:
            duration = rng.randint(4, 18)  # months
            end = month_add(start, duration)
            plan = PLAN_ORDER[plan_idx]
            if end > END:
                windows.append((start, None, plan))
                break
            windows.append((start, end, plan))
            r = rng.random()
            if r < 0.30:      # churn
                break
            elif r < 0.65:    # upgrade
                plan_idx = min(plan_idx + 1, 2)
            elif r < 0.75:    # downgrade
                plan_idx = max(plan_idx - 1, 0)
            # else: renew same plan
            start = end
        company_windows[cid] = windows
        for (s, e, plan) in windows:
            subscriptions.append([
                f"sub_{sub_id:05d}", cid, plan, PLANS[plan][0], ts(s),
                ts(e) if e else "", "active" if e is None else "cancelled",
            ])
            sub_id += 1

        # mentors: seats = max seats over the company's lifetime
        max_plan = max(windows, key=lambda w: PLAN_ORDER.index(w[2]))[2] if windows else "starter"
        lo, hi = PLANS[max_plan][1]
        first_start = windows[0][0] if windows else created
        last_end = windows[-1][1] if windows else created
        for _ in range(rng.randint(lo, hi)):
            joined = rand_dt(first_start, min(first_start + timedelta(days=200), END))
            is_active = last_end is None and rng.random() > 0.08
            mentors.append([
                mentor_id, cid, f"{rng.choice(JOB_FAMILIES)} {rng.choice(['Analyst', 'Manager', 'Lead', 'Specialist', 'Director'])}",
                ts(joined), "true" if is_active else "false",
                round(rng.uniform(0.55, 0.97), 3),  # hidden: acceptance propensity
                round(rng.lognormvariate(2.6, 0.9), 2),  # hidden: median response hours
            ])
            mentor_id += 1

    def company_active(cid: int, at: datetime) -> bool:
        return any(s <= at and (e is None or at < e) for (s, e, _) in company_windows[cid])

    # ------------------------------------------------------------- students
    students = []
    span = (END - START).total_seconds()
    for sid in range(1, N_STUDENTS + 1):
        # growth curve: more signups over time (sqrt distribution)
        signup = START + timedelta(seconds=span * (rng.random() ** 0.6))
        channel = rng.choices(list(CHANNELS), weights=[c[0] for c in CHANNELS.values()])[0]
        email = f"student{sid}@mail.example"
        r = rng.random()
        if r < 0.02:
            email = email.upper()
        elif r < 0.04:
            email = f"  {email} "
        students.append([sid, email, rng.choice(LEVELS), channel,
                         rng.choice(CITIES), ts(signup)])

    # ------------------------------------------------------------- bookings (CDC log) & reviews
    mentor_joined = {m[0]: datetime.strptime(m[3], "%Y-%m-%d %H:%M:%S") for m in mentors}
    booking_rows, reviews = [], []
    bid = 1
    rid = 1
    for (sid, _email, _lvl, channel, _city, signup_s) in students:
        signup = datetime.strptime(signup_s, "%Y-%m-%d %H:%M:%S")
        if rng.random() > CHANNELS[channel][1]:
            continue  # never books
        n = 1 + int(rng.expovariate(0.7))
        cursor = signup + timedelta(hours=rng.expovariate(1 / 240))  # ~10 days to first booking
        for _ in range(n):
            if cursor > END:
                break
            pool = [m for m in mentors
                    if mentor_joined[m[0]] <= cursor and company_active(m[1], cursor)]
            if not pool:
                cursor += timedelta(days=rng.randint(10, 60))
                continue
            m = rng.choice(pool)
            m_id, accept_p, resp_med = m[0], m[5], m[6]
            created = cursor
            scheduled = created + timedelta(days=rng.randint(3, 21), hours=rng.randint(8, 19) - created.hour)
            if scheduled <= created:
                scheduled = created + timedelta(days=3)
            events = [("requested", created)]

            response_at = created + timedelta(hours=rng.lognormvariate(0, 0.8) * resp_med)
            # a request expires after 7 days, or when its slot passes, whichever comes first
            expiry_at = min(created + timedelta(days=7), scheduled)
            if response_at >= expiry_at:
                events.append(("expired", expiry_at))
            elif rng.random() < accept_p:
                events.append(("accepted", response_at))
                if rng.random() < 0.12:
                    cancel_at = rand_dt(response_at, scheduled)
                    events.append(("cancelled", cancel_at))
                else:
                    events.append(("completed", scheduled + timedelta(minutes=45)))
            else:
                events.append(("declined", response_at))

            # keep only events that happened before the extraction date
            events = [(s, t) for (s, t) in events if t <= END]
            for status, t in events:
                booking_rows.append([f"bk_{bid:06d}", sid, m_id, ts(created), ts(scheduled),
                                     noisy_status(status), ts(t)])
            final_status, final_t = events[-1]
            if final_status == "completed" and rng.random() < 0.6:
                review_at = final_t + timedelta(hours=rng.randint(1, 96))
                if review_at <= END:
                    rating = rng.choices([1, 2, 3, 4, 5], weights=[2, 3, 10, 35, 50])[0]
                    row = [f"rv_{rid:06d}", f"bk_{bid:06d}", rating, ts(review_at)]
                    reviews.append(row)
                    if rng.random() < 0.01:  # exact duplicate from a double-fired webhook
                        reviews.append(list(row))
                    rid += 1
            bid += 1
            cursor = created + timedelta(days=rng.expovariate(1 / 45) + 1)

    # shuffle the CDC log: sources rarely arrive ordered
    rng.shuffle(booking_rows)

    # ------------------------------------------------------------- write
    write("raw_companies", ["id", "name", "industry", "employee_range", "created_at"], companies)
    write("raw_subscriptions", ["id", "company_id", "plan", "mrr_cents", "started_at", "ended_at", "status"], subscriptions)
    write("raw_mentors", ["id", "company_id", "job_title", "joined_at", "is_active"], [m[:5] for m in mentors])
    write("raw_students", ["id", "email", "education_level", "acquisition_channel", "city", "signed_up_at"], students)
    write("raw_bookings", ["booking_id", "student_id", "mentor_id", "created_at", "scheduled_at", "status", "updated_at"], booking_rows)
    write("raw_reviews", ["id", "booking_id", "rating", "created_at"], reviews)


if __name__ == "__main__":
    main()
