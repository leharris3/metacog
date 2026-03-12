# Notes
---
* This app is designed for MacOS 26

# New Features
---

* **Projects**
    * Projects are long-horizon (i.e., multi-day or multi-week) efforts that required larger resource allocations and which are composed of multiple **tasks**.
    * Add a "Projects" page to the dashboard where users can create and manage their projects.
    * Setup Wizard
        * Like task setup, user provides project name, expected start date and end date.
        * Ask a series of meta cognition questions designed to help the user plan out their project. For instance, "Why is this project important?", "What challenges might you have face? How do you plan to overcome them?", etc. 
        * At a minimum, user creates *four tasks* that are assigned to the project using the usual task setup.
        * User also specifies project **deliverables** – concrete project goals.
    * Debreif Wizard
        * User answers meta-cognitive questions to reflect on project. For example, "During this project, what did you do well? What could you have done better?" "Did you accomplish the goals you created for this project at it's outset? Why or why not?" etc.
        * User reflects on all incomplete tasks and deliverables.
* Menu Bar Icon
    * The MetaCog app now has a white cog icon in the Mac menu bar. Users can close the and open the HUD from the menu bar similar to the design of native notifications panel

# Other Changes
---

* **Tasks**
    * Tasks that do not belong to a project are now limited to 30 minutes in duration.
    * Tasks can be assigned to projects; tasks belonging to a projected are indicated with tags on the task page of the dashboard.
* Anki
    * Before a user can create a new standalone task or project, an Anki flash card must be answered.

# Bug Fixes
---

* When a user edits an existing task (e.g., adds a new allowed app), the HUD appears at the very center of the screen instead of the bottom center of the screen.
* 