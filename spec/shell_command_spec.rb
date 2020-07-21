RSpec.describe ShellCommand do
  it "has a version number" do
    expect(ShellCommand::VERSION).not_to be nil
  end

  it "can execute a simple shell command" do
    cmd = ShellCommand.new('echo "Hello World!"', chdir: ".")
    output = cmd.run!

    expect(output.strip).to eq "Hello World!"
  end

  it "streams the output from a shell command" do
    output = []
    cmd = ShellCommand.new('echo "Hello World!\nHow nice that you are here!"', chdir: ".")
    cmd.stream! do |block|
      output << block
    end

    expect(output.join).to eq "Hello World!\r\nHow nice that you are here!\r\n"
  end

  it "succeeds with exit code 0" do
    cmd = ShellCommand.new('echo "Hello World!"', chdir: ".")
    cmd.run!

    expect(cmd.code).to eq 0
    expect(cmd.success?).to be true
  end

  it "fails with exit code 1 if the command cannot run properly" do
    cmd = ShellCommand.new('ps .', chdir: ".")
    cmd.run

    expect(cmd.code).to eq 1
  end

  it "fails with exit code 127 if command does not exist" do
    cmd = ShellCommand.new('doesnotexist "Hello World!"', chdir: ".")
    cmd.run

    expect(cmd.code).to eq 127
  end

  it "raises a TimedOut error when called with run!" do
    cmd = ShellCommand.new('sleep 5 && echo "Hello"', default_timeout: 1, chdir: ".")
    expect { cmd.run! }.to raise_error(ShellCommand::TimedOut)
  end

  it "gracefully handles TimeOut error when called with run" do
    cmd = ShellCommand.new('sleep 5 && echo "Hello"', default_timeout: 1, chdir: ".")
    cmd.run

    expect(cmd.success?).to be false
    expect(cmd.code).to eq 'timeout'
  end
end
