FROM archlinux:base

ARG HOST_UID=1000
ARG HOST_GID=1000

# tmux (multiplexer), ttyd (web terminal), nodejs/npm (CLIs + status server), git.
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
      tmux ttyd nodejs npm git shadow vim less ripgrep openssh && \
    pacman -Scc --noconfirm

# Pin to the exact versions already in use on the host.
# claude-code's postinstall fetches a native binary and can fail silently
# (npm treats the optional-dependency download as non-fatal) if there's a
# transient network hiccup during build, leaving `claude` broken at runtime.
# Re-running install.cjs explicitly makes that failure loud instead of silent.
RUN npm install -g \
      @anthropic-ai/claude-code@2.1.278 \
      @openai/codex@0.155.1 && \
    node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs" && \
    claude --version

# Mirror the host UID/GID so bind-mounted ~/.claude, ~/.codex, ~/Projects
# don't hit permission mismatches.
RUN groupadd -g ${HOST_GID} ayo && \
    useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash ayo

USER ayo
WORKDIR /home/ayo
ENV HOME=/home/ayo \
    HISTFILE=/home/ayo/.agent-state/bash_history

COPY --chown=ayo:ayo entrypoint.sh /home/ayo/entrypoint.sh
COPY --chown=ayo:ayo status-server /home/ayo/status-server
COPY --chown=ayo:ayo tmux.conf /home/ayo/.tmux.conf
RUN chmod +x /home/ayo/entrypoint.sh

EXPOSE 7681 8080

ENTRYPOINT ["/home/ayo/entrypoint.sh"]
