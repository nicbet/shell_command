# ShellCommand

ShellCommand allows execution of system commands with streaming I/O, timeouts, and environemnt variable interpolation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shell_command', github: 'nicbet/shell_command'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install shell_command

## Usage

To run a shell command with default timeout of 5 minutes:

```ruby
output = ShellCommand.new('echo Hello World', chdir: __dir__).run
```

To stream output from a long running shell command we can do:

```ruby
cmd = ShellCommand.new('docker build -t hello/world .', chdir: __dir__)

cmd.stream! do |chunk|
    puts chunk
end
```

We can also pass optional arguments to the command string:

``` ruby
cmd = ShellCommand.new('docker build -t hello/world .' => {'timeout' => 30}, chdir: __dir__).run!
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/shell_command. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/shell_command/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ShellCommand project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/shell_command/blob/master/CODE_OF_CONDUCT.md).

## Thanks

Shopify's [Shipit Engine](https://github.com/Shopify/shipit-engine) for the original version under MIT license.