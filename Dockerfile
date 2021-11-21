FROM ruby:latest

WORKDIR /test

ADD fixture fixture
ADD lib lib
ADD /spec/* spec/
ADD Gemfile .
ADD graphlyte.gemspec .
ADD .rspec .

RUN gem install bundler
RUN bundle install
