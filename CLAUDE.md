# Development workflow
During development use all expert agents you have available to you, so you can get the best results. 
1. Plan - when you get new issue, read it carefully, understand what is needed to be done, if you have any questions, ask them and if you understand the issue, build implementation plan in the issue comments -> ask user to read the plan and if all is good, follow to development
2. Development - create new branch from main branch with the name of the issue and use all your knowledge from UX, UI, code quality, performance, security, etc. to implement the issue
3. Testing - test your code, make sure it works as expected, there are no errors, it looks good, if you need to make specific test by user, document the steps user should do to properly test the feature.
4. Code review - create pull request, make sure you have no errors, warnings or recommendations in the code, make sure you have no duplicated code, make sure the code is clean and readable, make sure you have no useless code in the pull request, make sure you have no commented out code in the pull request, make sure you have no TODOs in the pull request
5. Documentation - after you finish the pull request, document the changes in the issue, update website content

## Guidelines
- ALWAYS check if code has no ERRORS, WARNINGS or RECOMMENDATIONS during building to keep the code clean and without issues 
- ALWAYS REFACTOR classes and methods to keep the code clean and readable without duplicated code, split too long classes (more than 800 lines) into smaller classes 
- ALWAYS keep the code clean without your test files or helper files you create during development to try something, remove them after you finish the task
- DON'T create random readme files, which I didnt request
- After each bigger change document changes also to website in hugo/content/en/ so we keep the documentation up to date with features of the app
- use github cli to interact with issues, pull requests (PR), branches, commits, etc. to keep the workflow smooth and fast
- before starting development of specific issue, describe you plan in the issue as comment, so I can review it and give you feedback about the implementation plan
- for each issue create new branch from main branch (pull latest files) with the name of the issue, so it is clear what you are working on and once ready, create pull request
- add comments to issue when you start working on it, so I know you are working on it, add comments to issue when you discovered something important what needs to be changed in the code because of issue, add to issue also description what you plan to do to implement the issue with concept of changes
- after you finish implementation and create pull request (reference issue in PR so it is closed automatically when merged), make deep review of the pull request: analyze all changes, check if there are no duplicated codes, forgotten comments, performance improvements, maybe there are useless codes, which are not needed anymore and were done just for testing purpouses, etc.

# Application design
- background of form and dialogs should be black
- there should be high contrast between color of text and background
- use dark theme for all dialogs and forms
- example of nice color scheme is current airspaces panel, which is black background with white text and orange or light blue highlights

# Guide for Claude - Website development (Hugo CMS)

- website files are stored in /hugo directory
- all content is in /hugo/content/en/ directory
- all images are in /hugo/static/images/ directory
- always make sure hugo project build is successful after making changes
- if you need to learn from other examples of website, check /Users/viktorzeman/work/FlowHunt-hugo/ - it is another website built with the same hugo theme, you can learn about structures of layouts, partials, shortcodes
