ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

    fixtures :all
  end
end
