# frozen_string_literal: true

require "optparse"

module FactoryBotGraph
  class CLI
    DEFAULT_PATHS = %w[spec/factories test/factories].freeze

    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      options = { format: "mermaid", include_traits: false }
      parser = option_parser(options)
      paths = parser.parse(argv)
      files = ruby_files(paths.empty? ? DEFAULT_PATHS : paths)
      raise ArgumentError, "No factory files found" if files.empty?

      parsed = Parser.new.parse_files(files)
      graph = Graph.new(parsed.factories, parsed.edges)
      @stdout.write(graph.render(**options))
      0
    rescue ArgumentError, OptionParser::ParseError, SyntaxError => error
      @stderr.puts("factory_bot_graph: #{error.message}")
      1
    end

    private

    def option_parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: factory_bot_graph [options] [file_or_directory ...]"
        opts.on("-f", "--format FORMAT", %w[mermaid dot], "Output format: mermaid or dot") { |value| options[:format] = value }
        opts.on("-r", "--factory NAME", "Only render dependencies reachable from a factory") { |value| options[:root] = value }
        opts.on("--[no-]traits", "Include relationships declared in traits (default: false)") { |value| options[:include_traits] = value }
        opts.on("-h", "--help", "Show this help") do
          @stdout.puts(opts)
          exit 0
        end
      end
    end

    def ruby_files(paths)
      paths.flat_map do |path|
        if File.directory?(path)
          Dir[File.join(path, "**", "*.rb")]
        elsif File.file?(path)
          path
        else
          []
        end
      end.uniq.sort
    end
  end
end
