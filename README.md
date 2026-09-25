# gh-pusher

Push a git repo to GitHub from inside a throwaway container, so your Mac never
holds a GitHub token, an SSH key, or a git identity.

```
$ cd ~/Github/some-repo
$ gh-pusher -m "feat: add thing"
gh-pusher: committed: 3f9a12c feat: add thing
gh-pusher: pushing main -> shazi7804/some-repo
gh-pusher: done
```

## How it works

`gh-pusher` runs `docker run --rm`, bind-mounts the repo at `/repo`, and pushes
over HTTPS with a token read from the macOS Keychain and passed in as an env var.

Three things keep the host clean:

- `GIT_CONFIG_GLOBAL=/tmp/gitconfig` — all global git config is written inside
  the container and dies with it.
- The token is supplied through a `credential.helper` that echoes it from the
  environment, so it is never written to any config file.
- The push target is passed as an explicit URL argument, so your repo's own
  `origin` (SSH or HTTPS) is never rewritten and no token ends up in
  `.git/config`.

The container is removed after every push.

## Install

```bash
git clone https://github.com/shazi7804/git-pusher.git ~/Github/git-pusher
ln -s ~/Github/git-pusher/bin/gh-pusher ~/.local/bin/gh-pusher
```

That's it. The image builds itself on first use, and if you have ever done a
`git push` over HTTPS on this Mac there is no token to set up either.

### Where the token comes from

Resolved in order, first hit wins:

1. `$GH_TOKEN` or `$GITHUB_TOKEN` in the environment
2. `gh-pusher`'s own keychain item, created by `gh-pusher login`
3. the credential git's `osxkeychain` helper already stored for `github.com`

Step 3 is why most setups need nothing: a previous `git push` already left a
usable PAT in the login keychain. `gh-pusher` prints which source it used on
every run.

Run `gh-pusher login` only if you want a dedicated token — for example one
scoped more tightly than the one git already has. It prompts for the token
without echoing it, so the value never reaches argv or your shell history.

Tokens should be [fine-grained PATs](https://github.com/settings/personal-access-tokens)
with **Contents: Read and write** on the repos you push. Add
**Pull requests: Write** to open PRs from `gh-pusher shell`.

### Where the commit identity comes from

If `~/.config/gh-pusher/config` has a name and email, that is used. Otherwise
the container calls `gh api user` and commits as the token's owner, falling back
to `<login>@users.noreply.github.com` when the account's email is private. So
`user.email` never has to be configured on the host.

## Usage

```
gh-pusher [push] [options] [-- git-push-args...]
gh-pusher <command>

Options:
  -m, --message MSG    stage everything and commit with MSG before pushing
  -t, --tag NAME       create annotated tag NAME at HEAD and push it too
      --tag-message MSG  annotation for -t (default: the tag name)
  -r, --remote NAME    remote whose URL to resolve (default: origin)
  -C, --dir PATH       repository to push (default: current directory)

Commands:
  push       push the current branch (the default; may be omitted)
  login      store a GitHub token in the macOS Keychain
  logout     delete the stored token
  build      rebuild the container image
  shell      open a shell in the container with the repo mounted at /repo
  help       show this message
```

Pushing is the default action, so `gh-pusher` and `gh-pusher push` are the same.

Without `-m`, only committed history is pushed and you get a warning if the
working tree is dirty.

### Tags

`-t` cuts a release in one call — commit, tag, push both refs:

```bash
gh-pusher -m "0.6.0 — mobile AIDLC" -t v0.6.0
```

The tag is created *inside* the container, so its annotation gets the same
identity as the commit and no `user.email` is needed on the host. If the tag
already exists locally it is pushed unchanged, which is how you ship a tag you
made earlier with plain `git tag`.

To push every local tag instead of a named one, pass git's own flag through:

```bash
gh-pusher -- --tags           # all tags
gh-pusher -- --follow-tags    # only annotated tags reachable from HEAD
```

`gh-pusher shell` drops you into the container with `git` and `gh` available and
credentials already wired up — useful for `gh pr create`, interactive rebases, or
anything else you'd rather not run against your host git config.

## What this does and does not isolate

**Isolated:** the push itself. No token, SSH key, `user.email` or credential
helper is *added* to your Mac — nothing is written to `~/.gitconfig` or `~/.ssh`,
and `.git/config` in the repo is never rewritten. Note that reusing an existing
`osxkeychain` credential reads a secret that was already on the Mac; it does not
put a new one there.

**Not isolated:** the network path. The container shares the host's network, so
the push still leaves from your Mac's IP. If you need the push to originate from
somewhere else, you want a remote environment (Codespaces, a VPS, or CI), not a
local container.

## Requirements

- macOS (uses `security` for Keychain access)
- Docker
- git on the host, used only to locate the repo root
