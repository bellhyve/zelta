# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../run_test_generator'

class RunTestGeneratorTest < Minitest::Test
  def setup
    @original_argv = ARGV.dup
    @original_program_name = $PROGRAM_NAME
    @existing_yaml_file = '/tmp/some.yaml'

  end

  def teardown
    ARGV.replace(@original_argv)
    $PROGRAM_NAME = @original_program_name
  end

  # ---------------------------------------------------------------------------
  # process_args — option parsing
  # ---------------------------------------------------------------------------

  def test_process_args_returns_nil_without_file
    ARGV.replace([])
    assert_nil RunTestGenerator.process_args
  end

  def test_process_args_returns_nil_for_invalid_option
    ARGV.replace(['--bogus-flag'])
    assert_nil RunTestGenerator.process_args
  end

  def test_process_args_with_yaml_file_only
    yaml_file = 'some.yaml'
    ARGV.replace([yaml_file])
    result = RunTestGenerator.process_args
    assert_equal yaml_file, result[:file]
    refute result[:validate_file]
    refute result[:validate_all]
    assert_equal [], result[:setup_shellspec]
    assert_nil result[:verified_files_path_option]
  end

  def test_process_args_with_file_validate_long_form
    ARGV.replace(['--file-validate', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal 'some.yaml', result[:file]
    assert result[:validate_file]
  end

  def test_process_args_with_file_validate_short_form
    ARGV.replace(['--fv', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert result[:validate_file]
  end

  def test_process_args_with_all_validate_long_form
    ARGV.replace(['--all-validate'])
    result = RunTestGenerator.process_args
    assert result[:validate_all]
    assert_equal '', result[:file]
  end

  def test_process_args_with_all_validate_short_form
    ARGV.replace(['--av'])
    result = RunTestGenerator.process_args
    assert result[:validate_all]
    assert_equal '', result[:file]
  end

  def test_process_args_with_verified_dir_long_form
    ARGV.replace(['--verified-dir=/tmp/verified', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal '/tmp/verified', result[:verified_files_path_option]
  end

  def test_process_args_with_verified_dir_short_form
    ARGV.replace(['--vd=/tmp/verified', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal '/tmp/verified', result[:verified_files_path_option]
  end

  def test_process_args_with_single_setup_shellspec
    ARGV.replace(['-s=cmd1', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal ['cmd1'], result[:setup_shellspec]
  end

  def test_process_args_with_setup_shellspec_long_form
    ARGV.replace(['--setup-shellspec=cmd1', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal ['cmd1'], result[:setup_shellspec]
  end

  def test_process_args_accumulates_multiple_setup_shellspec
    ARGV.replace(['-s=cmd1', '-s=cmd2', '--setup-shellspec=cmd3', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal %w[cmd1 cmd2 cmd3], result[:setup_shellspec]
  end

  def test_process_args_combines_all_options
    ARGV.replace(['--fv', '-s=cmd1', '--vd=/tmp/v', 'some.yaml'])
    result = RunTestGenerator.process_args
    assert_equal 'some.yaml', result[:file]
    assert result[:validate_file]
    assert_equal ['cmd1'], result[:setup_shellspec]
    assert_equal '/tmp/v', result[:verified_files_path_option]
  end

  def test_process_args_ignores_trailing_args_after_file
    ARGV.replace(['some.yaml', 'extra'])
    result = RunTestGenerator.process_args
    assert_equal 'some.yaml', result[:file]
  end

  # ---------------------------------------------------------------------------
  # usage_message
  # ---------------------------------------------------------------------------

  def test_usage_message_includes_program_name
    $PROGRAM_NAME = '/path/to/run_test_generator.rb'
    assert_match(/run_test_generator\.rb/, RunTestGenerator.usage_message)
  end

  def test_usage_message_lists_file_validate_option
    assert_match(/--file-validate|--fv/, RunTestGenerator.usage_message)
  end

  # ---------------------------------------------------------------------------
  # run — dispatches to validators and shellspec runner
  # ---------------------------------------------------------------------------

  def test_run_validates_all_when_av_flag_given
    ARGV.replace(['--all-validate'])
    PathConfig.stubs(:yaml_schema_path).returns('/fake/schema.yml')
    PathConfig.stubs(:test_specfiles_glob).returns('/fake/**/*.yaml')

    SchemaValidator.any_instance.expects(:validate_all).with('/fake/**/*.yaml').returns(true)
    RunTestGenerator.run
  end

  def test_run_validates_file_only_when_fv_flag_given
    ARGV.replace(['--file-validate', 'some.yaml'])
    PathConfig.stubs(:yaml_schema_path).returns('/fake/schema.yml')

    SchemaValidator.any_instance.expects(:validate_file).with('some.yaml').returns(true)
    ShellspecRunner.any_instance.expects(:generate_test).never
    RunTestGenerator.run
  end

  def test_run_validates_then_generates_test_for_yaml_file
    ARGV.replace(['some.yaml'])
    PathConfig.stubs(:yaml_schema_path).returns('/fake/schema.yml')

    SchemaValidator.any_instance.expects(:validate_file).with('some.yaml').returns(true)
    ShellspecRunner.any_instance.expects(:generate_test).with(nil).returns(true)
    RunTestGenerator.run
  end

  def test_run_passes_verified_dir_to_shellspec_runner
    ARGV.replace(['--vd=/tmp/verified', 'some.yaml'])
    PathConfig.stubs(:yaml_schema_path).returns('/fake/schema.yml')

    SchemaValidator.any_instance.expects(:validate_file).returns(true)
    ShellspecRunner.any_instance.expects(:generate_test).with('/tmp/verified').returns(true)
    RunTestGenerator.run
  end

  def test_run_passes_setup_shellspec_to_shellspec_runner_constructor
    ARGV.replace(['-s=cmd1', '-s=cmd2', 'some.yaml'])
    PathConfig.stubs(:yaml_schema_path).returns('/fake/schema.yml')

    SchemaValidator.any_instance.expects(:validate_file).returns(true)
    runner = mock('shellspec_runner')
    runner.expects(:generate_test).with(nil).returns(true)
    ShellspecRunner.expects(:new).with(%w[cmd1 cmd2], 'some.yaml').returns(runner)

    RunTestGenerator.run
  end

  # NOTE: run_test_generator.rb:64 calls `options.usage` when `options` is nil,
  # which raises NoMethodError before the intended `return 1`. This test
  # documents that bug; once fixed, change to `assert_equal 1, ...`.
  def test_run_crashes_when_no_arguments_given_documents_bug
    ARGV.replace([])
    assert_raises(NoMethodError) { RunTestGenerator.run }
  end
end
