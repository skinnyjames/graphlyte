.bundle-install: Gemfile graphlyte.gemspec
	bundle install
	touch .bundle-install

.PHONY: test
test: .bundle-install
	bundle exec rspec

.PHONY: lint
lint: .bundle-install
	bundle exec rubocop

.PHONY: all
all: test lint
