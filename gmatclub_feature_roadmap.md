# GMATClub Feature Inventory & PreUni Perú Roadmap

**Crawl date:** 2026-08-18  
**Pages visited:** 24 of 25 allowed  
**Session state:** Partially authenticated (cf_clearance injected; phpBB session HttpOnly-gated, so logged-out view for most question pages; logged-in view visible on analytics/quiz/rewards/profile via non-HttpOnly cookies)

---

## Section 1 — Feature Inventory

| # | Feature Name | Description | Gated | Data Dependency | Intended User Behavior |
|---|---|---|---|---|---|
| 1 | Subforum taxonomy | Hierarchical category tree: GMAT → Quantitative (PS, DS) / Verbal (CR, RC) / Data Insights (DS, G&T, MSR, TPA). Separate trees for MBA, GRE. | Free | Forum categories, post counts | Orient to the right question type; browse by section |
| 2 | Forum stats bar | Global counters: 33,798 topics, 242,355 posts. Displayed on forum index. | Free | Aggregate post counts | Social proof; signal platform credibility |
| 3 | Search bar | Full-text search across all forum topics. Present on every page. | Free | Indexed post content | Find a specific question or concept |
| 4 | Question listing with difficulty filters | Checkbox panel on forum subforum pages. 7 bands: Sub-505 (Easy), 505-555 (Easy), 555-605 (Medium), 605-655 (Medium), 655-705 (Hard), 705-805 (Hard), 805+ (Hard). | Free | Crowd-sourced difficulty ratings attached to each topic | Narrow to the difficulty band the student wants to drill |
| 5 | Question listing with topic filters | ~25 topic categories as checkboxes: Absolute Values, Algebra, Arithmetic, Combinations, Coordinate Geometry, Distance & Speed, Exponents, Fractions & Ratios, Functions, Graphs, Inequalities, Min-Max, Mixtures, Multiples & Factors, Must/Could be True, Number Properties, Overlapping Sets, Percents, Probability, Remainders, Roots, Sequences, Statistics & Sets, Word Problems, Work & Rate. | Free | Topic tags on each question | Drill one weak topic area |
| 6 | Pool selector ("All Unsolved Questions") | Filters question listing to only questions the logged-in user has not yet attempted. | Login | Per-user attempt history | Prevent repetition; always show fresh material |
| 7 | Topic/difficulty directory | Pinned thread in each subforum linking to questions organized by difficulty band × topic category. Two-level matrix. | Free | Tag index | Navigate directly to "Hard Probability questions" |
| 8 | Per-question difficulty badge | Tag on each question page: "605-655 (Medium)". Crowd-computed from attempt data. | Free | Aggregate attempt data | Set expectation for time investment; calibrate self-assessment |
| 9 | Per-question topic tags | Tags on question page: e.g., "Combinations \| Other". Linked; click navigates to filtered listing. | Free | Manual or crowd-assigned tags | Discover similar questions; understand concept tested |
| 10 | Answer distribution chart | After submitting an answer, shows what % of users chose A / B / C / D / E. Displayed as `statisticWrapExisting` bars. Hidden at 0% when not submitted (logged out). | Login (submission) | Per-question aggregate answer counts by choice | Calibrate confidence; understand where others go wrong |
| 11 | Official Answer (OA) gate | The correct answer is hidden behind a login wall. "unregistered" div shown to logged-out users with a registration upsell block (titled "GMAT Registration Benefits: Vast Question Bank…"). | Login | question.official_answer | Convert browsers to registered users |
| 12 | Per-question timer | Modal dialog: "GMAT Club Timer" pops up when a question is opened. Records time spent. Contact link: "Is there something wrong with our timer?" Points earned for using timer. | Login | User session timing data | Train pacing; feed points/rewards engine |
| 13 | Kudos (upvotes) on posts | Per-post button visible to all; clicking requires login. Shows count of kudos given and received. On profile: "7 Own / 161 Given." | Login (to give) | kudos junction table | Reward quality explanations; surface best solutions |
| 14 | Save / Bookmark | "Save" button on each question page. Saves to personal list. | Login | User bookmarks table | Build personal question list; revisit saved material |
| 15 | Reply / Discussion thread | Each question page has a threaded discussion. Reply button opens a post compose form. Post shows username, post count, kudos. | Login (to post) | Posts, user accounts | Ask for clarification; add an alternate solution; flag an error |
| 16 | Expert Reply badge | Users with Math Expert, Tutor, or "Expert reply" designation have a badge on their posts. Designated by admins or via paid expert partnerships. "Active GM" (Active GMATClub expert) sub-label. | Free (to view) | User role/group assignment | Trust a solution; prioritize reading a specific post |
| 17 | "Request Expert Reply" button | Button on question page that pings verified experts to respond. | Login | Expert user pool | Escalate an unresolved question to a trusted authority |
| 18 | Forum Quiz (custom quiz builder) | `/quiz/v5/build-quiz/`. Full-featured quiz builder: select exam type (GMAT/EA/GRE), section (Quant/Verbal/DI), topic (full 25-category taxonomy), difficulty (7 bands + Adaptive), source (All/Trending), pool (All Unsolved). Save/load templates. Sort by Recent. Generate custom quiz. | Login | All question metadata + user attempt history | Build a targeted drill session without manual browsing |
| 19 | Adaptive quiz mode | Within quiz builder, difficulty "Adaptive" option uses IRT to adjust question difficulty mid-quiz based on prior answers. | Login (possibly paid) | IRT model trained on attempt data | Simulate exam conditions; surface difficulty ceiling |
| 20 | Diagnostic Mini-Quiz | `/quiz/gmat-mini-quiz/`. Short diagnostic covering key topics. Returns personalized analytics. "Is the mini quiz really free? Yes." Retakable. | Free | Question pool sample | Quick entry point; generate analytics before committing |
| 21 | Question of the Day | Linked from nav: daily featured question. Recurring post thread updated daily by admins (Butler pattern). CR, DS, PS, RC each have their own Butler threads. | Free | Curated daily schedule | Drive daily return visits; prevent "what do I practice today?" paralysis |
| 22 | Analytics dashboard | `/forum/analytics.php#dashboard`. Tabs: Dashboard, Quant, Verbal, Data Insights. Per-section: Percentile (gated behind completing a GMAT Club Test), Questions Attempted, Time Practiced, Accuracy %, Streak (days). Auto-detected Strengths and Weaknesses by topic. Goal-setting: Target Score + Test Date. Source toggle: Tests / Quiz / Forum. Time period: All time or custom. | Login | All attempt, timing, and quiz records | Identify weakest topics; track trajectory over weeks |
| 23 | Error Log | `/forum/analytics.php#error_log`. Table with columns: Question, Result, Attempts, Category, Difficulty, Time, Date, Mistakes/Notes. Filterable by category and result. | Login | Per-question attempt records | Review wrong answers systematically; add personal notes |
| 24 | Study Plan (12-week) | `/study-plan/`. Free structured 12-week curriculum with daily topics. Week-by-week coverage: Arithmetic → CR → DI → Number Properties → Algebra → Statistics (Mock 1: Baseline) → Exponents → Inequalities → Work & Rates → RC → Sets & Sequences (Mock 2: Halfway) → Probability → RC details → MSR → review. "Continue where you left off" button. | Free (progress tracking: login) | Progress tracking table; question associations per week | Remove decision fatigue; provide a rails-on curriculum for self-studiers |
| 25 | User profile | `/forum/members/me.html`. Displays: kudos received/given, schools applied (name + year + outcome D/WL/A), GMAT/GRE scores (multiple attempts with section subscores), GPA, join date, last visited, total posts, most active forum/topic, groups (GMAT/GRE Verified, Quiz Members), rewards tier (BRONZE), points balance, badges. Public. | Free (to view) | User data, application tracker, score records | Signal credibility to other users; track own journey |
| 26 | Rewards / Points system | `/forum/rewards-dashboard.html`. Two point pools: Tier Qualifying Points (99, non-spendable) and Redeemable Points (49, spendable). Tiers: Bronze → next tier. Points earned by: using the question timer, posting, replying, chatting. Real-time live activity feed. Top-10 leaderboard (Bunuel #1 with 26,926 pts). User global rank visible (#579 for this session). Redeem tab for rewards. | Login | Points events table, leaderboard | Gamify participation; reward prolific contributors; drive daily engagement |
| 27 | Leaderboard (Top Members) | Visible within Rewards Dashboard. Top 10 by points. User's own rank shown below (#579). | Login | Cumulative points per user | Status competition; identify most helpful contributors |
| 28 | Live activity feed | Real-time stream on rewards page: "DashGrip — Timers 25s ago", "nsharp — Posts 10m ago", etc. Activity types: Timers, Posts, Replies, Chats, Reward redeemed. Refreshes continuously. | Login | Real-time event log | Social proof of active community; FOMO loop |
| 29 | Practice Tests (timed simulations) | `/gmat-focus-tests/`. Tiered: Free ($0, 1 adaptive test); Starter ($99.95/3mo, 20 Quant + 10 Verbal + 10 DI sectional tests); Pro ($139.95/3mo, adds 12 full adaptive tests + GMAT Focus-style score report + 1 QB reset); Elite ($189.95/3mo, adds unlimited resets + full↔sectional conversion + 6mo pause). 7-day money-back guarantee. IRT adaptive algorithm. | Free (1 test); paid for more | IRT model, question pool per difficulty band | Full exam simulation; score prediction; track improvement over multiple attempts |
| 30 | GMAT Focus-style score report | Generated after completing a Pro/Elite practice test. Mimics the real GMAT score report format. | Paid (Pro+) | Test session answer data + IRT scoring | Understand composite score + section breakdown; practice reading score reports |
| 31 | Score Calculator | `/forum/gmat-focus-score-calculator-418782.html`. Interactive calculator for estimating GMAT score from raw section performance. | Free | Scoring rubric logic | Set realistic target; understand scoring before first attempt |
| 32 | Real-time chat rooms | Visible in header and notification panel: "Yale Applicants chat", "NYU Stern Applicants chat", "General GMAT Chat", "Practice Questions Chat". Linked to context (school, section). | Login | Chat message store | Peer conversation in parallel with studying; community cohesion |
| 33 | Notification system | Bell/count in header: "6 Unread". Shows: followed-user activity, followed-forum new topics with preview. Snooze 15m, Mark All As Read options. | Login | Follows/subscriptions, post events | Keep users informed of replies and new relevant content |
| 34 | "Butler" daily question posts | Recurring pinned threads for each section (Problem Solving Butler, Critical Reasoning Butler, Data Sufficiency Butler, RC Butler). Posted by admins; 2 fresh questions per day. | Free | Manual curation by admins | Daily entry point for users who don't want to choose their own questions |
| 35 | Free Question Banks | Linked from navigation. Separate section with curated free question sets organized by source (OG, GMAT Focus, etc.). | Free/Login | Curated question collections | Practice from official sources without hunting |
| 36 | Ask GMAT Experts subforum | Subforum section where partner prep companies (e-GMAT, Magoosh, Manhattan Prep, Target Test Prep, GMATWhiz) staff expert responders. Treated like a premium customer support channel. | Free (to read); Login (to post) | Partner company accounts, moderation | Get authoritative answers; exposure for partner companies |
| 37 | Affiliate deals marketplace | "DEALS" top-nav section. Discounts for e-GMAT (save $525), Magoosh ($215), Manhattan Prep ($225), Target Test Prep ($599), GMATWhiz ($725), Experts' Global ($418). Student loan cashback ($500 Prodigy). | Free | Affiliate partnership codes | Revenue generation; user value through partner discounts |
| 38 | MBA Rankings | `/mba-rankings`, `/mim-rankings`. Full ranked lists of MBA and MiM programs. | Free | Rankings data, partner school profiles | MBA discovery; school shortlisting |
| 39 | Decision Tracker | `/forum/decision-tracker/`. Application outcome tracker, interview debrief archive, interview release schedule, profile evaluations. | Free / Login | User-submitted application outcomes | Competitive intelligence on admissions cycles |
| 40 | Flashcards | `/forum/gmat-flashcards-108651.html`. Downloadable GMAT vocabulary and math flashcard set. | Free | Static content | Supplemental reference material |
| 41 | Math Book (PDF) | `/forum/gmat-math-book-in-downloadable-pdf-format-130609.html`. Community-written comprehensive math reference in PDF. | Free | Static PDF | Reference for foundational concepts |
| 42 | Mobile apps | iOS (`apps.apple.com/us/app/gmat-club/id1265813439`) and Android (`play.google.com/store/apps/details?id=com.deepinspire.gmatclub`). Links in footer. No separate landing page found. | Free (download) | Full platform API | Study on mobile; notifications on device |
| 43 | GMAT/GRE score display on profile | Users self-report GMAT and GRE scores (with section breakdowns and attempt numbers). Visible on public profile. Groups include "GMAT/GRE Verified" for score-verified users. | Login (to add) | User-submitted score records | Establish credibility; allow peers to calibrate advice quality |
| 44 | School application outcome tracking | Profile section: applied schools + graduation year + result (D = Denied, WL = Waitlisted, A = Admitted). | Login | User-submitted application records | Transparency about real admissions results; community data |

---

## Section 2 — Feature Clusters

Nine functional clusters organize the 44 inventoried features by what they accomplish together rather than where they appear on GMATClub. Each row maps back to a Feature # in Section 1. The **PreUni Tier** column is the assignment discussed in Section 3; the **Note** column records any adaptation from the GMATClub implementation to the Peruvian context.

---

### Cluster A — Question Display
*The atomic unit. Every other cluster depends on a question being renderable on screen with correct math, tags, and difficulty signal.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 2 | Forum stats bar | MVP | Show question count and community post count as social proof at launch |
| 8 | Per-question difficulty badge | MVP | Suppress below 50 attempts; display "Sin datos suficientes" otherwise |
| 9 | Per-question topic tags | MVP | Taxonomy is Peruvian (Aritmética, Geometría, Álgebra…), not GMAT's 25-category list |
| 1 | Subforum taxonomy | MVP | Flatten to subject areas per university; no GMAT / MBA sub-trees |
| 7 | Topic/difficulty directory | MVP | Manually maintained HTML page; not a dynamic tree |

---

### Cluster B — Attempt Submission + Calibration
*The data collection loop. Every downstream analytic, filter, and difficulty calibration feature depends on attempt records generated here.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 11 | Official Answer (OA) gate | MVP | Primary conversion mechanic; login-only, never payment-gated |
| 10 | Answer distribution chart | MVP | Suppress below 20 submissions; revealed only after the user submits their own answer |
| 12 | Per-question timer | Phase 2 | Records `tiempo_empleado_segundos`; feeds penalización-aware analytics in Cluster E |
| 6 | Pool selector ("All Unsolved Questions") | Phase 2 | Requires an existing attempt history; not meaningful at zero attempts |

---

### Cluster C — Community Layer
*The core differentiation. Neither Simbox PREU nor bancodepreguntas.pe offers anything in this cluster.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 15 | Reply / Discussion thread | MVP | Four typed post types: solucion, pregunta, objecion, comentario |
| 13 | Kudos (upvotes) on posts | MVP | Kudos drive visibility and inform moderator pinning — not auto-sort |
| 16 | Expert Reply badge | MVP | Peruvian equivalent: cachimbo badge derived from `academic_status`, not a paid role |
| 14 | Save / Bookmark | Phase 2 | Requires stable login and a pool large enough for "review later" to be meaningful |
| 17 | "Request Expert Reply" button | Reject | Requires a paid expert pool; the cachimbo badge is the no-cost replacement |

---

### Cluster D — Discovery
*How the target user finds their next question without decision fatigue.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 35 | Free Question Banks | MVP | This is the product itself: the curated pool of tagged past-exam questions |
| 4 | Question listing with difficulty filters | MVP | 3 bands at launch (Fácil / Medio / Difícil) until calibration data matures |
| 5 | Question listing with topic filters | MVP | Peruvian subject taxonomy replaces GMATClub's GMAT-specific topic list |
| 3 | Search bar | MVP | PostgreSQL `to_tsvector('spanish', …)` — never `'simple'` or `'english'` |
| 21 | Question of the Day | Phase 2 | One manually curated question per day; admin-selected, never automated |
| 34 | "Butler" daily question posts | Phase 2 | Same mechanic as QotD; no need for per-section Butler threads at Phase 2 scale |

---

### Cluster E — Personal Progress
*Makes return visits purposeful. Converts one-time visitors into streak-driven daily users.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 23 | Error Log | Phase 2 | Add penalización-aware columns; the Mistakes/Notes field is the highest-value piece |
| 22 | Analytics dashboard | Phase 2 | Must show **puntaje efectivo con penalización**, not raw accuracy alone |
| 43 | GMAT/GRE score display on profile | Phase 2 | Peruvian equivalent: target university + especialidad displayed on public profile |
| 24 | Study Plan (12-week) | Phase 3 | Requires community data on per-university topic weightings before a correct curriculum can be built |

---

### Cluster F — Quiz Building
*Self-directed drill sessions that go beyond browsing a single question at a time.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 18 | Forum Quiz (custom quiz builder) | Phase 2 | Filters: university, especialidad, topic, difficulty, pool (All / Unsolved / Wrong Only) |
| 20 | Diagnostic Mini-Quiz | Phase 2 | Short entry diagnostic; produces analytics before the student commits to a drill plan |
| 19 | Adaptive quiz mode (IRT) | Phase 3 | Requires ≥500 calibrated attempts per question; not viable before Year 2 |

---

### Cluster G — Social / Gamification
*Needs a live user base to deliver value. Building this before Clusters A–D is guaranteed waste.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 25 | User profile | MVP | Minimal at launch: academic_status, university target, post count, kudos given/received |
| 33 | Notification system | Phase 2 | Email-only for direct replies at MVP; full follow/feed system is Phase 3 |
| 26 | Rewards / Points system | Phase 3 | Zero value until 500+ DAU; the leaderboard must mean something before points do |
| 28 | Live activity feed | Reject | A ghost town at low user counts; signals low adoption rather than vitality |
| 27 | Leaderboard (Top Members) | Phase 3 | bancodepreguntas.pe owns the ranking mechanic now; revisit with accuracy-based ranking once data volume justifies it |
| 32 | Real-time chat rooms | Reject | WebSocket infrastructure + moderation overhead with no return at early user counts |

---

### Cluster H — Monetization
*GMATClub's revenue engine. None of it maps directly to the Peruvian context at this stage.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 31 | Score Calculator | Phase 2 | Peruvian equivalent: penalización calculator (correctas − 0.25 × incorrectas) |
| 42 | Mobile apps (iOS + Android) | Phase 3 | A PWA covers mobile needs at zero marginal cost until web retention is proven |
| 29 | Practice Tests (timed simulations) | Reject | Simbox PREU's territory; competing here is a losing fight for a solo builder |
| 30 | GMAT Focus-style score report | Reject | Wrong format for UNMSM; replace with bruto / deducción / efectivo display |
| 37 | Affiliate deals marketplace | Reject | No Peruvian prep-company affiliate ecosystem exists at launch |

---

### Cluster I — Wrong Context
*Features that exist on GMATClub for MBA admissions, GRE, or US academic markets. No Peruvian entrance exam equivalent.*

| Feature # | Feature Name | PreUni Tier | Note |
|---|---|---|---|
| 36 | Ask GMAT Experts subforum | Reject | Paid partner marketing slot; no equivalent commercial prep companies in Peru |
| 38 | MBA Rankings | Reject | UNMSM / UNI are public universities; no MBA admissions context |
| 39 | Decision Tracker (application outcomes) | Reject | No interview process, no school selection cycle, no waitlists in this context |
| 44 | School application outcome tracking | Reject | MBA-specific; same reason as above |
| 40 | Flashcards (downloadable) | Reject | Better alternatives (Anki, free PDFs) already exist in the Peruvian market |
| 41 | Math Book (PDF resource) | Reject | Zero differentiation; Lumbreras and free community PDFs already cover this |

---

## Section 3 — Prioritized Roadmap

### Phase 0 — Pre-build (complete before writing any plugin code)

Everything here is infrastructure, configuration, or content. None of it is custom code. Phase 0 is done when Discourse is live, the prerequisite plugins are installed, and 50 tagged questions exist in the system.

---

**1. Provision server**
*Owner: developer | Effort: 1 day*

Discourse requires Docker on Linux. Minimum specs: 2 GB RAM, 2 CPU cores, 40 GB SSD. Recommended providers at early stage: Hetzner CX21 (~€5/mo) or DigitalOcean Basic Droplet ($24/mo). SSL is handled automatically by Discourse's Let's Encrypt integration — no separate setup needed.

---

**2. Register domain and configure DNS**
*Owner: Gerald | Effort: 1 hour*

Register `preuni.pe` (or equivalent). Point the A record to the server IP. Discourse's setup script handles SSL from there. No CDN needed at MVP scale.

---

**3. Install Discourse via Docker**
*Owner: developer | Effort: half day*

Run the official `./discourse-setup` script. Required configuration at install time: admin email, domain, SMTP credentials (for registration emails and reply notifications). Set the default site language to Spanish (`es`). Do not customize anything else at this stage — get a clean baseline install first.

---

**4. Configure SMTP**
*Owner: developer | Effort: 1 hour*

Transactional email is required for user registration (confirmation link) and reply notifications. Use a free tier from Mailgun (10,000 emails/mo free) or Brevo (300/day free). SMTP credentials go into Discourse's `app.yml` before the first rebuild.

---

**5. Install prerequisite plugins**
*Owner: developer | Effort: 1 day*

Three plugins must be installed before any question content is added:

| Plugin | Purpose | When needed |
|---|---|---|
| `discourse-math` | MathJax rendering — without this, LaTeX in questions displays as raw text | Before first question is posted |
| `discourse-question-answer` | Q&A mode on threads — accepted-answer hierarchy, vote-sorted solutions | Before first discussion thread |
| `discourse-automation` | Scheduled recurring posts — needed for Question of the Day in Phase 2; install now to avoid future downtime | Can wait, but install during Phase 0 to avoid a rebuild later |

Plugin installs require editing `app.yml` and rebuilding the container. Each rebuild takes ~10 minutes. Do all three in one rebuild.

---

**6. Configure Discourse structure**
*Owner: Gerald (decisions) + developer (execution) | Effort: 1 day*

- **Categories**: one per subject area scoped by university. Example: `UNMSM / Aritmética`, `UNMSM / Geometría`, `UNI / Álgebra`. Flat structure — no sub-subcategories.
- **Tags**: create the Peruvian topic taxonomy as Discourse tags (Aritmética, Álgebra, Geometría, Trigonometría, Razonamiento Matemático, Razonamiento Verbal, Literatura, Historia del Perú, etc.). Tags are shared across categories.
- **User groups**: create four groups — Aspirante (default), Cachimbo, Egresado, Moderador. Admin assigns Cachimbo and Egresado manually at launch.
- **Cachimbo badge**: create a custom badge with university + admission year. Admin-granted, visible on solution posts.
- **Custom user fields**: add two fields to registration: "Universidad objetivo" (dropdown: UNMSM / UNI / PUCP / Otra) and "Especialidad objetivo" (text or dropdown). These appear on the public profile.
- **Trust levels**: set minimum trust level to post = TL0 (everyone can post) but require email confirmation before posting.

---

**7. Finalize Plugin 1 data model with developer**
*Owner: Gerald + developer | Effort: half day*

Align on how the question widget links to Discourse. Confirm: each question is one Discourse topic; the `preguntas` table stores the canonical data (MCQ options, OA, difficulty metadata) keyed to the Discourse `topic_id`. The developer writes the plugin migration files at this stage — not after.

---

**8. Seed 50 questions**
*Owner: Gerald | Effort: 3–5 days*

Fifty well-tagged questions must exist in the system before Plugin 1 development can be tested end-to-end. Each question needs: body text (LaTeX-formatted), five MCQ options (A–E), official answer, topic tag, university tag, and difficulty (left blank until 50 attempts accumulate). These are also the launch content — the platform should not go live with fewer. Source: past UNMSM / UNI exams (public domain).

---

**Phase 0 exit criteria:**
- Discourse is live at the registered domain with SSL
- `discourse-math`, `discourse-question-answer` plugins active
- Categories, tags, user groups, cachimbo badge configured
- Plugin 1 data model agreed and migration files drafted
- 50 questions posted, tagged, and rendering LaTeX correctly

---

### MVP — Required for the platform to function and deliver the core differentiation

---

**1. Per-question discussion thread with typed posts**  
*Tier: MVP | Effort: 5 days | Schema delta: None — `community_posts.post_type` enum (solucion/pregunta/objecion/comentario) already in schema*

This is the entire differentiation. Neither Simbox nor bancodepreguntas.pe offers threaded community discussion attached to individual questions. GMATClub's per-question thread is the proof that this mechanic works: a single question page can accumulate 10–20 community solutions over years, each one slightly different, each one helping a different learner. For PreUni, the absence of official solucionarios for San Marcos means this thread is not supplementary — it *is* the answer key. The four post types (solucion, pregunta, objecion, comentario) must be implemented from day one because they create the taxonomy that drives the expert hierarchy in Phase 2. Without the thread, the platform is just another question database, indistinguishable from what already exists.

---

**2. Official Answer (OA) gated behind login**  
*Tier: MVP | Effort: 2 days | Schema delta: None — `questions.respuesta_oficial` already exists; add login check in view layer*

The single most important conversion mechanic on GMATClub, and the right one for PreUni. The student arrives via SEO or a classmate's link, reads the question, wants the answer, and sees a registration prompt. This is low-friction because the user already has motivation (they want the answer). GMATClub's "unregistered" upsell block language — "Practice thousands of…" — is exactly the framing PreUni needs: "Resuelve miles de preguntas con la comunidad." The gate must be login-only, not payment, because payment walls before registration destroy conversion. The payoff for registering is immediate (they get the answer), which is the cleanest possible value exchange.

---

**3. Difficulty display with crowd-sourced calibration**  
*Tier: MVP | Effort: 3 days | Schema delta: None — difficulty computed from attempts, suppressed below 50 per existing spec*

The existing schema already suppresses difficulty below 50 attempts, which is the right call. GMATClub shows difficulty as a band (605-655 Medium) rather than a raw number, which is pedagogically superior because it communicates a range rather than false precision. For PreUni, the display should show the band when data exists (≥50 attempts) and "Sin datos suficientes" when not. This feature also enables the filter in Feature #4, so it is a prerequisite. The secondary benefit is that students who contribute attempts are improving the calibration for everyone — making the data better feeds the filtering feature, which makes the platform more useful, which attracts more users.

---

**4. Topic and difficulty filters on question listing**  
*Tier: MVP | Effort: 4 days | Schema delta: See item below — requires `etiquetas` and `pregunta_etiquetas` tables if not already present*

A student 3-6 months from the exam is not browsing randomly — they have identified a weak area (e.g., Razón y proporción, Series numéricas) and need to drill it. Without filters, they must scroll or use search. GMATClub's checkbox filter panel is the right UI: multi-select for topics, multi-select for difficulty bands, with an "All Unsolved" pool filter. For PreUni, topic taxonomy must be Peruvian-specific (Aritmética, Álgebra, Geometría, Trigonometría, Razonamiento Matemático, Razonamiento Verbal, Literatura, Historia, etc.) rather than GMATClub's GMAT-specific taxonomy. This is day-one required — without it the question bank is unusable for targeted drilling.

---

**5. Cachimbo credibility badge**  
*Tier: MVP | Effort: 1 day | Schema delta: None — `users.academic_status` enum includes 'cachimbo'; add badge rendering in view layer*

This is the one feature that has no GMATClub equivalent and is purely Peruvian. A cachimbo (recently-admitted university student) is the most trusted source of advice for aspirantes, because they just passed the exact exam the student is preparing for, in the current format, with real stakes. GMATClub uses paid expert badges (Math Expert, Tutor) which require commercial relationships. PreUni can offer a better signal for free: `academic_status = 'cachimbo'` is already in the users schema. The badge should appear on solution posts from cachimbos, with the graduation year and university (e.g., "Cachimbo UNMSM '26 — Ingeniería"). This creates an incentive for cachimbos to contribute, creates social proof for aspirantes, and costs nothing to implement beyond a visual badge. It is also a clear differentiator that bancodepreguntas.pe cannot copy without building the same community.

---

**6. Answer distribution chart**  
*Tier: MVP | Effort: 3 days | Schema delta: Add `respuesta_seleccionada` column to the attempts table — see Section 6*

After a student submits an answer, they see what percentage of other users chose each option. GMATClub renders this as A/B/C/D/E horizontal bars (`statisticWrapExisting`). The mechanism requires: (a) the student selects a choice, (b) their selection is stored, (c) the aggregate distribution is shown. This feature drives two behaviors: first, it creates a psychological reward for submitting (you learn how others struggled), and second, it teaches "where do people go wrong" reasoning, which is how the best GMAT tutors teach. The distribution is hidden until submission, which means it incentivizes trying the question rather than immediately revealing the answer. On PreUni, the distribution should be suppressed below 20 submissions (lower than difficulty threshold) to avoid misleading statistics early.

---

**7. Kudos (upvotes) on solutions**  
*Tier: MVP | Effort: 2 days | Schema delta: Add `votos` table — see Section 6*

GMATClub's kudos system does one critical thing: it lets the community visibly signal which solutions are worth reading. A solution with 50 kudos is immediately distinguished from one with 2, without any editorial intervention. Without a counter, the discussion thread is chronological and the first reply — often the lowest-quality rough draft — carries the same visual weight as a carefully worked solution posted a year later. For PreUni, this is especially important because official solucionarios don't exist: the community solution IS the answer key, and the kudos count is the quality signal. Kudos should be displayed on solucion posts only (not pregunta, objecion, or comentario). Which solution gets pinned at the top of the thread is a moderator decision, not an automatic sort — the kudos count informs that judgment but does not drive it automatically.

---

**8. User registration and login**  
*Tier: MVP | Effort: 3 days | Schema delta: None — users table exists*

Implied by features 2 and 6, but stated explicitly: email/password registration is the minimum. Google OAuth should be added in Phase 2 for lower friction. The registration prompt is the "unregistered" block described in Feature 2. Do not require email verification before showing the OA — the gate must deliver its payoff immediately. Email verification can happen asynchronously (to prevent spam later).

---

### Phase 2 — Strengthens the differentiator once there is a user base

---

**9. Error Log with personal notes**  
*Tier: Phase 2 | Effort: 3 days | Schema delta: Add `registro_errores` table — see Section 6*

GMATClub's Error Log (Question | Result | Attempts | Category | Difficulty | Time | Date | Mistakes/Notes) is the tool that separates students who improve from students who plateau. The Mistakes/Notes column is the highest-value piece: a student can write "confundí combinaciones con permutaciones" and it becomes a searchable personal log of conceptual gaps. For PreUni, this becomes viable in Phase 2 because it requires the difficulty-filter and topic-tag infrastructure from MVP to be meaningful. The Time column also feeds the penalización-aware analytics: if a student averages 4 minutes on Aritmética questions but UNMSM allocates 3 minutes per question, the error log reveals that pacing is a problem, not just accuracy.

---

**10. Analytics dashboard (accuracy + weaknesses by topic)**  
*Tier: Phase 2 | Effort: 5 days | Schema delta: Computed view over existing attempts data; no new tables required beyond what Error Log adds*

GMATClub's analytics shows: Questions Attempted, Time Practiced, Accuracy %, Streak (days), Strengths/Weaknesses by topic. For PreUni, the dashboard must show one additional metric that GMATClub cannot: **puntaje efectivo con penalización**. If a student has answered 100 questions with 70% accuracy under UNMSM rules, their effective score is not 70 — it is `70 - (30 × 0.25) = 62.5`. Showing this number forces the student to confront whether their current "correct or blank" strategy is better than "guess on everything." The weaknesses-by-topic panel directly addresses the use case of the target user: they know they are weak in Geometría and need the platform to confirm and quantify it, then route them to filtered drill sets.

---

**11. Custom quiz builder (non-adaptive)**  
*Tier: Phase 2 | Effort: 4 days | Schema delta: Add `quiz_configuraciones` table for saved templates*

GMATClub's quiz builder (topic × difficulty × pool × source) is the self-directed version of the Error Log drill. For PreUni, the initial version should be non-adaptive — adaptive scoring requires scale (thousands of calibrated questions per topic) that will not exist at Phase 2 launch. The key filters are: university (UNMSM / UNI / PUCP), especialidad (Medicina / Ingeniería / Letras), topic, difficulty, and pool (All / Unsolved Only / Wrong Only). "Wrong Only" is the Pre-exam cram mode — students who have 2 weeks left want to re-drill every question they got wrong. Template save/load can wait for Phase 3.

---

**12. Per-question timer**  
*Tier: Phase 2 | Effort: 2 days | Schema delta: Add `tiempo_empleado_segundos` column to attempts table*

GMATClub's timer modal is the data-collection mechanism behind their analytics and rewards system. For PreUni, pacing is a more acute problem than on the GMAT because UNMSM's penalización rule creates a dual-optimization problem: score per question AND time per question both matter. The timer records how long each attempt took, which feeds the Error Log (Time column) and the analytics dashboard. It also feeds the rewards points system in Phase 3. The timer should default to on but be dismissible, because some students find timers anxiety-inducing before exam day.

---

**13. Question of the Day**  
*Tier: Phase 2 | Effort: 1 day | Schema delta: Add `pregunta_del_dia_fecha` column to questions, or add `preguntas_del_dia` table*

GMATClub's "Butler" threads (2 questions per day per section) are one of the highest-engagement retention mechanics on the platform because they give passive users a reason to open the site daily without requiring a decision. For PreUni, one question per day across all sections is sufficient at Phase 2 scale. The implementation is a single admin action per day (select a question, set `fecha_pregunta_del_dia`). Do not automate it — manual curation ensures quality control and prevents low-quality questions from appearing in a high-visibility slot. The question of the day should auto-link to its full thread on the platform.

---

**14. Bookmarks / Saved questions list**  
*Tier: Phase 2 | Effort: 1 day | Schema delta: Add `marcadores` table — see Section 6*

GMATClub's Save button accumulates a personal queue. For PreUni, this is the "review later" mechanism for students who encounter a question they want to revisit but don't have time now. It is simpler than the Error Log (no attempt required — just a flag) and lower-friction than the quiz builder. Phase 2 timing because it requires login infrastructure to be stable and the question pool to be large enough that students actually want to save some for later.

---

### Phase 3 — Requires scale, data volume, or partnership to justify

---

**15. Rewards / points system**  
*Tier: Phase 3 | Effort: 8 days | Schema delta: Add `puntos_usuario`, `insignias`, `insignias_usuario` tables*

GMATClub's rewards system (timer points, post points, reply points, chat points; BRONZE → next tier; leaderboard; redeemable rewards) is compelling at scale — Bunuel's 26,926 points represent years of contribution. For PreUni, this system has zero value until there are enough users that the leaderboard means something and enough volume that the reward redemptions can be funded. Building it at MVP costs engineering time that would be better spent on the differentiation features. Phase 3, after 500+ daily active users.

---

**16. Full leaderboard / ranking page**  
*Tier: Phase 3 | Effort: 2 days | Schema delta: Computed from points or accuracy; no new tables*

bancodepreguntas.pe already owns the ranking mechanic and has academia scholarship partnerships around it. Competing on leaderboard alone is not viable. PreUni's leaderboard should be accuracy-based (best performance on verified-hard questions, not just volume), which is a differentiated take — but this requires a substantial question pool with calibrated difficulty before the ranking is meaningful. Phase 3.

---

**17. Adaptive quiz algorithm (IRT)**  
*Tier: Phase 3 | Effort: 15 days | Schema delta: IRT parameters per question; requires minimum 500 attempts per question for calibration*

GMATClub's adaptive mode uses Item Response Theory, which requires calibrated discrimination and difficulty parameters for every question. This only becomes viable when each question in the pool has ≥500 attempts with answer distribution data. At PreUni MVP, the question pool will not have that calibration. Build the non-adaptive quiz builder in Phase 2 and collect the data needed to train IRT parameters. Phase 3, after 1 year of attempt data.

---

**18. Study Plan (structured curriculum)**  
*Tier: Phase 3 | Effort: 6 days | Schema delta: Add `progreso_plan_estudio` table*

GMATClub's 12-week plan is built for a student with 3 months and a roughly even subject balance. Peruvian entrance exams have a different profile: UNMSM tests 100 questions across Aritmética, Álgebra, Geometría, Trigonometría, and Razonamiento Verbal and Lógico, but the weighting varies by especialidad. A curriculum that works for Medicina (heavier biology, chemistry, anatomy) does not work for Ingeniería (heavier physics and mathematics). Building a correct structured plan requires understanding each target university's exact topic weighting — data that must be crowdsourced from community members over time. Phase 3 after the community has mapped question distributions per university.

---

**19. Mobile app (iOS + Android)**  
*Tier: Phase 3 | Effort: 30+ days | Schema delta: None — API layer only*

GMATClub's apps exist at `apps.apple.com/us/app/gmat-club/id1265813439` and `play.google.com/store/apps/details?id=com.deepinspire.gmatclub`. For a solo builder on nights and weekends with a $500 budget, a native mobile app is out of scope until the web product has proven retention. A PWA (Progressive Web App) can deliver most of the mobile experience at zero marginal cost. Phase 3.

---

---

## Section 4 — Rejected Features and Why

**1. Full timed simulacros / practice tests**  
Simbox PREU owns this category with 7,000+ questions across 11 universities and a mature simulation engine. Building a competing product requires: a large calibrated question pool, an adaptive scoring engine, proctoring-equivalent UX, and score reporting infrastructure. This is a 60+ day engineering project for a product that will still be inferior to an entrenched competitor. The PreUni differentiation is per-question drilling, not full-exam simulation. Attempting to compete on Simbox's terrain while simultaneously building the community features would result in shipping neither well. Reject entirely.

**2. MBA rankings, Decision Tracker, Interview Debriefs, School Application Tracker**  
GMATClub's entire MBA admissions vertical — rankings, deadlines, decision tracker, interview release dates, school forums, scholarship negotiation — serves students applying to US/EU business schools. UNMSM and UNI are public Peruvian universities with a single national entrance exam. There is no equivalent admissions cycle, no interview process, no scholarship negotiation, and no school selection decision. These features would confuse and alienate PreUni's target user. Reject entirely.

**3. Affiliate deals marketplace (GMAT course discounts, student loan cashback)**  
GMATClub generates significant revenue from affiliate deals with prep companies (e-GMAT, Magoosh, Manhattan Prep, etc.) and Prodigy Finance loan cashback. The Peruvian market has none of these partners. There is no established paid GMAT/UNMSM prep industry with affiliate programs. The student loan context (US graduate school financing) has no Peruvian equivalent for university entrance. This feature category requires a commercial ecosystem that does not exist. Reject.

**4. Ask GMAT Experts subforum (paid expert partnerships)**  
GMATClub's "Ask GMAT Experts" section is funded by prep companies paying for the privilege of staffing official expert responders. It is, in effect, paid marketing for companies like e-GMAT. The Peruvian market has no prep company willing to pay for this, and the cachimbo badge (Feature #5 in MVP) is a superior credibility signal for the PreUni context anyway. The expert subforum also fragments discussion — a question gets answered in two places (the question thread AND the expert subforum). Reject.

**5. Adaptive quiz algorithm (IRT) at MVP or Phase 2**  
GMATClub advertises "Real GMAT-level adaptivity" using Item Response Theory. IRT requires each question to have calibrated discrimination and difficulty parameters estimated from hundreds or thousands of calibrated responses. A new platform with 50 registered users does not have this data. Implementing IRT without calibration data produces worse question selection than a simple random sampler. The feature creates false confidence in the system's judgment while delivering no real benefit. Build it in Phase 3 after the data exists.

**6. Real-time chat rooms**  
GMATClub has multiple active chat rooms (Yale Applicants, NYU Stern, General GMAT Chat, Practice Questions Chat) with live messages every few seconds. This requires WebSocket infrastructure, a moderation layer, and enough simultaneous users to make the chat feel alive. At PreUni MVP with fewer than 100 daily active users, a chat room is a ghost town that makes the platform feel abandoned. The asynchronous discussion thread (Feature #1) is the right social mechanism for a growing community. Reject until Phase 3.

**7. Flashcards and downloadable PDF resources**  
GMATClub's flashcards and Math Book PDF are static resources from the early 2010s. They persist on the platform for SEO and because removing them would break links. They do not represent a competitive advantage — Anki decks, free PDFs, and YouTube explanations are better versions of the same content. For PreUni, the equivalent (resúmenes de razonamiento matemático, formularios de geometría) already exist as free PDFs on Peruvian educational sites. Building a competing static resource provides zero differentiation and costs content creation time. Reject.

**8. GRE support**  
GMATClub covers GMAT, GRE, and Executive Assessment. PreUni's context is the Peruvian national university entrance exam (Examen de Admisión UNMSM, Examen de Admisión UNI). These are completely different exams from GRE. Adding GRE support would dilute the brand, split the question pool, and confuse the target user who has never heard of GRE in their academic context. Reject.

**9. Score report in GMATClub style (GMAT Focus format)**  
GMATClub's Pro/Elite tiers produce score reports in the GMAT Focus format (composite score + section breakdown + percentiles). UNMSM's scoring is a raw score with penalización applied, not a scaled adaptive score. A score report mimicking GMAT Focus would be meaningless for a student preparing for UNMSM. PreUni should show raw score, penalización deduction, and effective score — a simpler format that matches what the real exam produces. The "score report" feature is appropriate, but the GMATClub format specifically is wrong. See Section 4.

**10. Notification system (follows, activity feed)**  
GMATClub's notification system (follow a user, follow a forum, receive updates on new topics) is appropriate for a platform where users make long-term investments in discussions over years. At PreUni MVP, the notification system adds engineering complexity without delivering user value — there is not yet enough content or enough recurring users for "follow a topic" to be meaningful. Email notifications for direct replies to your posts are sufficient at MVP and cost zero to implement. The full follow/feed system belongs in Phase 3.

---

## Section 5 — Features GMATClub Lacks That PreUni Needs

**1. Penalización score display**  
UNMSM deducts 0.25 points for each wrong answer (penalización = true, penalización_valor = 0.25). GMATClub has no equivalent — the GMAT penalizes wrong answers implicitly through adaptive difficulty adjustment, not through explicit score subtraction. PreUni needs to display, on every practice session result: *Respuestas correctas: 65 | Incorrectas: 20 | En blanco: 15 | Puntaje bruto: 65 | Deducción por penalización: −5.00 | Puntaje efectivo: 60.00*. This display must also appear on the analytics dashboard, in the error log, and in any quiz result summary. The penalización field is already in the schema (`exams.penalizacion`, `exams.penalizacion_valor`), but the display logic, the "should I guess or leave blank?" decision support, and the quiz-mode integration must all be built. This is a first-class UI concept that does not exist anywhere on GMATClub.

**2. Penalización-aware "should I skip?" guidance**  
Related to the above but distinct: a student who has 30 seconds left and faces an uncertain question needs to know whether guessing is +EV under UNMSM rules. With 5 answer choices and a 0.25 deduction, the breakeven probability is P(correct) > 1/(1+0.25×4) = 1/2 = 50%. PreUni should show this rule inline in quiz mode: *"Con 5 opciones y penalización de −0.25, conviene responder si tu probabilidad de acertar supera el 50%."* This is a genuine pedagogical gap that no Peruvian prep platform addresses explicitly.

**3. Multi-university targeting with exam-specific filters**  
A student can target UNMSM, UNI, PUCP, and UP simultaneously (`user_university_targets` junction table already in schema). GMATClub has no equivalent — there is only one GMAT. PreUni needs: (a) a question tag indicating which universities have historically tested that concept, (b) a filter on the question listing to show "only questions relevant to UNMSM" or "shared by UNMSM and UNI," and (c) an analytics dashboard that shows accuracy per target university's topic distribution. This is the most technically complex Peruvian-specific feature, requires community-contributed tagging, and belongs in Phase 2 once enough questions are tagged.

**4. Especialidad filtering**  
UNMSM's exam has a general section and an especialidad section that varies by faculty (Medicina tests biology and chemistry; Ingeniería tests physics and advanced math; Letras tests literature and history). GMATClub's taxonomy is flat — there is no concept of "this question is relevant to me only if I'm applying to Ingeniería." PreUni needs an `especialidad` dimension on questions (linked via a junction table) and a user profile field for the student's target especialidad, so that the default question listing automatically filters to relevant questions. This prevents an Ingeniería aspirante from wasting time on biology questions meant for Medicina applicants.

**5. Cachimbo credibility badge (see also Section 3 MVP)**  
Already described as an MVP feature, but restated here because it represents a structural gap in GMATClub's model. GMATClub's credibility hierarchy is: Admin > Math Expert (paid) > Tutor (paid) > Quiz Member > Registered User. The Peruvian equivalent should be: Admin > Egresado (graduated from target university) > Cachimbo (recently admitted) > Estudiante (current student) > Aspirante (applicant). The `academic_status` enum in the users table already encodes this hierarchy. Displaying it prominently on solution posts creates a trust gradient that GMATClub cannot replicate without a paid expert marketplace. This is a zero-cost-to-maintain competitive advantage that compounds as more cachimbos join the platform.

**6. Absence of official solucionarios — community as the answer key**  
On GMATClub, every GMAT question has an official answer in the GMAT Official Guide or GMAT Focus materials. The community discusses the "best approach" but the OA is always authoritative and final. UNMSM does not publish official answer keys for past exams. When there is a disputed question (which happens regularly — several questions per exam cycle have ambiguous or contested answers), there is no official resolution. PreUni's discussion thread structure (especially the `objecion` post type) is designed for exactly this: a student posts a solucion, another posts an objecion challenging it, the community votes via kudos, and the highest-kudos solution becomes the de facto answer. This framing — "we are building the solucionario the university refuses to publish" — is a founding narrative that GMATClub never needed because their source material is already authoritative. PreUni should lean into it explicitly in onboarding copy.

---

## Section 6 — Schema Impact

The following SQL statements assume PostgreSQL 15+ and snake_case naming, with Spanish field names for Peruvian-specific concepts. They represent additions to the existing 13-table schema described in the project brief.

### MVP additions

```sql
-- Record which answer choice a user selected (feeds answer distribution chart)
ALTER TABLE intentos
  ADD COLUMN IF NOT EXISTS respuesta_seleccionada CHAR(1)          -- 'a', 'b', 'c', 'd', 'e', or NULL if skipped
      CHECK (respuesta_seleccionada IN ('a','b','c','d','e')),
  ADD COLUMN IF NOT EXISTS fue_en_blanco BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS tiempo_empleado_segundos INTEGER;       -- populated by timer; NULL if timer was dismissed

-- Upvotes on community_posts (kudos)
CREATE TABLE IF NOT EXISTS votos (
    id              BIGSERIAL PRIMARY KEY,
    post_id         BIGINT      NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    usuario_id      BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (post_id, usuario_id)                                   -- one vote per user per post
);

-- Topic + difficulty tags (shared vocabulary)
CREATE TABLE IF NOT EXISTS etiquetas (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL UNIQUE,                   -- e.g., 'Aritmética', 'Geometría', 'Combinatoria'
    tipo            VARCHAR(20) NOT NULL                           -- 'tema' | 'dificultad' | 'universidad'
        CHECK (tipo IN ('tema', 'dificultad', 'universidad')),
    orden           SMALLINT    NOT NULL DEFAULT 0                 -- display order within type group
);

-- Many-to-many: questions × tags
CREATE TABLE IF NOT EXISTS pregunta_etiquetas (
    pregunta_id     BIGINT   NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
    etiqueta_id     INTEGER  NOT NULL REFERENCES etiquetas(id) ON DELETE CASCADE,
    PRIMARY KEY (pregunta_id, etiqueta_id)
);

-- Bookmarks / saved questions
CREATE TABLE IF NOT EXISTS marcadores (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pregunta_id     BIGINT      NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, pregunta_id)
);
```

### Phase 2 additions

```sql
-- Personal notes on wrong answers (Error Log's Mistakes/Notes column)
CREATE TABLE IF NOT EXISTS notas_error (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pregunta_id     BIGINT      NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
    nota            TEXT,                                          -- free-form user note, e.g., "confundí con permutación"
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, pregunta_id)
);

-- Saved quiz configurations (templates)
CREATE TABLE IF NOT EXISTS configuraciones_quiz (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nombre          VARCHAR(120) NOT NULL,
    filtros         JSONB       NOT NULL DEFAULT '{}',             -- e.g., {"temas": [1,4,7], "dificultad": ["medio","dificil"], "pool": "incorrectas"}
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Question of the Day scheduling
CREATE TABLE IF NOT EXISTS preguntas_del_dia (
    fecha           DATE        PRIMARY KEY,
    pregunta_id     BIGINT      NOT NULL REFERENCES preguntas(id),
    publicado_por   BIGINT      REFERENCES users(id)
);

-- Penalización-aware score display (computed columns on quiz session results)
-- Assumes a quiz_sesiones or similar table already exists in the 13-table schema;
-- if not, add:
CREATE TABLE IF NOT EXISTS sesiones_quiz (
    id                          BIGSERIAL PRIMARY KEY,
    usuario_id                  BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    examen_id                   BIGINT      REFERENCES exams(id),          -- NULL for free-form quiz
    iniciada_en                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finalizada_en               TIMESTAMPTZ,
    total_preguntas             SMALLINT    NOT NULL DEFAULT 0,
    correctas                   SMALLINT    NOT NULL DEFAULT 0,
    incorrectas                 SMALLINT    NOT NULL DEFAULT 0,
    en_blanco                   SMALLINT    NOT NULL DEFAULT 0,
    puntaje_bruto               NUMERIC(6,2) GENERATED ALWAYS AS (correctas) STORED,
    deduccion_penalizacion      NUMERIC(6,2) GENERATED ALWAYS AS
                                    (incorrectas * COALESCE(
                                        (SELECT e.penalizacion_valor FROM exams e WHERE e.id = examen_id),
                                        0
                                    )) STORED,
    puntaje_efectivo            NUMERIC(6,2) GENERATED ALWAYS AS
                                    (correctas - incorrectas * COALESCE(
                                        (SELECT e.penalizacion_valor FROM exams e WHERE e.id = examen_id),
                                        0
                                    )) STORED
);

-- Add especialidad dimension to questions (Peruvian-specific)
-- Assumes an 'especialidades' table or enum already exists; if not:
CREATE TABLE IF NOT EXISTS especialidades (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL UNIQUE,                   -- e.g., 'Medicina', 'Ingeniería', 'Letras', 'General'
    universidad_id  INTEGER     REFERENCES universities(id)
);

CREATE TABLE IF NOT EXISTS pregunta_especialidades (
    pregunta_id     BIGINT  NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
    especialidad_id INTEGER NOT NULL REFERENCES especialidades(id) ON DELETE CASCADE,
    PRIMARY KEY (pregunta_id, especialidad_id)
);

-- Add target especialidad to user profile
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS especialidad_objetivo_id INTEGER REFERENCES especialidades(id);
```

---

*End of roadmap. Total features inventoried: 44. Clusters: 9 (Section 2). MVP: 8 features. Phase 2: 6 features. Phase 3: 5 features. Rejected: 10 entries (Section 4). Peruvian-specific gaps: 6 (Section 5). Schema delta: Section 6. Discourse coverage: Section 7.*

---

## Section 7 — GMATClub Features vs. Discourse Coverage

Maps each of the 44 inventoried features against what Discourse provides out of the box, what an existing plugin covers, and what requires a custom plugin build.

**Coverage legend:**
- **Native** — Discourse provides this with zero custom code
- **Plugin** — an existing open-source Discourse plugin handles it (install only)
- **Custom** — requires a bespoke plugin written for PreUni
- **Future Review** — not in current scope; kept as a candidate for Peruvian adaptation in a later phase

| # | Feature Name | Coverage | Discourse Solution | PreUni Tier |
|---|---|---|---|---|
| 1 | Subforum taxonomy | Native | Discourse categories + subcategories | MVP |
| 2 | Forum stats bar | Native | Admin stats widget; 3-line theme component to surface it prominently | MVP |
| 3 | Search bar | Native | Discourse built-in full-text search, present on every page | MVP |
| 4 | Question listing with difficulty filters | Custom | Tags are native; the checkbox filter sidebar requires a custom topic-list filter plugin | MVP |
| 5 | Question listing with topic filters | Custom | Same as F4 — Peruvian topic taxonomy tags are native, but the filter panel UI is custom | MVP |
| 6 | Pool selector ("All Unsolved Questions") | Custom | Requires attempt data from the question plugin; no native equivalent | Phase 2 |
| 7 | Topic/difficulty directory | Native | Pinned topic with manually maintained links; no code needed | MVP |
| 8 | Per-question difficulty badge | Custom | Discourse has no crowd-computed difficulty; custom plugin reads aggregate attempt data | MVP |
| 9 | Per-question topic tags | Native | Discourse tags, displayed on each topic automatically | MVP |
| 10 | Answer distribution chart | Custom | No Discourse equivalent; custom plugin reads aggregate answer counts from intentos | MVP |
| 11 | Official Answer (OA) gate | Custom | Discourse has no per-field login gate on topics; OA reveal is a custom widget behavior | MVP |
| 12 | Per-question timer | Custom | No native timer; custom JS component tracks session time and writes to intentos | Phase 2 |
| 13 | Kudos (upvotes on posts) | Native | Discourse post likes (heart icon); count displayed per post, already matches PreUni kudos model | MVP |
| 14 | Save / Bookmark | Native | Discourse bookmarks (native, per-topic and per-post) | MVP |
| 15 | Reply / Discussion thread | Plugin | `discourse-question-answer` adds accepted-answer Q&A mode on top of native replies | MVP |
| 16 | Expert Reply badge | Plugin | Discourse trust levels + custom badge assignment; admin grants badge to cachimbo/egresado users | MVP |
| 17 | "Request Expert Reply" button | Custom | No native equivalent; custom button triggers a moderator notification | Phase 2 |
| 18 | Forum Quiz (custom quiz builder) | Custom | No Discourse equivalent; full custom plugin with filter UI and quiz session management | Phase 2 |
| 19 | Adaptive quiz mode (IRT) | Custom | No Discourse equivalent; requires IRT model, viable only at Phase 3 data volume | Phase 3 |
| 20 | Diagnostic Mini-Quiz | Custom | Simplified version of F18; same custom plugin, entry-point flow | Phase 2 |
| 21 | Question of the Day | Plugin | `discourse-automation` plugin schedules a recurring pinned topic post; admin curates content | Phase 2 |
| 22 | Analytics dashboard | Custom | No Discourse equivalent; custom plugin reads intentos/sesiones tables and renders per-topic breakdown with penalización | Phase 2 |
| 23 | Error Log | Custom | No Discourse equivalent; custom plugin reads attempt records and renders notas_error table | Phase 2 |
| 24 | Study Plan (12-week) | Custom | No Discourse equivalent; custom plugin with week/day progress tracking against per-university topic weightings | Phase 3 |
| 25 | User profile | Native | Discourse profiles are native; target university + especialidad added via Discourse custom user fields (built-in feature, no plugin) | MVP |
| 26 | Rewards / Points system | Plugin | `discourse-gamification` adds points; full tier + redeem system needs a light extension on top | Phase 3 |
| 27 | Leaderboard (Top Members) | Plugin | `discourse-gamification` includes a basic leaderboard; accuracy-based ranking needs a custom sort on top | Phase 3 |
| 28 | Live activity feed | Future Review | Viable once 500+ DAU; signals community vitality. Discourse Chat activity tab can serve this with zero custom code | Future |
| 29 | Practice Tests (timed simulations) | Future Review | Adapt as a timed full-exam UNMSM/UNI simulation — not a GMAT clone. Viable once question pool exceeds 500 questions | Future |
| 30 | GMAT Focus-style score report | Future Review | Adapt as a PreUni exam report: correctas / incorrectas / en blanco / puntaje efectivo — matches sesiones_quiz computed columns already in schema | Future |
| 31 | Score Calculator | Custom | Simple one-page tool; Discourse theme component with inline JS, no backend needed | Phase 3 |
| 32 | Real-time chat rooms | Future Review | Discourse Chat is built-in at no cost; enable once a study-group use case justifies the moderation overhead | Future |
| 33 | Notification system | Native | Discourse notifications (replies, mentions, bookmarks) — native and complete | Phase 2 |
| 34 | "Butler" daily question posts | Plugin | `discourse-automation` schedules recurring posts; admin still curates the question selection | MVP |
| 35 | Free Question Banks | Native | Discourse category + tag organization; curated collections are just tagged topics | MVP |
| 36 | Ask GMAT Experts subforum | Future Review | Adapt as "Pregunta a un Cachimbo" — recently admitted students answer aspirantes; zero cost, high trust signal, no paid marketplace needed | Future |
| 37 | Affiliate deals marketplace | Future Review | Peruvian adaptation: referral partnerships with Academias Preuniversitarias (Trilce, Bertello, César Vallejo); revenue share on enrollments | Future |
| 38 | MBA Rankings | Future Review | Adapt as UNMSM/UNI faculty-difficulty rankings or historical ingresante cutoff scores by especialidad and cycle | Future |
| 39 | Decision Tracker | Future Review | Adapt as admission outcome tracker: postulante submits exam score + result (Ingresó / No ingresó) by cycle and universidad; builds community data on cutoff scores | Future |
| 40 | Flashcards | Future Review | Adapt as Fórmulas Rápidas cards per topic (Aritmética, Geometría…); static content, zero build cost via a pinned Discourse topic per subject | Future |
| 41 | Math Book (PDF) | Native | Upload PDF to a pinned Discourse topic; no custom code needed | N/A |
| 42 | Mobile apps | Native | Discourse is mobile-responsive; official Discourse mobile app wraps the web app automatically | Future |
| 43 | GMAT/GRE score display on profile | Native | Discourse custom user fields (built-in); target university + especialidad are two custom fields, zero plugin code | Phase 2 |
| 44 | School application outcome tracking | Future Review | Merge with F39 into a single "Resultados de Postulantes" tracker — same data model, same Peruvian adaptation | Future |

### Summary by coverage type

| Coverage | Count | Features |
|---|---|---|
| **Native** | 12 | F1, F2, F3, F7, F9, F13, F14, F25, F33, F35, F41, F43 |
| **Plugin** (install only) | 5 | F15 (`discourse-question-answer`), F16 (custom badge), F21 (`discourse-automation`), F26, F27 (`discourse-gamification`) |
| **Custom** (build from scratch) | 15 | F4, F5, F6, F8, F10, F11, F12, F17, F18, F19, F20, F22, F23, F24, F31 |
| **Future Review** (Peruvian adaptation candidates) | 12 | F28, F29, F30, F32, F36, F37, F38, F39, F40, F42, F44 + F34 |

**Bottom line for the developer:** 12 features are free from Discourse. The 5 plugin installs take hours, not days. The real build effort is the 15 custom plugins — of which the **question widget** (F4, F5, F8, F10, F11) is one coherent plugin, not five separate builds. The 12 Future Review features are not blocked; they are deliberately deferred until user data or community size justifies the adaptation.
