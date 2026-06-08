# frozen_string_literal: true

require "prism"

module FactoryBotGraph
  Factory = Struct.new(:name, :file, :line)
  Edge = Struct.new(:source, :target, :kind, :trait, :file, :line)

  class Parser
    EXPLICIT_RELATIONS = %w[
      association association_list association_list_strategy
      build build_list build_stubbed build_stubbed_list
      create create_list attributes_for attributes_for_list
    ].freeze
    IGNORED_BARE_CALLS = %w[
      after before callback evaluator factory initialize_with skip_create
      to_create trait transient
    ].freeze

    attr_reader :factories, :edges

    def initialize
      @factories = {}
      @edges = []
      @implicit_relations = []
    end

    def parse_files(files)
      files.each { |file| parse_file(file) }
      resolve_implicit_relations
      self
    end

    private

    Context = Struct.new(:factory, :trait)

    def parse_file(file)
      result = Prism.parse(File.read(file))
      raise SyntaxError, "Could not parse #{file}" unless result.success?

      visit(result.value, Context.new(nil, nil), file)
    end

    def visit(node, context, file)
      return unless node

      if node.is_a?(Prism::CallNode)
        visit_call(node, context, file)
      else
        node.child_nodes.each { |child| visit(child, context, file) }
      end
    end

    def visit_call(node, context, file)
      if node.name == :factory
        name = symbol_value(arguments(node).first)
        return unless name

        record_factory(node, file)
        visit(node.block, Context.new(name, nil), file)
      elsif node.name == :trait && context.factory
        visit(node.block, Context.new(context.factory, symbol_value(arguments(node).first)), file)
      else
        record_relation(node, context, file)
        node.child_nodes.each { |child| visit(child, context, file) }
      end
    end

    def record_factory(node, file)
      name = symbol_value(arguments(node).first)
      return unless name

      @factories[name] = Factory.new(name, file, node.location.start_line)
      record_parent(name, node, file)
    end

    def record_parent(factory, node, file)
      parent = keyword_symbol(arguments(node), :parent)
      add_edge(factory, parent, "parent", nil, file, node.location.start_line) if parent
    end

    def record_relation(node, context, file)
      return unless context.factory

      name = node.name.to_s

      if name == "association"
        target = keyword_symbol(arguments(node), :factory) || symbol_value(arguments(node).first)
        add_edge(context.factory, target, name, context.trait, file, node.location.start_line) if target
      elsif EXPLICIT_RELATIONS.include?(name)
        target = symbol_value(arguments(node).first)
        add_edge(context.factory, target, name, context.trait, file, node.location.start_line) if target
      elsif bare_call?(node) && !IGNORED_BARE_CALLS.include?(name)
        @implicit_relations << [context.factory, name, context.trait, file, node.location.start_line]
      end
    end

    def resolve_implicit_relations
      seen = {}
      @implicit_relations.each do |source, target, trait, file, line|
        next unless factories.key?(target)

        key = [source, target, trait]
        next if seen[key]

        seen[key] = true
        add_edge(source, target, "association", trait, file, line)
      end
      deduplicate_edges
    end

    def add_edge(source, target, kind, trait, file, line)
      @edges << Edge.new(source, target, kind, trait, file, line)
    end

    def deduplicate_edges
      seen = {}
      @edges = @edges.each_with_object([]) do |edge, deduplicated|
        key = [edge.source, edge.target, edge.kind, edge.trait]
        next if seen[key]

        seen[key] = true
        deduplicated << edge
      end
    end

    def bare_call?(node)
      node.receiver.nil? && node.arguments.nil?
    end

    def arguments(node)
      node.arguments&.arguments || []
    end

    def symbol_value(node)
      return unless node.is_a?(Prism::SymbolNode)

      node.unescaped
    end

    def keyword_symbol(args, keyword)
      hash = args.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
      pair = hash&.elements&.find { |entry| symbol_value(entry.key) == keyword.to_s }
      symbol_value(pair&.value)
    end
  end
end
