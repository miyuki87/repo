---
description: Publish this project to GitHub with README, About section, GitHub Pages, CI/CD and a secrets check
argument-hint: <owner/repo or GitHub URL> [public|private] [branch]
---

# Publish to GitHub

Publish the current project to GitHub and set up its public face. Work through the steps below in order. The secrets check runs BEFORE anything leaves this machine, even though it is listed as its own step.

Repo info from the user: `$ARGUMENTS`

## 0. Gather inputs

1. Parse `$ARGUMENTS` for:
   - The target repo, as `owner/repo` or a `https://github.com/owner/repo(.git)` URL.
   - Visibility, `public` or `private` (only used if the repo has to be created). Default: `public`.
   - The branch to publish. Default: the current branch if it is `main` or `master`, otherwise `main`.
2. If the repo is missing or unclear, ask the user before doing anything else. Do not guess an owner or repo name.
3. Check the tools you have:
   - `git --version`
   - `gh --version` and `gh auth status`. If `gh` is installed but not logged in, ask the user to run `gh auth login` (or `! gh auth login` from the prompt) and wait.
   - If `gh` is not available at all, use the GitHub MCP tools (`mcp__github__*`) where they cover the step, and for anything they cannot do, give the user the exact manual steps in the GitHub web UI.
4. Check whether the repo exists: `gh repo view OWNER/REPO --json name,visibility,defaultBranchRef,homepageUrl,description`. Note the result. Do not create it yet.

## 1. Make sure no sensitive data goes to the internet

Do this before any push. If you find anything, stop and report it to the user with file and line. Do not push until the user has decided what to do.

1. Look at what would be published: `git ls-files` plus any untracked files that are not ignored (`git ls-files --others --exclude-standard`).
2. Make sure a `.gitignore` exists and covers the usual risky files. Add any missing entries:
   ```
   .env
   .env.*
   !.env.example
   *.pem
   *.key
   *.p12
   *.pfx
   id_rsa*
   *.log
   .DS_Store
   Thumbs.db
   node_modules/
   .claude/settings.local.json
   ```
   If any of these are already tracked, tell the user and offer `git rm --cached <file>` (this keeps the local file).
3. Scan for secrets:
   - If `gitleaks` is installed, run `gitleaks detect --source . --redact` (this also scans git history).
   - Otherwise grep the working tree AND history. Working tree:
     ```
     git grep -nIiE '(api[_-]?key|secret|passw(or)?d|token|bearer|private[_-]?key|client[_-]?secret|aws_access_key_id|aws_secret_access_key)\s*[:=]'
     git grep -nIE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]+|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
     ```
     History: `git log -p --all | grep -nIE '<same patterns>'`. A secret that was committed and later deleted is still public once pushed.
4. Check for personal or internal data:
   - Real email addresses: `git grep -nIE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'`. Placeholders like `YOUR_EMAIL@example.com` or `noreply@...` are fine. A real personal email (for example in a form endpoint such as FormSubmit) must be flagged, since it will be public and can be scraped for spam.
   - Internal hostnames, private IPs (`10.`, `192.168.`, `172.16-31.`), internal URLs, real customer or employee names, phone numbers, account numbers.
   - Real company logos or branding that the project should not carry.
5. Check commit author emails: `git log --format='%an <%ae>' | sort -u`. If a personal email appears and the user may not want it public, tell them about GitHub's `noreply` address. Do not rewrite history unless the user asks.
6. If history contains a secret, explain the options (rotate the secret first, then rewrite history with `git filter-repo` or start a fresh history) and let the user choose. Never force-push or rewrite history on your own.

Give the user a short result: "No sensitive data found" or a list of findings.

## 2. Create or update the README

1. Read the project first (main files, `CLAUDE.md` if present, existing `README.md`) so the README is accurate. Do not invent features.
2. If `README.md` exists, update it in place and keep anything the user wrote that is still correct. If not, create it.
3. Include:
   - Project name and a one-line summary.
   - Live demo link: `https://OWNER.github.io/REPO/` (or the custom domain if one is set).
   - CI status badge: `![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)`.
   - Features.
   - How to run it locally (for a static site: open `index.html` in a browser, no build step).
   - Configuration the user must set (for example a placeholder endpoint and how to replace it), without real values.
   - Project structure (short).
   - Deployment: how GitHub Pages and the Actions workflows work.
   - Any disclaimer the project needs (for example "demo only, fictitious company, not affiliated with any real bank").
   - License, only if a `LICENSE` file exists or the user asks for one.
4. Keep the language plain and direct.

## 3. Set up CI/CD with GitHub Actions

Create `.github/workflows/` files that fit the project type. Use the current major versions of the official actions (check the actions' release pages if unsure). Do not add secrets to workflow files.

### 3a. CI (`.github/workflows/ci.yml`)

Runs on push and pull request to the publish branch. Tailor the checks to the project:

- Node, Python, etc.: install, lint, test, build with the project's own commands.
- Plain static site (single `index.html`, no build, like this repo): a shell job that fails if the project's rules are broken. For this repo, follow the hard constraints in `CLAUDE.md`, for example:
  - `index.html` exists and is not empty.
  - No external scripts, stylesheets or fonts (`<script src="http`, `<link ... href="http`, `@import url(http`).
  - No storage APIs (`localStorage`, `sessionStorage`, `indexedDB`, `document.cookie`).
  - No `alert(` or `confirm(`.
  - No `!important` in CSS.
  - No real email in `FORMSUBMIT_ENDPOINT` (only the `YOUR_EMAIL@example.com` placeholder is allowed in the repo).
  - Optionally a headless browser smoke test that loads the page and checks for console errors.

  Keep grep checks precise so they do not fire on comments that explain the rule. Run each check locally before committing so CI is green on the first push.

Also add a secret scan job (for example `gitleaks/gitleaks-action` with `fetch-depth: 0` on checkout) so future pushes are checked too.

### 3b. CD to GitHub Pages (`.github/workflows/pages.yml`)

Deploy with the Actions-based Pages flow, not a `gh-pages` branch:

```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]        # use the publish branch
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: .           # or the build output folder, e.g. dist/
      - id: deployment
        uses: actions/deploy-pages@v4
```

- If the project has a build step, build first and upload the output folder only.
- If the site root is the repo root, add an empty `.nojekyll` file and make sure nothing private sits in the repo root, since every file in `path` becomes public. Prefer copying only the site files (for example `index.html`) into a `_site/` folder in a step and uploading that.
- Optionally make deploy wait for CI (`needs:` in one workflow, or `workflow_run`).

## 4. Push the code

1. Show the user a short summary of what will be pushed: target repo, branch, visibility (if creating), files added or changed in this run, and the secrets check result. Ask for a clear go-ahead. Pushing makes the code public (for a public repo) and cannot be fully undone.
2. Commit the new and changed files with a clear message, for example `Add README, CI and GitHub Pages workflows`. Only stage files you meant to change.
3. If the repo does not exist, create it: `gh repo create OWNER/REPO --public|--private --source=. --remote=origin` (no `--push` yet).
4. If it exists, set or check the remote: `git remote get-url origin`, else `git remote add origin https://github.com/OWNER/REPO.git`. If `origin` points somewhere else, ask before changing it.
5. Make sure the local branch name matches the publish branch (`git branch -M main` only if the user agrees to rename).
6. Push: `git push -u origin BRANCH`. If the remote has commits you do not have, fetch and show the user the difference. Never force-push unless the user explicitly asks.

## 5. Create or update GitHub Pages

1. Enable Pages with the Actions source:
   - New: `gh api -X POST repos/OWNER/REPO/pages -f build_type=workflow`
   - Existing: `gh api -X PUT repos/OWNER/REPO/pages -f build_type=workflow`
   - Check: `gh api repos/OWNER/REPO/pages --jq '.html_url,.build_type'`
2. Pages on a private repo needs a paid GitHub plan. If the API refuses for that reason, tell the user and offer to make the repo public or skip Pages.
3. Trigger or watch the deploy: `gh run list --workflow pages.yml --limit 1`, then `gh run watch <id>`. If it fails, read the logs (`gh run view <id> --log-failed`), fix the cause, commit and push again.
4. Confirm the site loads: `curl -sI https://OWNER.github.io/REPO/` should return `200` (a first deploy can take a minute or two).

## 6. Create or update the GitHub About section

Do this after Pages is live so the link works.

```
gh repo edit OWNER/REPO \
  --description "<one-line summary, under 350 characters>" \
  --homepage "https://OWNER.github.io/REPO/" \
  --add-topic <topic1> --add-topic <topic2> ...
```

- Base the description on the README summary. Plain wording, no marketing language.
- Pick 3 to 8 lowercase topics that describe the project (for example `kanban`, `project-management`, `vanilla-javascript`, `html`, `css`, `github-pages`, `demo`). Keep topics the user already set unless they are wrong.
- The `--homepage` value is the GitHub Pages link. Use the custom domain instead if one is configured (`gh api repos/OWNER/REPO/pages --jq .cname`).
- Check it: `gh repo view OWNER/REPO --json description,homepageUrl,repositoryTopics`.

## 7. Final report

Give the user a short summary:

- Repo URL and branch pushed.
- Secrets check result (and anything they still need to act on).
- README: created or updated.
- Workflows added, and the result of the latest CI and Pages runs.
- Live GitHub Pages URL.
- About section: description, homepage link, topics.
- Any manual steps left (for example a one-time activation email from a form service, rotating a leaked key, or enabling Pages in Settings if the API was refused).
