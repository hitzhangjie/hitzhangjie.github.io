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

## deploy locally

you should pay attention to this:

1. run `npm install`, you may encounter some errors, like:
    ```
    This version of npm is compatible with lockfileVersion@1, but package-lock.json was generated for lockfileVersion@2
    ```
    it means your nodejs version may be too old, you could use `nvm` to manage your 
    node.js versions.
2. install `nvm` on rhel
    ```
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    ```
3. install newer version of node.js
    ```
    nvm install v19.8.1
    ```
4. then install the required packages
    ```
    npm install
    ```
5. finally, run `hugo serve`
    well, if you haven't installed hugo before, install it first:
    ```
    go install --tags=extended -v github.com/gohugoio/hugo@latest
    ```

