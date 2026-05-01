# GitHub Actions workflows

## `publish-docs.yml`

Auto-publishes the contents of `docs/` to GitHub Pages on every push to `main`
that touches `docs/**`. Also runnable on demand via the **Run workflow** button
in the Actions tab (`workflow_dispatch`).

The workflow does no build step — `docs/` is treated as already-rendered static
output. It simply uploads the directory as a Pages artifact via the official
`actions/configure-pages`, `actions/upload-pages-artifact`, and
`actions/deploy-pages` actions, then deploys it. Concurrency group `pages` is
set with `cancel-in-progress: false` so an in-flight deploy is allowed to
finish rather than being cut off by a follow-up push.

### One-time manual setup (required)

GitHub Pages must be enabled on the repo and configured to deploy **from
GitHub Actions** (not from a branch). Until that's done, the workflow will
succeed at uploading the artifact but the deploy step will fail.

**Web UI:** Settings → Pages → Source → "GitHub Actions".

**CLI:**
```bash
gh api repos/nbardy/shader_benchmark/pages -X POST -f build_type=workflow
```

After enabling, every push to `main` that changes `docs/` will deploy to:

https://nbardy.github.io/shader_benchmark/

### Caveats

- **Private repos:** GitHub Pages on private repositories requires GitHub Pro
  or Team. On the free tier, the repo must be public for Pages to serve.
- **First deploy:** The very first run after enabling Pages can take a couple
  of minutes to propagate before the URL responds.
- The deploy URL surfaces in the Actions tab via the job's `environment.url`
  output (`${{ steps.deployment.outputs.page_url }}`).
