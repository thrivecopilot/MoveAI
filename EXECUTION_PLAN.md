# MoveAI Execution Plan

## Purpose & Context

MoveAI's mission is to democratize elite-level coaching through computer vision and real-time feedback. 

This execution plan bridges strategy and delivery — outlining what success looks like, how we'll measure it, and what we'll build to get there.

## Strategy → Success Flow

| Layer | Question | Output |
| :---- | :---- | :---- |
| **Vision** | Why does MoveAI exist? | Help everyday lifters master form safely and effectively. |
| **Goal (North Star)** | What defines long-term success? | % of users showing ≥ 30 % Form Improvement Index (FII) in 4 weeks. |
| **Success Definition** | What short-term wins prove we're on track? | Consistent form improvement, fewer red flags, repeat usage. |
| **Execution** | How will we achieve those wins? | Deliver MVP → Safety layer → Coaching intelligence. |

### AI Context Usage Note

For AI or automation tools:  
Use Section 2 ("Strategy → Success Flow") as a grounding summary of MoveAI's mission, North Star goal, and success definition.  

 • Treat "Vision" as the immutable purpose of the product.  

 • Treat "Goal (North Star)" as the primary outcome metric (FII).  

 • Treat "Success Definition" as the near-term measurable user outcomes that guide OKRs.  

 • Treat "Execution" as the current roadmap theme context.  

When generating or evaluating code, copy, analytics, or OKRs, always align recommendations back to the most relevant element of this flow.

## Defining Success — Key Metrics (HEART Mapping)

| HEART Category | Metric | Formula / Definition | Target | Tool / Source |
| :---- | :---- | :---- | :---- | :---- |
| **H – Happiness** | Self-Rated Improvement (SRI) | Avg. weekly self-rating (1–5) | ≥ 4.2 | In-app micro survey |
| **E – Engagement** | Session Logging Frequency | Avg. \# of form analysis sessions per user per week | ≥ 3 sessions / week | Event tracking (Firebase / Mixpanel) |
| **A – Adoption** | First Form Analysis Completion Rate | % of new users who record and receive feedback within 24 h of onboarding | ≥ 80 % | Onboarding funnel |
| **R – Retention** | 30-Day Active Rate | % of users performing ≥ 3 sessions in week 4 | ≥ 60 % | Cohort analysis |
| **T – Task Success** | Form Improvement Index (FII) | ((Baseline − Current) / Baseline) × 100 | ≥ 30 % in 4 weeks | Pose model logs |
| **T – Task Success** | Red Flag Rate (RFR) | \# risky sessions / total sessions | ≤ 10 % | Flag events |
| **T – Task Success** | Movement Consistency Score (MCS) | 1 − (normalized variance of bar path / ideal path) | ≥ 0.85 | Pose delta data |
| **T – Task Success** | Correction Uptake Rate (CUR) | Corrected faults / previously flagged faults | ≥ 60 % by next session | Feedback history |

## Measurement Plan

How to Instrument Early

* Aggregate joint-angle deviations across reps → compute FII.  
* Log "red-flag" events (e.g., `back_rounding = true`) per video.  
* Tag each session (`date`, `exercise`, `feedback_summary`).  
* Add feedback completion events (`feedback_viewed ≥ 80 %`).  
* Capture self-ratings via in-app slider

**Data Sources**

| Type | Description | Tool |
| :---- | :---- | :---- |
| Pose data | Joint angles, bar path, velocity | CoreML / Apple Vision |
| Event data | Session, flag, feedback interactions | Firebase / Mixpanel |
| User feedback | Surveys, ratings | In-app form |

## 2026 OKRs & Roadmap

### Q1 2026: Core Feedback Loop MVP

**Objective:**  
 Prove that AI-powered feedback drives measurable improvement in user form and satisfaction.

| Key Result | Metric Link | Target | Initiative(s) |
| ----- | ----- | ----- | ----- |
| ≥ 30 % average improvement in form accuracy within 4 weeks | FII | ≥ 30 % | Pose Engine v1 · Overlay UI |
| ≥ 4.2 avg. Self-Rated Improvement Score | SRI | ≥ 4.2 | Feedback visualization · post-session survey |
| ≥ 75 % feedback completion rate | Feedback Completion | ≥ 75 % | Feedback viewer · micro-survey |
| Launch closed beta with ≥ 50 active weekly users | Adoption | 50 users | Beta release · invite flow |

### Q2 2026: Safety & Consistency Layer

**Objective:**  
 Reduce risky movement patterns and improve rep-to-rep consistency.

| Key Result | Metric Link | Target | Initiative(s) |
| ----- | ----- | ----- | ----- |
| ≤ 10 % Red Flag Rate across top 3 exercises | RFR | ≤ 10 % | Red-Flag Module |
| Movement Consistency Score ≥ 0.85 | MCS | ≥ 0.85 | Consistency Tracker |
| Correction Uptake Rate ≥ 60 % | CUR | ≥ 60 % | Iterative feedback flow |
| Launch public release (v2) with ≥ 500 active users | Adoption | 500 users | Release campaign · improved onboarding |

### Q3 2026: Coaching Intelligence & Retention

**Objective:**  
 Turn real-time insights into long-term training habits and loyalty.

| Key Result | Metric Link | Target | Initiative(s) |
| ----- | ----- | ----- | ----- |
| ≥ 60 % 30-day retention rate among active users | Retention | ≥ 60 % | Progress Dashboard · Streaks |
| ≥ 70 % Correction Uptake Rate on recurring exercises | CUR | ≥ 70 % | Personalized cue generation |
| ≥ 3 avg. form sessions per week per retained user | Session Logging | ≥ 3 | Habit notifications · streak loops |
| ≥ 10 % conversion rate to Pro subscription | Monetization | ≥ 10 % | Free→Pro funnel · premium analytics |

## Stretch Objective (cross quarter)

**Objective:** Establish MoveAI as a credible digital coach platform.

| Key Result | Metric Link | Target | Initiative(s) |
| ----- | ----- | ----- | ----- |
| ≥ 1000 total paying Pro subscribers by year-end | Monetization | ≥ 1000 | Marketing partnerships · Pro launch |
| ≥ 85 % positive sentiment in app reviews | Happiness | ≥ 85 % | NPS survey · support response |
| Secure ≥ 1 pilot with gym or sports academy | Partnerships | 1 pilot | B2B outreach · demo program |

## Risks & Mitigations

| Risk | Mitigation |
| ----- | ----- |
| Poor model accuracy | Continuous tuning; sample diversity |
| Dim-light environments | User lighting prompt before record |
| Latency during analysis | Async feedback mode |
| Privacy concerns | On-device processing for Pro tier |

## Human \+ AI Collaboration Plan

| Area | Human Role (You) | AI Role (Cursor / ChatGPT) |
| :---- | :---- | :---- |
| Product Strategy | Define direction, OKRs | Summarize, structure, draft docs |
| Development | Build core models, verify UX | Generate SwiftUI / ML boilerplate |
| Analytics | Specify metrics, review dashboards | Generate schema / SQL / events |
| Content | Write copy, manage brand | Draft social / App Store text |

## Primary User Personas

| Persona | Description | Key Pain Points | Goals |
| ----- | ----- | ----- | ----- |
| Intermediate lifter | Trains 4–5×/week | Unsure if depth, posture, or alignment is correct | Improve technique, avoid injury |
| Combat athlete | Uses compound lifts for power | Lacks coach feedback | Optimize mechanics for speed & safety |

## Core Jobs-to-Be-Done

* "Record my lift and tell me what to fix immediately."  
* "Track form improvement over time."  
* "Compare myself to pro-standard technique."

## Key Features (MVP)

| Feature | User Benefit | Priority | Notes |
| ----- | ----- | ----- | ----- |
| AI Form Analysis | Detects joints, angles, deviations | ⭐⭐⭐⭐⭐ | Based on Apple Vision / pose-estimation |
| Overlay Visualization | Instant visual feedback | ⭐⭐⭐⭐ | Highlights joints / errors |
| Progress Tracker | Tracks improvements per exercise | ⭐⭐⭐ | Uses local HealthKit metrics |

## Growth Model

## **Acquisition:** TikTok/IG reels showing split-screen AI feedback. **Monetization:** Free tier (3 analyses/day), Pro ($14.99/mo unlimited). **Retention Loop:** Streak tracking \+ weekly "Form Report Card."

## Launch Messaging

*"Film your lift. Get pro feedback instantly. Train smarter — not harder."*

## Appendix

### Metrics → OKR Traceability Matrix

| Metric | HEART Category | Primary Objective / Quarter | Key Result(s) | Initiative(s) | Data Source / Owner |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Form Improvement Index (FII)** | Task Success | Q1 Core Feedback Loop MVP / Q3 Coaching Intelligence | ≥ 30 % form accuracy gain in 4 weeks | Pose Engine v1 · Overlay UI · Progress Dashboard | Pose model logs / Founder (PM \+ AI) |
| **Self-Rated Improvement (SRI)** | Happiness | Q1 Core Feedback Loop MVP | ≥ 4.2 avg SRI | Feedback visualization · Micro-survey | In-app survey / Founder |
| **Feedback Completion Rate** | Engagement \+ Task Success | Q1 Core Feedback Loop MVP | ≥ 75 % completion | Feedback viewer · UX improvement | Firebase / Cursor (Analytics Scripts) |
| **Red Flag Rate (RFR)** | Task Success | Q2 Safety & Consistency | ≤ 10 % risk patterns | Red-Flag Module | Flag events / Pose data pipeline |
| **Movement Consistency Score (MCS)** | Task Success | Q2 Safety & Consistency | ≥ 0.85 score | Consistency Tracker | Pose delta data / Founder |
| **Correction Uptake Rate (CUR)** | Task Success | Q2 & Q3 Coaching Intelligence | ≥ 60 % → 70 % follow-up correction | Iterative feedback flow · Personalized cues | Feedback history / Cursor codegen |
| **Session Logging Frequency** | Engagement | Q3 Coaching Intelligence | ≥ 3 sessions / week | Habit notifications · Streak loops | Firebase / Mixpanel |
| **30-Day Active Rate** | Retention | Q3 Coaching Intelligence | ≥ 60 % active users | Progress Dashboard · Gamified loops | Cohort analysis / Analytics script |
| **Monetization Rate** | Retention \+ Business | Q3 Stretch Objective | ≥ 10 % Pro conversion / ≥ 1000 Pro subs | Free→Pro funnel · Premium analytics · Partnerships | Stripe / Firebase |
| **App Review Sentiment / NPS** | Happiness | Stretch Objective | ≥ 85 % positive sentiment | Support loop · In-app survey | App Store reviews / Founder |


