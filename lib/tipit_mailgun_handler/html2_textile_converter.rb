require 'html2textile'

module TipitMailgunHandler

  class Html2TextileConverter

    def to_textile
      temp_result = @parser.to_textile
      return temp_result if @image_map.nil?
      @image_map.each do |k, v|
        k = k.gsub("<", "cid:")
        k = k.gsub(">", "")
        temp_result = temp_result.gsub(k, v)
      end
      temp_result
    end

    private

    def initialize(html, image_map=nil)
      @image_map = image_map
      @parser = HTMLToTextileParser.new
      @parser.feed(html)
    end

  end

end