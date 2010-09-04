require 'parse'
require 'test/unit'

class TestWinaml < Test::Unit::TestCase
  def test_calc
    assert_equal("8", Winaml.new.test('#{5+3}'))
    assert_equal("5", Winaml.new.test('#{5-3+3}'))
  end
  
  def test_variable
    assert_equal("13", Winaml.new.test('<<var=5+8>#{var}'))
    assert_equal("14", Winaml.new.test('<<var=6+8><<var2=var>#{var2}'))
    assert_equal("13", Winaml.new.test('<<var=5+8><<var2=3>#{var}'))
    assert_equal("", Winaml.new.test('#{var2}'))
    
    # Testing special variables.
    assert_equal("13", Winaml.new.test('<<@title=5+8>#{@title}'))
  end
  
  def test_condition
    assert_equal("23", Winaml.new.test('<<if 5 < 6>#{23}<<endif>'))
    assert_equal("", Winaml.new.test('<<if 5 > 6>#{23}<<endif>'))
    assert_equal("1337", Winaml.new.test('<<var1=1337><<if var1 == 1><<var1 = 50><<endif>#{var1}'))
    assert_equal("2233", Winaml.new.test('
<<var1 = 3>
<<if 3+6 < var1>
	<<var1 = 5>
	#{11}
<<else> 
	#{22}
		<<if var1 and var1 == 3> 
		#{33}
	<<endif>
<<endif>'))
  end
  
  def test_text
    assert_equal("\t<p>hej</p>\r\n", Winaml.new.test('<text>hej<>'))
    assert_equal("\t<p>hej 3 42</p>\r\n", Winaml.new.test('<<var1 = 3><text>hej #{var1} #{45-3}<>'))
    
    assert_equal("\t<p>hej doe</p>\r\n", Winaml.new.test('<<var1 = "\'hej\'"><<var2 = "\'doe\'"><text>#{var1} #{var2}<>'))
    # Testing concating two strings.
    assert_equal("\t<p>hejdoe!!!</p>\r\n", Winaml.new.test('<<var1 = "\'hej\'"><<var2 = "\'doe\'"><text>#{var1+var2}!!!<>'))
    # Testing escaping characters to HTML code.
    assert_equal("\t<p>&lt;bla&gt;</p>\r\n", Winaml.new.test('<text>\<bla\><>'))
    assert_equal("\t<p>w  &lt;  bla&gt;</p>\r\n\t<p>w  &lt;  bla&gt;</p>\r\n", 
                 Winaml.new.test('<text>w  \<  bla\><><text>w  \<  bla\><>'))
    
    assert_equal("\t<p>hejhej</p>\r\n", 
                 Winaml.new.test('<<var1 = "\'hej\'"+"\'hej\'"><text>#{var1}<>'))
    assert_equal("\t<p>hejhej</p>\r\n", 
                 Winaml.new.test('<<var1 = "\'hej\'"><<var2 = var1+"\'hej\'"><text>#{var2}<>'))
  end
  
  def test_array
    assert_equal("", Winaml.new.test('<<var1 = [[3]]>'))
  end
  
  def test_table
    assert_equal("\t<table>\r\n\t<tr>\r\n\t\t<td>\r\n\t<p>hej</p>\r\n\t\t</td>\r\n\t</tr>\r\n\t<tr>\r\n\t\t<td>\r\n\t<p>hej</p>\r\n\t\t</td>\r\n\t</tr>\r\n</table>\r\n", 
                 Winaml.new.test('<<var1 = [[3][2]]><table var1><text>hej<><>'))
    
    assert_equal("\t<table>\r\n\t<tr>\r\n\t\t<td>\r\n\t<p>Hej 3!</p>\r\n\t\t</td>\r\n\t</tr>\r\n\t<tr>\r\n\t\t<td>\r\n\t<p>Hej 2!</p>\r\n\t\t</td>\r\n\t</tr>\r\n</table>\r\n", 
                 Winaml.new.test('<<var1 = [[3][2]]><table var1><text>Hej #{@item}!<><>'))
  end
end
