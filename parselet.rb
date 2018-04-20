require 'parslet'

class MiniP < Parslet::Parser
  # Single character rules
  rule(:lparen)     { str('(') >> space? }
  rule(:rparen)     { str(')') >> space? }
  rule(:comma)      { space? >> str(',') >> space? }

  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }

  # Things
  rule(:integer)    { match('[0-9]').repeat(1).as(:int) >> space? }
  rule(:identifier) { match['a-z'].repeat(1) }
  rule(:operator)   { match('[+]') >> space? }

  # Grammar partse
  rule(:sum)        {
    integer.as(:left) >> operator.as(:op) >> expression.as(:right) }
  rule(:arglist)    { expression >> (comma >> expression).repeat }
  rule(:funcall)    {
    identifier.as(:funcall) >> lparen >> arglist.as(:arglist) >> rparen }

  rule(:expression) { funcall | sum | integer }
  root :expression
end

IntLit = Struct.new(:int) do
  def eval; int.to_i; end
end
Addition = Struct.new(:left, :right) do
  def eval; left.eval + right.eval; end
end
FunCall = Struct.new(:name, :args) do
  def eval; puts args.inspect; p args.map { |s| s.eval }; end
end

class MiniT < Parslet::Transform
  rule(:int => simple(:int))        { IntLit.new(int) }
  rule(
    :left  => simple(:left),
    :right => simple(:right),
    :op    => '+')                     { Addition.new(left, right) }

  rule(
    :funcall => 'puts',
    :arglist => subtree(:arglist))  { FunCall.new('puts', arglist) }
end

parser = MiniP.new
transf = MiniT.new

puts parser.parse('puts(1,2,3, 4+5, 10 + 1)')

ast = transf.apply(
  parser.parse(
    'puts(1+1)'))

ast.eval # => [1, 2, 3, 9]
