require "shell_command/version"
require "shell_command/hash"
require "shell_command/environment_variables"

require 'pty'
require 'shellwords'
require 'fileutils'
require 'timeout'

KILOBYTE = 2048

class ShellCommand
  MAX_READ = 64 * KILOBYTE

  Error = Class.new(StandardError)
  NotFound = Class.new(Error)
  Denied = Class.new(Error)
  TimedOut = Class.new(Error)

  class Failed < Error
    attr_reader :exit_code

    def initialize(message, exit_code)
      super(message)
      @exit_code = exit_code
    end
  end

  attr_reader :out, :code, :chdir, :env, :args, :pid, :timeout

  def initialize(*args, default_timeout: 300, env: {}, chdir:)
    @args, options = parse_arguments(args)
    @timeout = options['timeout'.freeze] || options[:timeout] || default_timeout
    @env = env
    @chdir = chdir.to_s
  end

  def with_timeout(new_timeout)
    old_timeout = timeout
    @timeout = new_timeout
    yield
  ensure
    @timeout = old_timeout
  end

  def to_s
    @args.join(' ')
  end

  def interpolate_environment_variables(argument)
    return argument.map { |a| interpolate_environment_variables(a) } if argument.is_a?(Array)

    EnvironmentVariables.with(env).interpolate(argument)
  end

  def success?
    return false if code == 'timeout'
    !code.nil? && code.zero?
  end

  def exit_message
    "#{self} exited with status #{@code}"
  end

  def run
    output = []
    stream do |out|
      output << out
    end
    output.join
  rescue TimedOut
    output.join
  end

  def run!
    output = []
    stream! do |out|
      output << out
    end
    output.join
  end

  # We actually do need the interpolation here!
  # rubocop:disable Style/RedundantInterpolation
  def with_full_path
    old_path = ENV['PATH']
    ENV['PATH'] = "#{ENV['PATH']}"
    yield
  ensure
    ENV['PATH'] = old_path
  end
  # rubocop:enable Style/RedundantInterpolation

  def interpolated_arguments
    interpolate_environment_variables(@args)
  end

  def start(&block)
    return if @started
    @control_block = block
    child_in = @out = @pid = nil
    FileUtils.mkdir_p(@chdir)
    with_full_path do
      @out, child_in, @pid = PTY.spawn(@env.stringify_keys, *interpolated_arguments, chdir: @chdir)
      child_in.close
    rescue Errno::ENOENT
      raise NotFound, "#{Shellwords.split(interpolated_arguments.first).first}: command not found"
    rescue Errno::EACCES
      raise Denied, "#{Shellwords.split(interpolated_arguments.first).first}: Permission denied"
    end
    @started = true
    # Return this object
    self
  end

  def stream(&block)
    start
    begin
      read_stream(@out, &block)
    rescue TimedOut => error
      @code = 'timeout'
      yield red("No output received in the last #{timeout} seconds.") + "\n"
      terminate!(&block)
      raise error
    rescue Errno::EIO # Somewhat expected on Linux: http://stackoverflow.com/a/10306782
    end

    _, status = Process.waitpid2(@pid)
    @code = status.exitstatus
    self
  end

  def red(text)
    "\033[1;31m#{text}\033[0m"
  end

  def stream!(&block)
    stream(&block)
    raise Failed.new(exit_message, code) unless success?
    self
  end

  def timed_out?
    @last_output_at ||= Time.now.to_i
    (@last_output_at + timeout) < Time.now.to_i
  end

  def touch_last_output_at
    @last_output_at = Time.now.to_i
  end

  def yield_control
    @control_block&.call
  end

  # rubocop:disable Lint/ShadowedException
  def read_stream(io)
    touch_last_output_at
    loop do
      yield_control
      yield io.read_nonblock(MAX_READ)
      touch_last_output_at
    rescue IO::WaitReadable, IO::EAGAINWaitReadable
      raise TimedOut if timed_out?
      IO.select([io], nil, nil, 1)
      retry
    end
  rescue EOFError
  end
  # rubocop:enable Lint/ShadowedException

  def terminate!(&block)
    kill_and_wait('INT', 5, &block) ||
      kill_and_wait('INT', 2, &block) ||
      kill_and_wait('TERM', 5, &block) ||
      kill_and_wait('TERM', 2, &block) ||
      kill('KILL', &block)
  rescue Errno::ECHILD, Errno::ESRCH
    true # much success
  ensure
    begin
      read_stream(@out, &block)
    rescue
    end
  end

  def kill_and_wait(sig, wait, &block)
    retry_count = 5
    kill(sig, &block)
    begin
      with_timeout(wait) do
        read_stream(@out, &block)
      end
    rescue TimedOut
    rescue Errno::EIO # EIO is somewhat expected on Linux: http://stackoverflow.com/a/10306782
      # If we try to read the stream right after sending a signal, we often get an Errno::EIO.
      if status = Process.wait(@pid, Process::WNOHANG)
        return status
      else
        # If we let the child a little bit of time, it solves it.
        retry_count -= 1
        if retry_count > 0
          sleep(0.05)
          retry
        end
      end
    end
    Process.wait(@pid, Process::WNOHANG)
  end

  def kill(sig)
    yield red("Sending SIG#{sig} to PID #{@pid}\n")
    Process.kill(sig, @pid)
  end

  def parse_arguments(arguments)
    options = {}
    args = arguments.flatten.map do |argument|
      case argument
      when Hash
        options.merge!(argument.values.first)
        argument.keys.first
      else
        argument
      end
    end
    return args, options
  end
end
