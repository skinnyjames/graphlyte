# frozen_string_literal: true

require 'stringio'

module Mocks
  CouldNotStartServer = Class.new(StandardError)
  LOG_FILE = 'log/json-graphql-server.log'

  def self.included(mod)
    mod.before(:all) do
      next if @server_pid

      @server_pid = start_graphql_server
    end

    mod.after(:all) do
      Process.kill('TERM', @server_pid) if @server_pid
      @server_pid = nil
    end
  end

  def start_graphql_server
    File.truncate(LOG_FILE, 0) if File.exist?(LOG_FILE)

    command = %w[npm run serve]
    server_pid = spawn(*command, %i[err out] => [LOG_FILE, 'w'], chdir: "#{__dir__}/../../../fixture")

    wait_for_server

    server_pid
  rescue CouldNotStartServer
    Process.kill('TERM', server_pid) if server_pid
  end

  def wait_for_server
    # $stdout.print 'Waiting for server'
    timeout = 2 # seconds
    slept = 0

    until File.exist?(LOG_FILE) && File.read(LOG_FILE).include?('server running')
      sleep(0.1)
      slept += 0.1
      raise CouldNotStartServer, 'Could not start mock graphql server' if slept > timeout

      # putc '.'
    end

    # puts ' ready'
  end

  def mock_response(name)
    mocks = JSON.parse File.read("#{__dir__}/../../../fixture/mocks.json")

    mocks.fetch(name)
  end
end
