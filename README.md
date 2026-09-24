# Nihongo Trainer (Flutter / Android) — v1.5

A complete Flutter rewrite of the NihongoTrainer desktop app — 320
sentences, 536 kanji, 533 vocabulary words, 280 radicals, and now 269
hiragana/katakana characters too, as a touch-first mobile app with swipe
gestures and a customizable background (your own photo, like a chat
wallpaper).

**👉 Start here: [`SETUP_INSTRUCTIONS.md`](./SETUP_INSTRUCTIONS.md)** — it
covers two ways to get from this code to an installed app:

- **Option A (recommended):** upload this folder to a free GitHub repo
  and a included automation (GitHub Actions) builds the APK for you in
  the cloud — no installs on your computer at all.
- **Option B:** build it locally with the Flutter SDK, useful if you want
  to tinker with live-reload.

## Quick summary

- All app code and data are already here and finished.
- Either build path takes about 10–30 minutes, mostly waiting, not typing.
- You end up with a real `app-release.apk` you install like any other app,
  and can rebuild any time.

## What's new in 1.5: Hiragana & Katakana + two home-screen dashboards

- **Hiragana / Katakana** — a full modern-kana section: 269 characters
  covering the basic 46 (×2), dakuten, handakuten, yōon, small/special
  kana, and the common extended katakana combinations used for loanwords
  (obsolete/historical kana intentionally excluded). Browse by group,
  tap a character for its romaji/notes/paired-kana, or jump into the
  **Kana Quiz** (Kana→Romaji and Romaji→Kana, filterable by type).
- Kana is **integrated into the existing SRS/Daily Review system**
  (`kana:<character>` ids, same due-date scheduling as kanji/vocab) —
  it's one shuffled review queue, with every card labelled by section
  (Kanji / Vocabulary / Hiragana / Katakana) so it's always clear what
  you're reviewing.
- **Two new compact cards** at the top of the Home screen:
  - **Daily Progress** — current streak and today's goal, tap through to
    a full **Progress Dashboard** (streak, weekly overview, per-category
    learning progress, lifetime accuracy, weak areas, recent activity).
  - **Daily Review** — reviews due today and an estimated time, tap
    through to the existing Daily Review flow (unchanged engine).
  - The daily goal is configurable in Settings → Study.
- **Take a Test** no longer reveals correct/wrong per question — picking
  an answer only registers the choice; the full review (your answer vs.
  the correct one, per question) is shown once the test is complete on
  the results screen.
- Sentences and Radicals are still not part of Daily Review's spaced
  repetition (unchanged from 1.3) — the Progress Dashboard says so rather
  than showing a misleading progress bar for them.

## What's new in 1.3: Radical Trainer

Two new home-screen entries, built from a 280-radical database (the
traditional 214 Kangxi radicals plus 72 additional common/variant
components):

- **Radicals** — browse all 280, or search by name or meaning as you
  type. Tap one for its full meaning, its name/reading(s), how it's
  typically used (e.g. "usually a left-side component"), and every
  example kanji it appears in.
- **Radical Quiz** — the same browse-and-answer format as Learn Kanji:
  see a radical, pick its meaning from 4 options, difficulty filter chips,
  swipe to skip.
- **Test and Mixed** now include a Radicals option, and Mixed draws from
  all four content types together.
- Same click sounds, wrong-answer sound + vibration, and menu-music
  stop/resume behavior as every other lesson screen — nothing new to
  learn about how it behaves.
- Radicals aren't part of Daily Review's spaced repetition (yet) — this
  update is scoped to browsing + quizzing, as asked.

## What's in 1.2: sound, vibration, and a Sound settings section

- **Menu music** loops on the home screen, Settings, and the Take-a-Test
  setup screen, stops the instant you enter a lesson/test/review/
  flashcard screen, and restarts from the beginning when you come back or
  reopen the app. Controlled from Settings: on/off toggle, volume slider
  (default 25%).
- **Click sounds**: one sound for menu/settings taps, a different one for
  taps inside lessons/tests/flashcards/review.
- **Wrong answers** now play an error sound plus a short vibration.
- The Settings screen's "About the app icon" info text has been removed
  (it was just cluttering the screen) — the custom launcher icon itself
  is unchanged and still set up the same way as before.

## What's in 1.1: Daily Review (spaced repetition)

Every vocab word and kanji tracks its own learning progress on-device (no
account, no server). Rate each review **Again / Hard / Good / Easy** and
the app schedules when it should come back — missed items sooner,
well-known ones much later. The home screen's top banner always shows
what's due today and is the fastest way into a review session; Flashcards
mode feeds the same progress too (swipe up = Good, swipe down = Again),
so nothing you do in the app is thrown away when you leave a screen or
switch filters. Existing modes (Learn Sentences, Learn Kanji, Test) are
unchanged.
