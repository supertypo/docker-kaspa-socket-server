##
# builder image
##
FROM python:3.10-slim AS builder

ARG REPO_DIR
ARG VERSION

ENV APP_USER=api \
  APP_UID=55747 \
  APP_DIR=/app \
  VERSION=$VERSION

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    libpq-dev

RUN pip install \
  pipenv

RUN groupadd -r -g $APP_UID $APP_USER && \
  useradd -d $APP_DIR -r -m -s /sbin/nologin -g $APP_USER -u $APP_UID $APP_USER

WORKDIR $APP_DIR
USER $APP_USER

COPY --chown=$APP_USER:$APP_USER "$REPO_DIR" $APP_DIR

RUN pipenv install --deploy -v
RUN rm -r .cache/

##
# kaspa-socket-server image
##
FROM python:3.10-slim

ARG VERSION

ENV APP_USER=api \
  APP_UID=55747 \
  APP_DIR=/app \
  VERSION=$VERSION

ENV KASPAD_HOST_1=kaspad:16110 \
  SQL_URI=postgresql+asyncpg://postgres:password@postgresql:5432/postgres

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    libpq-dev \
    dumb-init && \
  rm -rf /var/lib/apt/lists/*

RUN pip install \
  pipenv

RUN groupadd -r -g $APP_UID $APP_USER && \
  useradd -d $APP_DIR -r -m -s /sbin/nologin -g $APP_USER -u $APP_UID $APP_USER

WORKDIR $APP_DIR
USER $APP_USER

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD pipenv run gunicorn -b 0.0.0.0:8000 -w 1 -k uvicorn.workers.UvicornWorker main:app --timeout 120

COPY --chown=$APP_USER:$APP_USER --from=builder $APP_DIR $APP_DIR

