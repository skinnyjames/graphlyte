# frozen_string_literal: true

require 'stringio'

module Mocks
  def self.included(mod)
    mod.before(:all) do
      next if @server_pid

      log_file = 'log/json-graphql-server.log'
      timeout = 2 # seconds

      File.truncate(log_file, 0)
      command = %w[json-graphql-server fixture/mocks.json --p 5000]

      @server_pid = spawn(*command, [:err, :out] => [log_file, 'w'])

      STDOUT.print 'Waiting for server'
      slept = 0
      until slept > timeout || File.read(log_file).include?('server running')
        sleep(0.1)
        slept += 0.1
        putc '.'
      end

      if slept > timeout
        Process.kill('TERM', @server_pid) if @server_pid
        @server_pid = nil
        raise 'Could not start server' if timeout
      end

      puts ' ready'
    end

    mod.after(:all) do
      Process.kill('TERM', @server_pid) if @server_pid
      @server_pid = nil
    end
  end

  def mock_response(name)
    mocks = JSON.parse File.read("#{__dir__}/../../../fixture/mocks.json")

    mocks.fetch(name)
  end
end
