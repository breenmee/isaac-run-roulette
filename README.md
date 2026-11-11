# Isaac Run Roulette — Repentance+

Two animated wheels for your own Isaac progress. Choose a random **unlocked, unfinished character**, then a random **missing Hard-mode mark**. One first-wheel entry is **Challenges**, with **2× the weight of an individual character**, leading to an unlocked, unfinished challenge. Greedier is included, not standard Greed.

This repository is configured specifically for `breenmee/isaac-run-roulette`, save slot **1**. The initial `data/progress.json` comes from a user-provided Repentance+ slot-1 save. It **is not live Steam data** until the Windows helper first publishes an update.

## Step 1: Publish the website (one time)

1. On your Windows PC, **extract the release ZIP** you were given. You should see `index.html`, `README.md`, `data/`, and `windows/` inside the extracted folder.
2. Open [your repository](https://github.com/breenmee/isaac-run-roulette) on GitHub.
3. Choose **Add file → Upload files**, and drag in `index.html`, `data/` and `windows/` from inside the extracted folder. Add this README if you want. **Don't upload the ZIP itself** — GitHub Pages needs the actual files.
4. Commit directly to the **main** branch.
5. In the repository, open **Settings → Pages**. Under **Build and deployment**, choose **Deploy from a branch**, then branch **main** and folder **/(root)**. Save.
6. When Pages reports the site has been deployed, open **https://breenmee.github.io/isaac-run-roulette/** from any browser.

No runtime, backend, database subscription, or PC uptime is required for the website. GitHub Pages hosts the static page and the last published JSON. Progress data in this **public repository** is public; it contains only summary marks and challenges, *not* your save file or credentials.

## Step 2: Configure the sync on your Windows 11 PC

The `windows/Sync_Isaac.cmd` file launches a PowerShell helper. It reads a **local**, **Steam-synced** `rep+persistentgamedata1.dat` save **without modifying it**. It publishes only a derived `data/progress.json` to GitHub via the official Contents API.

1. In GitHub, create a [fine-grained Personal Access Token](https://github.com/settings/personal-access-tokens/new). Set **Repository access → Only select repositories → isaac-run-roulette** and **Repository permissions → Contents → Read and write**. Metadata read access may be added automatically. Choose a reasonable expiration date and create the token.
2. On your PC, locate the extracted folder, open `windows/`, and double-click **Sync_Isaac.cmd** (not the `.ps1` file).
3. On first run, it looks for `rep+persistentgamedata1.dat` in common Steam locations. If it finds multiple files, choose the correct one. If it can't find it, paste the exact path from your previously working Save Finder. Your choice is saved for later runs.
4. The helper displays your detected marks and challenges and **asks before publishing**. Confirm with `Y`.
5. The first time it asks for a GitHub token, paste the fine-grained token into the terminal. It is encrypted for your Windows user account using Windows DPAPI, under `%LOCALAPPDATA%\IsaacRunRoulette\github-token.dpapi`. **Never paste the token in the repository, website, or a chat message.**
6. After `SUCCESS!`, wait for GitHub Pages to deploy the updated commit, then press **Refresh progress** in the roulette (or reload the browser page).

**To sync again:** Close Isaac on the Thor, let Steam Cloud upload the save, and make sure your main PC has downloaded the new save. Then double-click `windows/Sync_Isaac.cmd` again and confirm publishing. **Steam Cloud may not download a new Thor save to the PC until Isaac launches there.** Check the save-file modified time shown in the helper and do not publish an older save as if current.

If you ever need to replace an expired/revoked token, run `windows/Reset_GitHub_Token.cmd` and sync again with a new token.

## What the wheel does

- **Character wheel:** All unlocked characters with unfinished Hard marks. No already-completed characters.
- **Challenges option:** One segment with 2× the weight of any one character; it appears only when at least one available, unfinished challenge exists.
- **Second wheel:** Only unfinished Hard marks, including Greedier if Greedier is unlocked. Selecting Challenges instead shows only available, unfinished challenges.
- **Reroll:** Unlimited. An immediate reroll chooses a different option when more than one option exists. There are no permanent exclusions.
- **Completion:** No manual fake completions. Spins do not alter your saves. Progress is updated only from new save snapshots.
- **Refresh:** The website fetches the published JSON when you tap Refresh, return to the browser tab, or leave the tab open for a couple minutes. Refreshing the page **does not itself trigger a Steam sync**.
- **Selection persistence:** The selected character and goal persist locally in the browser until you spin again or a new snapshot removes that goal as completed.

## Privacy and safety

- Never upload a raw `.dat` save to your public repo. The helper never sends raw saves, your Steam account number, paths, or secrets.
- GitHub token never appears in `progress.json` and is not stored in the repo; the helper stores it locally via Windows account encryption.
- The token has access only to the selected repository. Do not create a classic token with broad account permissions.
- Source code is inspectable. This is fan-made and not affiliated with Edmund McMillen, Nicalis, or Valve.

## Troubleshooting

**Page not found:** Check Settings → Pages for the correct branch and root folder, and check that `index.html` is at the repo root.

**The page loads but says unable to load progress:** Confirm the repo contains `data/progress.json` (not `Isaac_Run_Roulette_Release/data/progress.json` nested under an extra folder).

**The sync asks for a token every run:** Confirm you are using the same Windows user account and that `%LOCALAPPDATA%\IsaacRunRoulette` is writeable.

**Sync works but the website is old:** Confirm a new commit was created and that GitHub Pages has finished publishing. Reload your phone page. Check the `Updated` and `PC save modified` timestamps on the roulette.

**Your Thor run doesn't appear:** Steam Cloud may have uploaded it but the PC may still have the older local save. Refresh the save on the PC (for example by launching Isaac after synchronization) and check the file modification time before running Sync again.

**The helper fails:** It leaves the terminal open so you can screenshot the exact error. It never edits the save.

## References

- [Isaac save file format](https://isaac.ardor.guru/guides/save-file-format/) — chunk layout for Repentance+
- [IsaacGuru challenge list](https://isaacguru.com/challenges) — challenge prerequisites
- [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

## Developer notes

`data/progress.json` schema v1: `exact=true`, `characters` (34 entries with `id`, `name`, `unlocked`, `hardCompleted`, `goals`), `challenges` (45 entries with `id`, `name`, `unlocked`, `completed`), stats, timestamps. `windows/Sync_Isaac.ps1` parses chunks 1 (secrets), 2 (event-counter completion bits) and 7 (challenge completions) in the Repentance+ persistent save; it reads but never writes the save. Character unlocks use the relevant secret achievements; each locked challenge's availability uses its unlock secret; default challenges are always available. All 12 Hard/Greedier mark counters per character are considered. Normal and online completion bits do not count.
