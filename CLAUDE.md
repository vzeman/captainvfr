# Development workflow
ALWAYS use specialized agents for each development step to achieve the best results and code quality:

1. **Planning Phase** - Use `issue-analysis-architect` agent to analyze GitHub issues and create comprehensive implementation plans
2. **Development Phase** - Use `dev-cycle-orchestrator` agent to manage the complete development lifecycle from planning through implementation
3. **Code Review** - Use `code-review-expert` agent after implementing new features, fixing bugs, or refactoring code for thorough analysis
4. **Testing** - Use `mobile-app-qa-specialist` agent for iOS/macOS app testing, including functionality, UI/UX validation, and screenshot capture, ask user to do manual test with exact steps to reproduce the issue
   - Use `hugo-cms-qa-specialist` agent for website testing, including functionality, UI/UX validation, and screenshot capture
   - Use `github-issue-manager` agent to update issue for any bugs found during testing
5. **Documentation** - Use `hugo-cms-developer` agent to update website documentation in hugo/content/en/ if there are no erors or warnings in the codebase and PR is ready for merge

If you can do some tasks parallel, you can use multiple agents at the same time.

## Workflow Guidelines
- ALWAYS use `github-issue-manager` agent to manage GitHub issues, avoiding duplicates and maintaining organized tracking
- Use github CLI (gh command) to interact with issues, PRs, branches, and commits
- Before you start development, Create new branch from main (latest pull from github)
- Reference issue in PR for automatic closing when merged

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
