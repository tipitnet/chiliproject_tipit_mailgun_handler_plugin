require File.expand_path('../../test_helper', __FILE__)

class TextileConverterTest < ActiveSupport::TestCase

  def test_bold
    assert_textile '*bold*', '<b>bold</b>'
  end

  def test_bold_with_spaces
    assert_textile '*b o l d*',
                   '   <b>   b  o  l   d    </b>            '
  end

  def test_bold_with_new_lines_inside
    assert_textile '*b o l d*',
                   '<b> b  o
    l d
</b>'
  end

  def test_italic
    assert_textile '_italic_',
                   '<i>italic</i>'
  end

  def test_italic_with_spaces
    assert_textile '_i t a l i c_',
                   '<i>  i  t  a  l i c</i>'
  end

  def test_heading
    assert_textile "\n\nh1. Heading 1\n\n",
                   '<h1>Heading 1</h1>'

    assert_textile "\n\nh2. Heading 2\n\n",
                   '<h2>Heading 2</h2>'

    assert_textile "\n\nh3. Heading 3\n\n",
                   '<h3>Heading 3</h3>'
  end

  def test_heading_with_color
    assert_textile "\n\nh1. Hello %{color: red}world%\n\n",
                   '<h1>Hello <span style="color: red">world</span></h1>'
  end

  def test_heading_with_spaces
    assert_textile "\n\nh1. Th is is a headi ng\n\n",
                   '<h1>  Th
     is is a headi  ng           </h1>'
  end

  def test_span_with_style
    assert_textile "I'm %{color:red;}unaware% of most soft drinks.\n",
                   '<p>I\'m <span style="color:red;">unaware</span> of most soft drinks.</p>'
  end

  def test_span_style_inside_bold
    assert_textile '*This is bold %{color: indianred}but this is red and bold!%*',
                   '<b>This is bold <span style="color: indianred">but this is red and bold!</span>    </b>'
  end

  def test_span_with_new_lines
    assert_textile "\n%{font-weight: bold;}Testing some bold%\n\n",
                   '<span style="font-weight: bold;">Testing some bold<br><br></span>'
  end

  # We are transforming new lines in html to spaces in textile, so in this case
  # we will end up with one more space before "un a ware" and one more space
  # after "un a ware" because we have newlines before and after "un a ware".
  # Textile rendering will omit these "new" spaces.
  def test_span_whitespaces
    assert_textile "I'm  %{color:red;}un a ware%  of most soft drinks.\n",
                   '<p>I\'m <span
        style="color:red;">
    un a
    ware
</span>
    of most soft drinks.</p>'
  end

  def test_span_with_style_and_spaces
    assert_textile "Standard%{font-style: italic;}italics% and\n",
                   "Standard<span style=\"font-style: italic;\">italics </span>and"

    assert_textile "Standard %{font-style: italic;}italics% and\n",
                   "Standard<span style=\"font-style: italic;\"> italics</span> and"

    assert_textile "Standard %{font-style: italic;}italics% and\n",
                   "Standard <span style=\"font-style: italic;\">italics</span> and"

    assert_textile "Standard %{font-style: italic;}italics% and\n",
                   "Standard<span style=\"font-style: italic;\"> italics </span>and"
  end

  def test_clean_span_without_style
    assert_textile "test\n\n\n%{font-weight: bold;}Testing some bold%\n\ntest",
                   "<span>test<br><br><span style=\"font-weight: bold;\">Testing some bold<br><br></span></span>test"
  end

  def test_clean_nested_span_if_parent_span_has_style
    assert_textile "This is %{font-style: italic;}a nested span test%\n",
                   "This is <span style=\"font-style: italic;\">a nested <span style=\"font-weight: bold;\">span test</span></span>"
  end

  def test_clean_non_styled_parent_span_if_child_span_has_style
    assert_textile "This is a nested %{font-weight: bold;}span test%\n",
                   "This is <span>a nested <span style=\"font-weight: bold;\">span test</span></span>"
  end

  def test_clean_all_spans_if_none_have_styles
    assert_textile "This is a nested span test\n",
                   "This is <span>a nested <span>span test</span></span>"
  end

  def test_link
    assert_textile '"Google":http://google.com',
                   '<a href="http://google.com">Google</a>'
  end

  def test_link_inside_p
    assert_textile "I searched \"Google\":http://google.com.\n",
                   '<p>I searched <a href="http://google.com">Google</a>.</p>'
  end


  def test_link_with_span_inside
    assert_textile "\"This is a link with a span %{color: red}in red%\":http://localhost:3000",
                   "<a href=\"http://localhost:3000\">This is a link with a span <span style=\"color: red\">in red</span></a>"
  end

  # TODO: This should be in another class, we are not transforming to Textile, we are
  # just removing the title tag.
  def test_remove_title_tag
    assert_textile '', '<title>this is the title</title>'
  end

  def test_simple_bulleted_list
    assert_textile '

* A first item
* A third

',
                   '<ul><li>A first item</li><li>A third</li></ul>'

  end

  def test_simple_bulleted_list_with_space
    assert_textile '

* A f irst item
* A third

',
                   '<ul><li>A f


    irst item</li><li>A

    third</li></ul>
'
  end


  def test_simple_numeric_list
    assert_textile '

# A first item
# A third

',
                   '<ol><li>A first item</li><li>A third</li></ol>'
  end

  def test_simple_numeric_list_with_style
    assert_textile '

# A first %{color:red}item%
# A third

',
                   '<ol><li>A first <span style="color:red">item</span></li><li>A third</li></ol>'
  end

  def test_numeric_nested_list
    assert_textile '

* Fuel could be:
** Coal
** Electricity
* Humans need only:
** Water
** Protein

',
                   '
<ul><li>Fuel could be:
<ul>
<li>Coal
</li>
<li>Electricity</li>
</ul>
</li>
<li>Humans need only:
<ul>
<li>Water</li>
<li>Protein</li>
</ul></li>
</ul>
'
  end

  def test_bulleted_nested_list
    assert_textile '

# Fuel could be:
## Coal
## Electricity
# Humans need only:
## Water
## Protein

',
                   '
<ol>
<li>Fuel could be:
<ol>
<li>Coal</li>
<li>Electricity</li>
</ol>
</li>
<li>Humans need only:
<ol>
<li>Water</li>
<li>Protein</li>
</ol></li>
</ol>'
  end

  def test_spaces
    assert_textile "  hello  world\n",
                   '<p>
    &nbsp;&nbsp;hello&nbsp;&nbsp;world
    </p>'
  end


  def test_convert_html_space_to_textile_space
    assert_textile "with. Why\n",
                   '<p>with.&nbsp; Why </p>'
  end

  def test_p
    assert_textile 'A single paragraph.
Followed by another.
',
                   '<p>A single paragraph.</p>

                <p>Followed by another.</p>
'
  end

  def test_div
    assert_textile 'A single paragraph.
Followed by another.
',
                   '<div>A single paragraph.</div>

                <div>Followed by another.</div>
'
  end

  def test_no_space_after_new_line
    assert_textile "\na line", '<br>     a line'
  end

  def test_space_after_new_line_if_html_space
    assert_textile "\n   a line", '<br>
&nbsp;&nbsp;&nbsp;a line'
  end

  def test_no_space_after_new_p
    assert_textile "p\nNo leading spaces", '<p>p</p>
No leading spaces'
  end

  def test_no_space_after_new_div
    assert_textile "div\nNo leading spaces", '<div>div</div>
No leading spaces'
  end

  def test_no_space_after_new_line_for_h1
    assert_textile "\n\n\nh1. Heading\n\n", '<br><h1>
Heading</h1>'
  end

  # In order to show lists properly, we are adding two new lines after and before the lines.
  def test_new_lists_must_be_preceded_by_a_blank_line
    assert_textile '

* item1



# item1

',
                   '<ul><li>item1</li></ul><ol><li>item1</li></ol>'
  end

  def test_hr
    assert_textile "\n",'<hr>'
  end

  # We are changing newlines in the original HTML to spaces, so in this particular case a space will be added
  # for the content of the span. More analysis should be made to see if we really want this behaviour for all the cases.
  def test_new_line_at_span_start
    assert_textile " test",
                   "<span>
test</span>"
  end

  def test_image
    expected = "!image1.png!"
    image_map = { "<ii_1477855169c39137>" => 'image1.png' }
    actual = "<img src=\"cid:ii_1477855169c39137\" />"
    converter = TipitMailgunHandler::TextileConverter.new(actual, image_map)
    assert_equal expected, converter.to_textile
  end

  def test_div_plus_image
    input = "<div dir=\"ltr\"><div class=\"gmail_default\" style=\"font-family:arial,helvetica,sans-serif\"><br></div><div class=\"gmail_quote\"><br><div dir=\"ltr\"><div style=\"font-family:arial,helvetica,sans-serif\">plain text</div><div style=\"font-family:arial,helvetica,sans-serif\"> <img src=\"cid:ii_1477f9531e1536e7\" alt=\"Inline image 1\" width=\"454\" height=\"250\"><br> </div></div> </div><br></div>"
    image_map = { "<ii_1477f9531e1536e7>" => 'image1.png' }
    converter = TipitMailgunHandler::TextileConverter.new(input, image_map)
    actual = converter.to_textile
    expected = "\nplain text\n!image1.png!\n\n\n"
    assert_equal expected, actual
  end

  def test_clean_div_plus_image
    input = "<div><div><br></div><div><br><div><div>plain text</div><div><img src=\"cid:ii_1477f9531e1536e7\"><br> </div></div> </div><br></div>"
    image_map = { "<ii_1477f9531e1536e7>" => 'image1.png' }
    converter = TipitMailgunHandler::TextileConverter.new(input, image_map)
    actual = converter.to_textile
    expected = "\n\nplain text\n!image1.png!"
    assert_equal expected, actual
  end


  private

  def assert_textile(expected, actual)
    converter = TipitMailgunHandler::TextileConverter.new(actual)
    assert_equal expected, converter.to_textile
  end
end