# Git Conflict Fix and Push Guide

Notes for Ofer, written after fixing the `mpages` Git problem on 2026-07-07.

## Short Summary

The repository had a merge conflict while trying to bring local `main` together with `origin/main`.

Local `main` had the new `Matot_Masei` generated files.  
Remote `origin/main` had newer edits to the older `Pinchas` PDF loader files.

The fix was:

1. Inspect the Git state.
2. Confirm a merge was already in progress.
3. Inspect the conflicting files and Git stages.
4. Decide that the local `Matot_Masei` files were the correct files to keep.
5. Resolve both conflicts with `--ours`.
6. Stage the resolved files.
7. Verify no conflict markers remained.
8. Finish the merge commit.
9. Push `main` to GitHub.

## What the Problem Was

`git status` showed:

```text
## main...origin/main [ahead 1, behind 4]
UU pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html
UU pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html
```

Meaning:

- Local `main` had 1 commit that was not on GitHub.
- GitHub `origin/main` had 4 commits that were not local.
- The branch had diverged.
- A merge was already in progress.
- `UU` means both sides modified the same logical files and Git could not choose automatically.

The conflicted files were:

```text
pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html
pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html
```

Git also showed:

```text
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)
```

after the conflicts were resolved.

## Why the Conflict Happened

The local commit was:

```text
af650ba Add feature
```

It replaced/generated the new `Matot_Masei` files.

The remote commits updated old `Pinchas` loader files:

```text
19f8c72 Update f2.Pinchas.pdf.20260628.130307.pdf.loader.scroll.v1.html
8713af5 Update f2.Pinchas.pdf.20260628.130307.pdf.loader.scroll.v1.html
8b8704a Update f2.Pinchas.pdf.20260628.130307.pdf.loader.scroll.v2.html
e553694 Update f2.Pinchas.pdf.20260628.130307.pdf.loader.scroll.v2.html
```

Git detected the `Pinchas` files as renamed/replaced by the new `Matot_Masei` files, so it tried to merge old remote `Pinchas` edits into new local `Matot_Masei` generated files.

That created conflict markers like:

```text
<<<<<<< HEAD
...
=======
...
>>>>>>> origin/main
```

## Important Decision

For this specific conflict, the correct result was to keep the local `Matot_Masei` files.

Reason:

- The local branch contained the new generated portion: `Matot_Masei`.
- The incoming remote changes were for the older portion: `Pinchas`.
- Mixing remote `Pinchas` HTML/PDF URLs into local `Matot_Masei` files would create incorrect pages.

So the resolution used:

```powershell
git checkout --ours -- `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"
```

During a merge:

- `--ours` means the current local branch version.
- `--theirs` means the incoming remote branch version.

Do not use `--ours` automatically every time. Inspect first.

## Every Step That Was Used

### 1. Check the short Git status

```powershell
git status --short --branch
```

This showed:

```text
## main...origin/main [ahead 1, behind 4]
UU pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html
UU pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html
```

### 2. Check detailed status and recent history

```powershell
git status --porcelain=v2 --branch
git log --oneline --graph --decorate --all -n 20
```

This confirmed:

- `main` and `origin/main` had diverged.
- Local `HEAD` was `af650ba Add feature`.
- Remote `origin/main` was `e553694`.

### 3. Search for conflict markers

```powershell
Select-String -Path `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html",`
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html" `
  -Pattern "<<<<<<<|=======|>>>>>>>"
```

This confirmed both files contained merge conflict markers.

### 4. Confirm this was a merge, not a rebase or cherry-pick

```powershell
git status
git ls-files -u -- `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"
```

Also checked `.git/MERGE_HEAD`.

Result:

```text
MERGE_HEAD exists
```

So the fix was to resolve conflicts and then run `git commit`.

### 5. Inspect what each side changed

```powershell
$base = git merge-base HEAD origin/main

git diff --name-status --find-renames $base HEAD -- pdf_scroll
git diff --name-status --find-renames $base origin/main -- pdf_scroll
```

This showed:

- Local side added `Matot_Masei` files.
- Local side deleted/replaced `Pinchas` files.
- Remote side modified only two old `Pinchas` loader files.

### 6. Inspect Git conflict stages

For conflicted files, Git stores 3 versions:

- Stage 1: common ancestor.
- Stage 2: ours/local/current branch.
- Stage 3: theirs/incoming branch.

Useful commands:

```powershell
git show ":1:pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html"
git show ":2:pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html"
git show ":3:pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html"
```

The important finding was:

- Stage 2 contained `Matot_Masei`.
- Stage 3 contained `Pinchas`.

So stage 2 was the correct version for this case.

### 7. Resolve the conflicts by keeping local files

```powershell
git checkout --ours -- `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"
```

### 8. Stage the resolved files

```powershell
git add `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"
```

### 9. Verify Git says conflicts are fixed

```powershell
git status
```

Expected result:

```text
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)
```

### 10. Verify no conflict markers remain

```powershell
Select-String -Path `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html",`
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html" `
  -Pattern "<<<<<<<","=======",">>>>>>>"
```

Expected result:

- No output.

### 11. Run Git whitespace/conflict sanity check

```powershell
git diff --cached --check
```

Expected result:

- No output.

### 12. Finish the merge commit

```powershell
git commit --no-edit
```

This created:

```text
5e5e611 Merge branch 'main' of https://github.com/StarCraft-il/mpages
```

### 13. Verify the branch is ready to push

```powershell
git status --short --branch
git log --oneline --graph --decorate --max-count=8
```

This showed local `main` was ahead and ready to push.

### 14. Push to GitHub

```powershell
git push origin main
```

Push result:

```text
To https://github.com/StarCraft-il/mpages.git
   e553694..5e5e611  main -> main
```

### 15. Final verification

```powershell
git status --short --branch
```

Expected final result:

```text
## main...origin/main
```

No extra files listed means:

- Working tree is clean.
- Local `main` is synced with `origin/main`.

## Quick Fix Recipe for the Same Situation

Only use this if the same conflict happens again and the correct files are the new local generated portion files.

```powershell
git status --short --branch

git checkout --ours -- `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"

git add `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html" `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html"

git diff --cached --check

Select-String -Path `
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v1.html",`
  "pdf_scroll/f2.Matot_Masei.pdf.20260706.235019.pdf.loader.scroll.v2.html" `
  -Pattern "<<<<<<<","=======",">>>>>>>"

git status
git commit --no-edit
git push origin main
git status --short --branch
```

## Safe Checklist for Next Time

Before choosing `--ours` or `--theirs`, always check:

1. What branch am I on?

   ```powershell
   git status --short --branch
   ```

2. Is a merge in progress?

   ```powershell
   git status
   ```

3. Which files are conflicted?

   ```powershell
   git ls-files -u
   ```

4. What is local vs remote?

   ```powershell
   git show ":2:path/to/conflicted-file"
   git show ":3:path/to/conflicted-file"
   ```

5. Are conflict markers gone?

   ```powershell
   Select-String -Path "path/to/conflicted-file" -Pattern "<<<<<<<","=======",">>>>>>>"
   ```

6. Did Git accept the resolution?

   ```powershell
   git status
   ```

7. Did the push work?

   ```powershell
   git push origin main
   git status --short --branch
   ```

## What Not To Do

- Do not force push unless you intentionally want to overwrite remote history.
- Do not choose `--ours` or `--theirs` without checking what each side contains.
- Do not commit files that still contain `<<<<<<<`, `=======`, or `>>>>>>>`.
- Do not mix old `Pinchas` PDF URLs into new `Matot_Masei` generated files.
- Do not abort a merge after conflicts are already correctly resolved unless you want to restart the whole merge.

