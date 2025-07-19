## Workflow Guidelines
- Always use plan.md file to understand tasks and plan execution
- ALWAYS check if code has no ERRORS, WARNINGS or RECOMMENDATIONS during building to keep the code clean and without issues 
- ALWAYS REFACTOR classes and methods to keep the code clean and readable without duplicated code, split too long classes (more than 800 lines) into smaller classes 
- ALWAYS keep the code clean without your test files or helper files you create during development to try something, remove them after you finish the task
- DON'T create random readme files, which I didnt request, use plan.md file to describe your task and how you implemented it
- After each bigger change document changes also to website in hugo/content/en/ so we keep the documentation up to date with features of the app
- website tasks are in hugo/hugo-plan.md file

# Guide for Claude - Website development (Hugo CMS)

- website files are stored in /hugo directory
- all content is in /hugo/content/en/ directory
- all images are in /hugo/static/images/ directory
- always make sure hugo project build is successful after making changes
- if you need to learn from other examples of website, check /Users/viktorzeman/work/FlowHunt-hugo/ - it is another website built with the same hugo theme, you can learn about structures of layouts, partials, shortcodes
- review and develop tasks in hugo-plan.md file and always update status of tasks when any task is ready