# NOTE
---
* This app runs on MacOS 26

# Bugs
---

Fixes
* Formatting of goals completed checkmarks UI, specifically on the task debreif part of the dashboard needs fixing.
* User progress/metrics related to AnkiCards not being logged. Accuracy on dashboard does not change. “Next due” dates are not changing as well.
* “Settings” window appears on app startup. We should add some logic that says “if user pressed maximize settings button -> maximize”; else -> kill the window if it is open.
* Create task and modify task windows should appear at the absolute center of the screen.

Features
* Add markdown support for Anki flashcard-related fields.
    * Single `$...$` wrappers for inline latex; `$$...$$` for newline, centered latex blocks.
* Settings window now allows user to select between different fonts.