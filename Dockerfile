FROM alpine:3.22

RUN apk add --no-cache \
      git \
      github-cli \
      openssh-client \
      ca-certificates

COPY image/gh-push /usr/local/bin/gh-push
RUN chmod +x /usr/local/bin/gh-push

# Global git config lives in the container's tmp, never in the mounted repo,
# so no credential or identity ever lands on the host filesystem.
ENV GIT_CONFIG_GLOBAL=/tmp/gitconfig \
    GIT_TERMINAL_PROMPT=0

WORKDIR /repo
ENTRYPOINT ["/usr/local/bin/gh-push"]
