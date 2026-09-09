# syntax=docker/dockerfile:1
ARG LANGUAGETOOL_BASE_IMAGE=erikvl87/languagetool:6.8@sha256:ef8fa12cbd485166c9ceeb7139d76d56d07707a624da6bb1fc1fbb5411750527

FROM ${LANGUAGETOOL_BASE_IMAGE}

# Keep the upstream 6.8 runtime and models, replacing only the entrypoint with
# OpenADA's safer defaults: opt-in CORS and no configuration-value logging.
COPY --chown=languagetool:languagetool --chmod=755 start.sh ./start.sh

HEALTHCHECK --timeout=10s --start-period=5s \
  CMD curl --fail --data "language=en-US&text=a simple test" http://localhost:8010/v2/check || exit 1

CMD ["bash", "start.sh"]
