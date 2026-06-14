# frozen_string_literal: true

require_relative 'sys_exec'
require_relative 'test_generator'

class ShellspecRunner
  TIMEOUT_SECONDS = 120

  attr_reader :setup_cmds, :yaml_test_def_path

  def initialize(setup_cmds, yaml_test_def_path)
    cmds_with_env = []
    setup_cmds.each do |cmd|
      cmds_with_env << ". #{PathConfig.test_env_setup_path} && #{cmd}"
    end
    @setup_cmds = cmds_with_env
    @yaml_test_def_path = yaml_test_def_path
  end

  def generate_test(verified_files_dir_option = nil)
    return false unless prepare_test_env

    generator = TestGenerator.new(yaml_test_def_path)

    success = generator.generate_shellspec_test
    return false unless success

    return false unless prepare_test_env

    generator.verify_final_specfile(verified_files_dir_option)
  end

  private

  def prepare_test_env
    return true unless setup_cmds.length.positive?

    puts 'Shellspec setup commands:'
    setup_cmds.each do |cmd|
      puts cmd
    end

    result = SysExec.run_all(setup_cmds, timeout: TIMEOUT_SECONDS)
    puts "Shellspec setup completed  #{result.exit_status.zero? ? 'successfully' : 'with errors'}"
    result.exit_status.zero?
  end

end
