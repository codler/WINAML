require 'rdparse'
require 'nodes'

class Winaml
  
  def init_html() 
    # Set default values for html document.
    @html_output = {
      'html_begin' => "
<!DOCTYPE html>
<html lang=\"#{$vars['@language']}\">
	<head>
		<meta charset=\"utf-8\" />
		<title>#{$vars['@title']}</title>		
	</head>

	<body>\r\n",
      'html_end' => "\r\n\t</body>\r\n</html>"
    }
    
    return @html_output
  end
  
  def initialize
    
    @winaml_parser = Parser.new("winamlParser") do
      # Filters out all comments.
      token(/!"(.*?)"!/)
      # Escape '<' to html.
      token(/\\</) { |m| '&lt;' }
      # Escape '>' to html.
      token(/\\>/) { |m| '&gt;' }
      # Filters out spaces except in text-tags or strings.
      token(/(\s)(?!((?!"').)*'")(?!((?!<text>).)*<>)/)
      # Match words.
      token(/[a-zA-Z][a-zA-Z0-9]*/) { |m| m }
      # Match integers.
      token(/\d+/) {|m| m.to_i }
      # Match rest, one sign.
      token(/./) {|m| m }
      
      start :program do
        match(:condition, :program) { |a,b| Join_node.new(a, b) }
        match(:condition) { |a| a }
        match(:tags, :program) { |a,b| Join_node.new(a, b) }
        match(:tags) { |a| a }
        match(:getvars, :program) { |a,b| Join_node.new(a, b) }
        match(:getvars) { |a| a }
        match(:setvars,:program) { |a,b| Join_node.new(a, b) }
        match(:setvars) { |a| a }
      end
      
      # if-statement
      # eg. <<if true> X <endif>
      rule :condition do
        match('<', '<', 'if', :booleans, '>', :program, '<', '<', 'endif', '>'){ 
          |_,_,_,a,_,b,_,_,_,_| Condition_node.new(a, b)}
        match('<', '<', 'if', :booleans, '>', :program, '<', '<', 'else', '>', 
              :program, '<', '<', 'endif', '>') { 
          |_,_,_,a,_,b,_,_,_,_,c,_,_,_,_| Condition_node.new(a, b, c) }
      end
      
      # Boolean expressions.
      rule :booleans do
        match(:boolean, 'and', :booleans) { |a,_,b| 
          Expression_node.new(:evaland, a, b) }
        match(:boolean, 'or', :booleans) { |a,_,b| 
          Expression_node.new(:evalor, a, b) }
        match(:boolean) { |a| a }
        #match('(',:booleans,')') { |_,a,_| a }
      end
      
      rule :boolean do
        match('not', :boolean) { |_,a| Expression_node.new(:evalnot, a, a) }
        match('not', '(', :booleans, ')') { |_,_,a,_| 
          Expression_node.new(:evalnot, a, a) }
        match(:expr, :operator, :expr) { |a,b,c| Expression_node.new(b, a, c) }
        match('true') { |a| Constant_node.new(true)}
        match('false') { |a| Constant_node.new(false)}
        match(:expr) { |a| a}
        match('(',:booleans,')') { |_,a,_| a }
      end
      
      rule :operator do
        match('=', '=') { |_,_| :== }
        match('!', '=') { |_,_| :!= } #Ruby1.9 needed to use ":!=" as a symbol.
        match('>') {|_| :> }
        match('<') {|_| :< }
        match('>', '=') {|_| :>= }
        match('<', '=') {|_| :<= }
      end
        
      rule :tags do
        # Text tag.
        # eg. <text>Hello<>
        match('<','text','>', :anytext, '>') { |_,_,_,a,_| 
          Join_node.new(Join_node.new(Constant_node.new("\t<p>"), a), 
                        Constant_node.new("</p>\r\n")) 
        }
        match('<','text','>', '<', '>') { |_,_,_,_,_| 
          Constant_node.new("\t<p></p>\r\n")
        }
        
        # Table tag.
        # eg. <table data> X <>
        match('<','table', :expr,'>', :program,'<', '>') { |_,_,a,_,b,_,_| 
          Array_node.new(a, b)
        }
      end
      
      # The text in text tags.
      rule :anytext do
        match(:getvars, '<') { |a,_| a }
        match(:getvars, :anytext) { |a,b| Join_node.new(a, b) }
        match(:token, '<') {|a,_| a }
        match(:token, :anytext) { |a,b| Join_node.new(a, b) }
      end
      
      # String datatype.
      rule :string do
        match(:getvars, '\'') { |a,_| a }
        match(:getvars, :string) { |a,b| Join_node.new(a, b) }
        match(:token, '\'') {|a,_| a }
        match(:token, :string) { |a,b| Join_node.new(a, b) }
      end
      
      rule :token do
        match(String) { |a| Constant_node.new(a) }
        match(Integer) { |a| Constant_node.new(a.to_s) }
      end
      
      # Evaluate WINAML programming code.
      rule :getvars do
        match('#', '{', '@', 'item','}') { |_,_,_,_,_| 
          Special_node.new('item') }
        match('#', '{', '@', :var,'}') { |_,_,_,a,_| a.value = "@" + a.value; 
          Variable_node.new(a) }
        match('#', '{',:expr,'}') { |_,_,a,_| a }
        
      end
      
      rule :setvars do
        # Declare or assign a special variable to an expression.
        match('<', '<', '@', :var,'=',:expr,'>') { |_,_,_,a,_,b,_| a.value = 
          "@" + a.value; Assign_node.new(a, b) }
	
        # Declare or assign a variable to an array.
        match('<', '<', :var,'=','[',:array,']', '>') { |_,_,a,_,_,b,_,_| 
          Assign_node.new(a, b) }
        
        # Declare or assign a variable to an expression.
        match('<', '<', :var,'=',:expr,'>') { |_,_,a,_,b,_| 
          Assign_node.new(a, b) }
        
      end
      
      # Array datatype.
      rule :array do
        match('[', :box, ']', :array) { |_,a,_,b| 
          Array_join_node.new(Array_box_node.new(a), b) }
        match('[', :box, ']') { |_,a,_| Array_box_node.new(a) }
      end
      
      rule :box do
        match(:expr, ',', :box) { |a,_,b| 
          Array_join_node.new(Array_box_node.new(a) ,b) }
        match(:expr) { |a| Array_box_node.new(a) }
      end
      
      # Acceptable variablename.
      rule :var do
        match(/[a-zA-Z][a-zA-Z0-9]*/) { |a| Constant_node.new(a) }
      end
      
      # Arithmetic expressions.
      rule :expr do 
        match(:expr, '+', :term) { |a, _, b| Expression_node.new(:+, a, b) }
        match(:expr, '-', :term) { |a, _, b| Expression_node.new(:-, a, b) }
        match(:term)
      end
      
      rule :term do 
        match(:term, '*', :atom) { |a, _, b| Expression_node.new(:*, a, b) }
        match(:term, '/', :atom) { |a, _, b| Expression_node.new(:/, a, b) }
        match(:atom)
      end
      
      rule :atom do
        # Match an Integer, variable, WINAML-string or an (expression).
        match(Integer) { |a| Constant_node.new(a) }
        match(:var) { |a| Variable_node.new(a) }
        match('"',"'",:string,'"') { |_,_,a,_| a }
        match('(', :expr, ')') { |_, a, _| a }
      end
    end
  end
  
  # Exit WINAML.
  def done(str)
    ["quit","exit","bye",""].include?(str.chomp)
  end
  
  # WINAML "include"-function.
  def include_file(data)
    found = false
    data = data.gsub(/<<include "'(.*?)'">/) {|m| found = true; 
      File.new(m.sub("<<include \"'", '').sub("'\">", '')).read()}
    if (found) then
      data = include_file(data)
    end
    data
  end
  
  #For testing purposes.
  def test(str) 
    $vars = {}
    log(false)
    parsed_data = @winaml_parser.parse(str)
    return parsed_data.eval().to_s
  end  
  
  def parse()
    log(false)
    # user input
    print "[WINAML] "
    str = gets
    str = str.strip
    if done(str) then
      puts "Bye."
    else
      if str.index('.wml') then
        data = File.new(str).read()
        # Check for WINAML "include"-code before parse.
        data = include_file(data)
      	write_file = File.new(str.gsub(".wml",".html"), 'w')
      	parsed_data = @winaml_parser.parse(data)
       	parsed_data_eval = parsed_data.eval().to_s
      	html = init_html()
      	write_file << html['html_begin'] 
      	write_file << parsed_data_eval
      	write_file << html['html_end']
      	puts html['html_begin'] + parsed_data.eval().to_s + html['html_end']
      	write_file.close
      else
      	puts "Wrong file format"
      end
      parse
    end
  end
  
  def log(state = true)
    if state
      @winaml_parser.logger.level = Logger::DEBUG
    else
      @winaml_parser.logger.level = Logger::WARN
    end
  end
end

# Start WINAML parser.
Winaml.new.parse
