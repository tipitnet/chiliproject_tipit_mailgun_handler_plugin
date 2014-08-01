require 'rubygems'
require 'nokogiri'

module TipitMailgunHandler

  # This class is intended to convert html from emails to valid Textile. We are not covering
  # the complete Textile syntax, we only do minimal transformations to keep resulting Textile
  # as simple as possible.
  class TextileConverter

    MODIFIERS = {
        :b => '*',
        :strong => '*',
        :em => '_',
        :i => '_',
        :ins => '+',
        :u => '+',
        :span => '%',
        :del => '-',
        :cite => '??'
    }

    def to_textile
      @doc.css('body').children.to_s
    end

    private

    def initialize(html, image_map=nil)
      @image_map = image_map
      prepare_html_source(html)
      create_document(html)

      # Order is important here.
      process_paragraphs
      process_style_modifiers
      process_headers
      process_lists
      process_anchors
      process_brs
      process_spans
      process_html_spaces
      process_images
    end

    def process_images
      return if @image_map.nil?
      @doc.css("img").each do |node|
        image_cid = node['src']
        image_cid.gsub!(/cid:/,'')
        image_name = @image_map["<#{image_cid}>"]
        node.replace("!#{image_name}!")
      end

    end

    def prepare_html_source(html)
      # New lines are interpreted as spaces in HTML, so we transform new lines to spaces for Textile format.
      html.gsub!(/[\r\n]+/, ' ')

      # More than one space is omitted in HTML, so we remove all unneeded spaces for Textile format.
      html.gsub!(/[ ]+/, ' ')
    end

    def create_document(html)
      @doc = Nokogiri::HTML(html.strip)

      remove_title_if_present
    end

    def process_paragraphs
      # workaround for nested divs.
      @doc.css('div').each do |x|
        x.attributes.each_key { |k| x.remove_attribute(k)}
      end
      sorted = @doc.css('div').sort { |a, b| a.children.size <=> b.children.size }
      sorted.each do |node|
        text = node.children.to_s
        node.replace("#{text.strip}\n")
      end

      sorted = @doc.css('div').sort { |a, b| a.children.size <=> b.children.size }
      sorted.each do |node|
        text = node.children.to_s
        node.replace("#{text.strip}\n")
      end

      # workaround for nested p tags.
      @doc.css('p').sort { |a, b| a.children.size <=> b.children.size }.each do |node|
        text = node.children.to_s

        node.replace("#{text.strip}\n")
      end
    end

    # We are assuming that the style modifier is for the whole word. So this not support
    # styling parts of a word.
    def process_style_modifiers
      @doc.css('b', 'i', 'em', 'strong', 'ins', 'u', 'del', 'cite').each do |node|
        # We are getting the html of the children, we can't use {node.text} here
        # because we would be missing all the other html tags.
        text = node.children.to_s
        replacement_value = MODIFIERS[node.name.to_sym]

        node.replace(replacement_value + text.strip + replacement_value)
      end
    end

    def process_headers
      @doc.css('h1', 'h2', 'h3').each do |node|
        text = node.children.to_s

        node.replace("\n\n#{node.name}. " + text.strip + "\n\n")
      end
    end

    # For each root ul/ol we are going to process all children, and then replace the root ul/ol.
    def process_lists
      @doc.css('ul', 'ol').each do |list|

        # If we get a list (ol/ul) which is not a root, we stop processing.
        if list.ancestors('ul').count > 0 || list.ancestors('ol').count > 0
          return
        end

        textile_list = []

        list.css('li').each do |li|
          process_li(li, textile_list)
        end

        list.replace("\n\n" + textile_list.join("\n") + "\n\n")
      end
    end

    def process_li(li, lines)
      text = li.children.to_s

      ul_indentation_replacement = '#' * li.ancestors('ol').count
      ol_indentation_replacement = '*' * li.ancestors('ul').count

      replacement = ul_indentation_replacement.empty? ? ol_indentation_replacement : ul_indentation_replacement

      li_content = replacement + ' ' + text.strip
      lines << (li_content.gsub(li.children.css('ul', 'ol').to_s, '')).strip
    end

    #TODO: Add support for Link Aliases: http://redcloth.org/hobix.com/textile/ section 6.
    #TODO: What about link with span inside, we are not using the {text} variable here.
    def process_anchors
      @doc.css('a').each do |node|
        text = node.children.to_s

        node.replace("\"#{text.strip}\":#{node['href']}")
      end
    end

    def process_brs
      @doc.css("br").each do |node|
        node.replace("\n")
      end
    end

    def process_spans
      # Remove spans without styles
      @doc.css('span').sort { |a, b| a.children.size <=> b.children.size }.to_a.each do |node|

        unless node['style']
          text = node.children.to_s
          node.replace(text)
        end
      end

      # If we have nested spans with style attribute, we remove the children spans, textile doesn't support nested spans transformations.
      @doc.css('span').sort { |a, b| a.children.size <=> b.children.size }.to_a.each do |node|

        if node.ancestors('span').any? { |ancestor| ancestor['style'] }
          text = node.children.to_s
          node.replace(text)
        end
      end

      # process spans which have a style, for the others just remove the span tag.
      @doc.css('span').sort { |a, b| a.children.size <=> b.children.size }.to_a.each do |node|

        if node['style']
          text = node.children.to_s
          replacement_value = MODIFIERS[node.name.to_sym]

          trailing_whitespaces = text.match(/(\s+)$/)
          trailing_whitespaces = trailing_whitespaces ? trailing_whitespaces[0] : ''

          leading_whitespaces = text.match(/^(\s+)/)
          leading_whitespaces = leading_whitespaces ? leading_whitespaces[0] : ''

          textile_format = '{' + node['style'] + '}'

          unless text.strip.empty?
            node.replace(leading_whitespaces +
                             replacement_value +
                             textile_format +
                             text.strip +
                             replacement_value +
                             trailing_whitespaces
            )
          end
        else
          text = node.children.to_s
          node.replace(text)
        end
      end
    end

    def process_html_spaces
      # We want to avoid the creation of quoted blocks, so we remove spaces after new lines.
      new_fragment = @doc.to_html.gsub(/\n /, "\n")

      # note that we have an extra space after ";"
      new_fragment = new_fragment.gsub(/&(?:#xa0|#160|nbsp); /i, ' ')
      new_fragment = new_fragment.gsub(/&(?:#xa0|#160|nbsp);/i, ' ')

      @doc = Nokogiri::HTML(new_fragment)
    end

    # This should be in another class, we are not transforming to Textile, we are
    # just removing the title tag.
    def remove_title_if_present
      @doc.css('title').each { |node| node.remove }
    end

  end
end