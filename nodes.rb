# Set default value for html document
$vars = {
  '@title' => 'New WINAML document',
  '@language' =>'sv'
}

# Stack used for arrays.
$stack = 0
$stack_vars = {}

# Any text or number
class Constant_node
  attr_accessor :value
  def initialize(const)
    @value = const
  end
  def eval()
    return @value
  end
end

# For Expression_node at @operator
def evalnot(op)
  not op
end
def evaland(op)
  self and op
end
def evalor(op)
  self or op
end

class Expression_node
  attr_accessor :operand1, :operand2, :operator
  def initialize(op, op1, op2)
    @operand1 = op1
    @operand2 = op2
    @operator = op
  end
  def eval()
    return @operand1.eval().send(@operator, @operand2.eval())
  end
end

class Variable_node
  attr_accessor :id
  def initialize(id)
    @id = id
  end
  def eval()
    return $vars[@id.eval()] # Variable "@id" is evaled to get the correct value
  end
end

# Special variable
class Special_node
  attr_accessor :id
  def initialize(id)
    @id = id
  end
  def eval()
    
    if (@id == 'item') then
      return $stack_vars[$stack-1].eval() 
    end
  end
end

class Array_node
  attr_accessor :node_var, :node_table
  # Gets a Variable_node and a Array_box_node or Array_join_node
  def initialize(node_var, node_table)
    @node_var   = node_var
    @node_table = node_table
  end
  def eval()
    value = @node_var.eval()
    
    stack = $stack
    $stack = $stack + 1
    html = "\t<table>\r\n"
    value.each do |row|
      value = row.eval()
      html += "\t<tr>\r\n"
      value.each do |col|
        html += "\t\t<td>\r\n"
        # For @item variable
        $stack_vars[stack] = col
        html += @node_table.eval()
        html += "\t\t</td>\r\n"
      end
      html += "\t</tr>\r\n"
    end
    html += "</table>\r\n"
    
    $stack = $stack - 1
    
    return html
  end
end

class Array_box_node
  attr_accessor :node
  def initialize(node)
    @node = node
  end
  def eval()
    [@node]
  end
end

class Array_join_node
  attr_accessor :node1, :node2
  def initialize(node1, node2)
    @node1 = node1
    @node2 = node2 
  end
  def eval()
    @node1.eval() + @node2.eval()
  end
end

# Assign to variable
class Assign_node
  attr_accessor :var, :expr
  def initialize(var, expr)
    @var = var
    @expr = expr
  end
  def eval()
    value = @expr.eval()
    $vars[@var.eval()] = value
    nil
  end
end

class Condition_node
  attr_accessor :boolean, :node_true, :node_false
  def initialize(boolean, node_true, node_false=false)
    @boolean = boolean
    @node_true = node_true
    @node_false = node_false
  end
  def eval()
    if (@boolean.eval()) then
      @node_true.eval()
    else
      if (node_false) then
        @node_false.eval()
      end
    end
  end
end

# Merge other nodes
class Join_node
  attr_accessor :node1, :node2
  def initialize(node1, node2)
    @node1 = node1
    @node2 = node2
  end
  def eval()
    @node1.eval().to_s + @node2.eval().to_s
  end
end
