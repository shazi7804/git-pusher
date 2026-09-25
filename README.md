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
gh-pusher login          # prompts for token, then author name/email
```

`login` stores the token in the login keychain under the service `gh-pusher`,
and the commit identity in `~/.config/gh-pusher/config`.

Use a [fine-grained PAT](https://github.com/settings/personal-access-tokens)
with **Contents: Read and write** on the repos you want to push. Add
**Pull requests: Write** if you want to open PRs from `gh-pusher shell`.

The image builds itself on first use.

## Usage

```
gh-pusher [options] [-- git-push-args...]
gh-pusher <command>

Options:
  -m, --message MSG    stage everything and commit with MSG before pushing
  -r, --remote NAME    remote whose URL to resolve (default: origin)
  -C, --dir PATH       repository to push (default: current directory)

Commands:
  login      store a GitHub token in the macOS Keychain
  logout     delete the stored token
  build      rebuild the container image
  shell      open a shell in the container with the repo mounted at /repo
  help       show this message
```

Without `-m`, only committed history is pushed and you get a warning if the
working tree is dirty.

`gh-pusher shell` drops you into the container with `git` and `gh` available and
credentials already wired up — useful for `gh pr create`, interactive rebases, or
anything else you'd rather not run against your host git config.

## What this does and does not isolate

**Isolated:** the token, SSH keys, `user.email`, and every other piece of git
config. Nothing is added to your Mac's `~/.gitconfig` or `~/.ssh`.

**Not isolated:** the network path. The container shares the host's network, so
the push still leaves from your Mac's IP. If you need the push to originate from
somewhere else, you want a remote environment (Codespaces, a VPS, or CI), not a
local container.

## Requirements

- macOS (uses `security` for Keychain access)
- Docker
- git on the host, used only to locate the repo root
