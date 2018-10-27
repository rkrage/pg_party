# frozen_string_literal: true

RSpec::Matchers.define :match_heredoc do |expected|
  match do |actual|
    actual.squish == expected.squish
  end
end

RSpec::Matchers.alias_matcher :heredoc_matching , :match_heredoc

RSpec::Matchers.define :include_heredoc do |expected|
  match do |actual|
    actual.squish.include?(expected.squish)
  end
end

RSpec::Matchers.alias_matcher :heredoc_including, :include_heredoc
