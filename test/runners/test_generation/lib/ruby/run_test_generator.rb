#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_generator'
require_relative 'schema_validator'

module RunTestGenerator
  module_function

  def process_args
    require 'optparse'

    options = { setup_shellspec: [], validate_file: false, validate_all: false, verified_files_path: nil }

    parser = OptionParser.new do |opts|
      opts.banner = usage_message
      opts.on('--verified-dir=VERIFIED_DIR', '--vd=VERIFIED_DIR', 'Verified files directory') do |verified_dir|
        options[:verified_files_path] = verified_dir
      end
      opts.on('--file-validate', '--fv', 'Validate the file instead of processing it') do
        options[:validate_file] = true
      end
      opts.on('--all-validate', '--av', 'Validate all files') do
        options[:validate_all] = true
      end
      opts.on('-s=SETUP', '--setup-shellspec=SETUP', 'Shellspec setup commands') do |setup|
        options[:setup_shellspec] << setup
      end
    end

    begin
      parser.parse!  # consumes recognized options from ARGV, leaves the rest
    rescue OptionParser::InvalidOption => e
      warn e.message
      warn parser
      return nil
    end

    if options[:validate_all]
      file = ''
    else
      file = ARGV.shift

      if file.nil?
        warn parser  # prints the banner + option summary to stderr
        return nil
      end
    end

    { file: file, validate_file: options[:validate_file], validate_all: options[:validate_all],
      setup_shellspec: options[:setup_shellspec], verified_files_path_option: options[:verified_files_path] }
  end

  def usage_message()
    <<~USAGE
      Usage: #{$PROGRAM_NAME} [--file-validate] <yaml_config_file> | --all-validate
    USAGE
  end

  def run
    options = process_args

    if options.nil?
      puts usage_message
      return 1
    end

    yaml_file = options[:file]

    # puts "options"
    # p options

    if options[:validate_all]
      SchemaValidator.new(PathConfig.yaml_schema_path).validate_all(PathConfig.test_specfiles_glob)
    elsif options[:validate_file]
      SchemaValidator.new(PathConfig.yaml_schema_path).validate_file(yaml_file)
    else
      ShellspecRunner.new(options[:setup_shellspec], yaml_file).generate_test(options[:verified_files_path_option])
    end
  end
end

# Script execution
RunTestGenerator.run if __FILE__ == $PROGRAM_NAME
