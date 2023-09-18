# frozen_string_literal: true

require 'better_html'
require 'better_html/parser'
require 'better_html/tree/tag'

module WERB
  # Stack Frame Class
  class Frame
    attr_reader :name, :elems

    def initialize(name)
      @name = name
      @elems = []
    end

    def push!(elem)
      @elems = @elems << elem
      nil
    end
  end

  # Compile ERB into ruby.wasm compatible code
  class Transpiler
    def initialize(source, root_elem_name = 'document')
      @counter = 0
      @parser = create_parser(source)
      @root_elem_name = root_elem_name
      @frames = [Frame.new(@root_elem_name)]
    end

    def transpile
      transpile_ast(@parser.ast)[1]
    end

    private

    def current_frame
      frame = @frames.last
      raise StandardError, 'No Frames' if frame.nil?

      frame
    end

    def create_parser(source)
      buffer = Parser::Source::Buffer.new('(buffer)', source:)
      BetterHtml::Parser.new(buffer)
    end

    def collect_result
      frame = @frames.pop
      raise StandardError, 'No frames to pop' if frame.nil?

      frame.elems.reduce('') do |acc, elem|
        case elem
        in [:string | :erb | :container, content]
          "#{acc}#{content}"
        in [el_name, content]
          "#{acc}#{content}#{current_frame.name}.appendChild(#{el_name})\n"
        else
          raise StandardError, "\n#{elem} cannot be parsed.\nCurrent frame: #{self}"
        end
      end
    end

    def transpile_ast(node)
      return [:string, add_to_inner_html(node)] if node.is_a?(String)

      case node.type
      when :tag
        transpile_tag(node)
      when :text, :document
        transpile_container(node)
      when :erb
        transpile_erb(node)
      when :code
        [:code, "#{unpack_code(node)}\n"]
      else
        raise StandardError, 'Failed to transpile'
      end
    end

    def add_new_frame!(name)
      @frames = @frames << Frame.new(name)
      nil
    end

    def generate_el_name
      @counter += 1
      "@el#{@counter}"
    end

    def transpile_erb(erb)
      case erb.children
      in [nil, _, code, _]
        add_new_frame!(generate_el_name)
        erb.children.filter { |i| !i.nil? }.each do |n|
          transpiled = transpile_ast(n)
          current_frame.push!(transpiled)
        end
        [:container, collect_result]
      in [_indicator, _, code, _]
        [:erb, add_to_inner_html("\#{#{unpack_code(code)}}")]
      else
        raise StandardError
      end
    end

    def transpile_container(node)
      add_new_frame!(current_frame.name)
      node.children.each do |n|
        transpiled = transpile_ast(n)
        current_frame.push!(transpiled)
      end
      [:container, collect_result]
    end

    def transpile_tag(node)
      tag = BetterHtml::Tree::Tag.from_node(node)
      if tag.closing?
        [:container, collect_result]
      else
        el_name = generate_el_name
        add_new_frame!(el_name)
        [el_name, "#{el_name} = #{@root_elem_name}.createElement('#{tag.name}')\n"]
      end
    end

    def unpack_code(block)
      block.children[0].strip
    end

    def add_to_inner_html(elem)
      "#{current_frame.name}[:innerHTML] += \"#{elem}\"\n"
    end
  end
end