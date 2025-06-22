ARG baseVersion=1.0.0
FROM massix86/gleeter:${baseVersion}

RUN mkdir -p /home/gleeter/.config/gleeter
COPY --chown=gleeter: ./config.toml /home/gleeter/.config/gleeter/config.toml
