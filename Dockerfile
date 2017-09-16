FROM ruby:2.2.2

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main 10" >> /etc/apt/sources.list.d/pgdg.list \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update \
  && apt-get install -qq -y --fix-missing --no-install-recommends \
       build-essential \
       less \
       libpq-dev \
       postgresql-client-10 \
  && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 1.15.2

RUN mkdir /code

WORKDIR /code

ENV PATH "/code/bin:$PATH"

CMD /bin/sleep infinity
