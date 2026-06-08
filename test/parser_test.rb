# frozen_string_literal: true

require_relative "test_helper"

class ParserTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/factories.rb", __dir__)

  def setup
    @parser = FactoryBotGraph::Parser.new.parse_files([FIXTURE])
  end

  def test_finds_factories
    assert_equal %w[account author comment post], @parser.factories.keys.sort
  end

  def test_finds_association_trait_and_parent_relations
    relations = @parser.edges.map { |edge| [edge.source, edge.target, edge.kind, edge.trait] }

    assert_includes relations, ["author", "account", "parent", nil]
    assert_includes relations, ["post", "author", "association", nil]
    assert_includes relations, ["post", "account", "association", nil]
    assert_includes relations, ["post", "comment", "create_list", "with_comments"]
    assert_includes relations, ["comment", "post", "association", nil]
  end

  def test_deduplicates_associations_between_the_same_factories
    association_relations = @parser.edges.select do |edge|
      edge.source == "post" &&
        edge.target == "account" &&
        edge.kind == "association" &&
        edge.trait.nil?
    end

    assert_equal 1, association_relations.size
  end
end
