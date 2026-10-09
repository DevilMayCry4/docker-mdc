FROM python:3.10-slim-bullseye as build-stage
RUN echo "deb http://archive.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list \
    && apt-get -y update \
    && apt-get -y upgrade \
    && apt install -y -q bash wget binutils upx \
    && apt-get autoremove --purge -y \
    && apt-get clean -y
 
RUN \
    apt-get -y update && apt-get -y upgrade \
    && apt install -y -q \
        bash \
        wget \
        binutils \
        upx \
        build-essential \
        cmake \
    && apt-get autoremove --purge -y \
    && apt-get clean -y

ARG MDC_SOURCE_VERSION=2.0.16
ENV MDC_SOURCE_VERSION=${MDC_SOURCE_VERSION:-0e7f7f497e49ae9c2dd776357892a1f1cd6d6068}

RUN mkdir -p /tmp/mdc && cd /tmp/mdc \
    && wget -O-  https://codeload.github.com/DevilMayCry4/Movie_Data_Capture/tar.gz/refs/tags/$MDC_SOURCE_VERSION  | tar xz -C /tmp/mdc --strip-components 1 \
    && python3 -m venv /opt/venv && . /opt/venv/bin/activate \
    && pip install --upgrade \
        pip \
        pyinstaller \
    && pip install -r requirements.txt \
    && pip install playwright \
    && pip install face_recognition --no-deps \
    && pyinstaller \
        -D Movie_Data_Capture.py \
        --hidden-import "ImageProcessing.cnn" \
        --hidden-import "playwright" \
        --hidden-import "playwright.sync_api" \
        --add-data "$(python -c 'import cloudscraper as _; print(_.__path__[0])' | tail -n 1):cloudscraper" \
        --add-data "$(python -c 'import opencc as _; print(_.__path__[0])' | tail -n 1):opencc" \
        --add-data "$(python -c 'import face_recognition_models as _; print(_.__path__[0])' | tail -n 1):face_recognition_models" \
        --add-data "Img:Img" \
        --add-data "scrapinglib:scrapinglib" \
    && cp /tmp/mdc/config.ini /tmp/mdc/dist/Movie_Data_Capture/config.template

FROM debian:11-slim
ARG BUILD_DATE
ARG VERSION

LABEL maintainer="virgil"
LABEL build_from="https://github.com/DevilMayCry4/Movie_Data_Capture"
LABEL org.opencontainers.image.source="https://github.com/DevilMayCry4/docker-mdc"

ENV TZ="Asia/Shanghai"
ENV UID=0
ENV GID=0
ENV UMASK=002
ENV PLAYWRIGHT_BROWSERS_PATH=/config/ms-playwright

ADD docker-entrypoint.sh docker-entrypoint.sh
COPY --from=build-stage /tmp/mdc/dist/Movie_Data_Capture /app

# Playwright chromium 系统运行依赖库，注释移到RUN外面，RUN内部续行无注释
RUN \
    apt-get -y update && apt-get -y upgrade \
    && apt install -y -q \
        gosu \
        ca-certificates \
        libnss3 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libxkbcommon0 \
        libgtk-3-0 \
        libgbm1 \
        libasound2 \
        libatspi2.0-0 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libxcursor1 \
        libxinerama1 \
        libxi6 \
    && apt-get autoremove --purge -y \
    && apt-get clean -y \
    && chmod +x docker-entrypoint.sh \
    && mkdir -p /data /config /config/ms-playwright \
    && useradd -d /config -s /bin/sh mdc \
    && chown -R mdc /data /config

VOLUME [ "/data", "/config" ]
ENTRYPOINT ["/docker-entrypoint.sh"]
