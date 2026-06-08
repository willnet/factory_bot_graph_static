# frozen_string_literal: true

require_relative "test_helper"

class GraphTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/factories.rb", __dir__)

  def setup
    parsed = FactoryBotGraph::Parser.new.parse_files([FIXTURE])
    @graph = FactoryBotGraph::Graph.new(parsed.factories, parsed.edges)
  end

  def test_renders_mermaid
    output = @graph.render(format: "mermaid")

    assert_includes output, "flowchart LR"
    assert_includes output, 'factory_post -->|"association"| factory_author'
    refute_includes output, 'factory_post -->|"create_list (trait: with_comments)"| factory_comment'
  end

  def test_can_include_trait_relations
    output = @graph.render(format: "mermaid", include_traits: true)

    assert_includes output, 'factory_post -->|"create_list (trait: with_comments)"| factory_comment'
  end

  def test_can_hide_trait_relations
    output = @graph.render(format: "mermaid", root: "post", include_traits: false)

    refute_includes output, "factory_comment"
    assert_includes output, "factory_account"
    assert_includes output, "factory_author"
  end

  def test_renders_dot
    output = @graph.render(format: "dot", root: "author")

    assert_includes output, "digraph factory_bot"
    assert_includes output, '"author" -> "account" [label="parent"]'
    refute_includes output, '"post";'
  end
end
