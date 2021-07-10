FROM ruby:latest

WORKDIR /test

ADD lib/* lib/
ADD /spec/* spec/
ADD Gemfile .
ADD .rspec .

RUN gem install bundler
RUN bundle install
