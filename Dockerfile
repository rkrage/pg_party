FROM ruby:2.4.1

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main 10" >> /etc/apt/sources.list.d/pgdg.list \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update \
  && apt-get install -qq -y --fix-missing --no-install-recommends \
       build-essential \
       less \
       libpq-dev \
       postgresql-client-10 \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir /code

WORKDIR /code

CMD /bin/sleep infinity
