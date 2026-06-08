# frozen_string_literal: true

require "set"

module FactoryBotGraph
  class Graph
    def initialize(factories, edges)
      @factories = factories
      @edges = edges
    end

    def render(format:, root: nil, include_traits: false)
      edges = selected_edges(root, include_traits)
      nodes = selected_nodes(root, edges)

      case format
      when "mermaid" then render_mermaid(nodes, edges)
      when "dot" then render_dot(nodes, edges)
      else raise ArgumentError, "Unsupported format: #{format}"
      end
    end

    private

    def selected_edges(root, include_traits)
      edges = include_traits ? @edges : @edges.reject(&:trait)
      return edges unless root

      unless @factories.key?(root)
        raise ArgumentError, "Factory not found: #{root}"
      end

      reachable = Set[root]
      loop do
        added = edges.select { |edge| reachable.include?(edge.source) }
          .map(&:target)
          .reject { |target| reachable.include?(target) }
        break if added.empty?

        reachable.merge(added)
      end
      edges.select { |edge| reachable.include?(edge.source) }
    end

    def selected_nodes(root, edges)
      return @factories.keys.sort unless root

      ([root] + edges.flat_map { |edge| [edge.source, edge.target] }).uniq.sort
    end

    def render_mermaid(nodes, edges)
      lines = ["flowchart LR"]
      nodes.each { |node| lines << "  #{node_id(node)}[\"#{escape(node)}\"]" }
      edges.each do |edge|
        lines << "  #{node_id(edge.source)} -->|\"#{escape(edge_label(edge))}\"| #{node_id(edge.target)}"
      end
      lines.join("\n") + "\n"
    end

    def render_dot(nodes, edges)
      lines = ["digraph factory_bot {", "  rankdir=LR;"]
      nodes.each { |node| lines << %(  "#{escape(node)}";) }
      edges.each do |edge|
        lines << %(  "#{escape(edge.source)}" -> "#{escape(edge.target)}" [label="#{escape(edge_label(edge))}"];)
      end
      lines << "}"
      lines.join("\n") + "\n"
    end

    def edge_label(edge)
      edge.trait ? "#{edge.kind} (trait: #{edge.trait})" : edge.kind
    end

    def node_id(name)
      "factory_#{name.gsub(/[^a-zA-Z0-9_]/, "_")}"
    end

    def escape(value)
      value.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
    end
  end
end
