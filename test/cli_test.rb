# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

class CLITest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/factories.rb", __dir__)

  def test_outputs_graph_for_a_root_factory
    stdout = StringIO.new
    stderr = StringIO.new

    status = FactoryBotGraph::CLI.new(stdout:, stderr:).run(["--factory", "author", "--format", "dot", FIXTURE])

    assert_equal 0, status
    assert_includes stdout.string, '"author" -> "account"'
    assert_empty stderr.string
  end

  def test_reports_missing_factory
    stderr = StringIO.new

    status = FactoryBotGraph::CLI.new(stdout: StringIO.new, stderr:).run(["--factory", "missing", FIXTURE])

    assert_equal 1, status
    assert_includes stderr.string, "Factory not found: missing"
  end

  def test_omits_trait_relations_by_default
    stdout = StringIO.new
    stderr = StringIO.new

    status = FactoryBotGraph::CLI.new(stdout:, stderr:).run([FIXTURE])

    assert_equal 0, status
    refute_includes stdout.string, "trait: with_comments"
    assert_empty stderr.string
  end

  def test_can_include_trait_relations
    stdout = StringIO.new
    stderr = StringIO.new

    status = FactoryBotGraph::CLI.new(stdout:, stderr:).run(["--traits", FIXTURE])

    assert_equal 0, status
    assert_includes stdout.string, "trait: with_comments"
    assert_empty stderr.string
  end

  def test_uses_spec_factories_by_default
    stdout = StringIO.new
    stderr = StringIO.new

    Dir.mktmpdir do |directory|
      factories = File.join(directory, "spec", "factories")
      FileUtils.mkdir_p(factories)
      FileUtils.cp(FIXTURE, File.join(factories, "factories.rb"))

      Dir.chdir(directory) do
        status = FactoryBotGraph::CLI.new(stdout:, stderr:).run([])

        assert_equal 0, status
      end
    end

    assert_includes stdout.string, 'factory_post["post"]'
    assert_empty stderr.string
  end
end
