# README

Welcome to MySpace!

## start a local static site

```
npm install
npm run start
```

## build & deploy to github pages

**The `.github/workflows/master.yml` defines a github action:**  
When pushing, github action `build and deploy pages` will be run, the static
site will be in root of branch gh-pages, then it could be served by the github
pages service.

ps: Before, this repo is maintained under hitzhangjie/myspace, and uses a
    script `deploy.sh` to build the pages and deploy to *.github.io.
    
Now we uses github action to build the staitc site, and deploy automatically.

Run following commands:
```bash
git clone //ghttps://github.com/hitzhangjie/myspace
git remote add io https://github.com/hitzhangjie/hitzhangjie.github.io
git push io master
```

By this way, we can maintain this repo under hitzhangjie/myspace (the docs,
issues, the PRs), and we can take the advantage of build and deploy to github
pages.
    
## Why not use hitzhangjie.github.io instead?

I don't like maintain directly under hitzhangjie/hitzhangjie.github.io, I just
want to use it as a publishing purposes. For example, I may use repo A or B as
the datasource of gh pages instead of hitzhangjie/myspace.

If using hitzhangjie.github.io to maintain directly, the issues, PRs will be messy.

This way gives much more flexibility in maintaining.
