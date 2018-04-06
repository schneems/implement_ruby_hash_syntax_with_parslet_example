require 'parslet'

class RundocParser < Parslet::Parser
  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }
  rule(:lparen)     { str('(') >> space? }
  rule(:rparen)     { str(')') >> space? }
  rule(:comma)      { str(',') >> space? }

  rule(:lseattle)   { lparen | space? }
  rule(:rseattle)   { rparen | space? }

  rule(:show_operator)       { match('>').as(:show) }
  rule(:hide_operator)       { match('-').as(:hide) }
  rule(:show_hide_operator)  { show_operator | hide_operator }
  rule(:visability)          { show_hide_operator.as(:command) >> show_hide_operator.as(:result) >> space? }
  rule(:start_command)       { match(':').repeat(3, 3) >> visability.as(:visability) >> space? }
  rule(:identifier)          { match['.'].repeat(1) }
  rule(:comma)               { str(',') >> space? }

  rule(:integer)    { match('[0-9]').repeat(1).as(:int) >> space? }
  rule(:value)      { string | integer }

  rule(:key_value) {
    match['[:alnum:]'].repeat.as(:key) >> str(':') >> space.maybe >> value.as(:value)
  }

  rule(:arglist) {
    expression # >> (comma >> expression).repeat
  }

  rule('singlequote') { str(%Q{'}) }
  rule('doublequote') { str(%Q{"}) }
  rule("singlequote_string") {
    singlequote >> (str('\'').absnt? >> any).repeat.as(:string) >> singlequote >> space?
  }
  rule("doublequote_string") {
    doublequote >> (str('\'').absnt? >> any).repeat.as(:string) >> doublequote >> space?
  }

  rule(:unquoted_string) {
    match['[^\n\'\"]'].repeat.as(:string)
  }

  rule(:string) {
    doublequote_string | singlequote_string
  }


  rule(:expression) {
    string | key_value.as(:key_value) | unquoted_string
  }

  rule(:arglist)    { expression >> (comma >> expression).repeat }

  rule(:funcall) {
    match('[^ \(\)]').repeat(1).as(:funcall)
  }

  rule(:command) {
    funcall >>
    lseattle >>
    arglist.as(:arglist) >>
    rseattle >>
    stdin
  }

  rule(:stdin) {
    (start_command.absnt? >> any).repeat.as(:stdin)
  }

  rule(:code_comand) {
    (start_command >> command).as(:code).repeat
  }

  rule(:no_command) {
    (start_command.absnt? >> any).repeat.as(:no_code)
  }

  rule(:start) { no_command >> code_comand }
  root :start
end

# puts RundocParser.new.string.parse("'yo'")
puts RundocParser.new.command.parse("foo('s')")
puts RundocParser.new.command.parse("file.write lolol")

parser = RundocParser.new
puts parser.parse(":::>> foo('yo', 'sup', hello: 'world')")
puts parser.parse(":::>> foo(hello: 'world')")
puts parser.parse(":::>> $ cat 5 ")

puts RundocParser.new.no_command.parse(<<~EOL
  I am inside the block
howdy
EOL
)

puts RundocParser.new.start.parse(<<~EOL
  I am inside the block
howdy
:::>> file.write app/foo/bar.rb
EOL
)

puts parser.parse(<<~EOL
welcome
there
:::>> foo(hello_there: 'world')
  I am inside the block
:::>> hi('there')
and i am too
EOL
).inspect



puts parser.parse(<<~EOL
welcome
there
:::>> foo(hello_there: 'world')
  I am inside the block
:::>> | $ echo
EOL
).inspect

class RundocTransform < Parslet::Transform
  rule(:no_code => simple(:string)) { NoCode.new(string) }
  rule(:code => simple(:hash)) {NoCode.new(hash)}
end

class NoCode
  def initialize(val)
    @val = val
  end

  def eval
    @val
  end
end

parser = RundocParser.new
transf = RundocTransform.new

ast = transf.apply(
  parser.parse(<<~EOL
yoyo
EOL
  )
)

# puts "=="
# puts parser.parse(<<~EOL
# yoyo
# EOL
# )
# puts ast.eval

puts   parser.parse(<<~EOL
:::>> $ cat Gemfile
EOL
)


ast = transf.apply(
  parser.parse(<<~EOL
:::>> $ cat Gemfile
EOL
  )
)
puts "=="
puts ast.inspect
puts ast.eval
