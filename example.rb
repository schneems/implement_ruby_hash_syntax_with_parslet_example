require 'parslet'

class MyParser < Parslet::Parser
  rule(:spaces)  { match('\s').repeat(1) }
  rule(:spaces?) { spaces.maybe }
  rule(:comma)   { spaces? >> str(',') >> spaces? }

  rule(:string) {
    str('"') >> (
      str('"').absent? >> any
    ).repeat.as(:string) >> str('"')
  }

  rule(:value) {
    string
  }

  rule(:key) {
    spaces? >> (
      str(':').absent? >> match('\s').absent? >> any
    ).repeat.as(:key) >> str(':') >> spaces?
  }

  rule(:key_value) {
    (
      key >> value.as(:val)
    ).as(:key_value) >> spaces?
  }

  rule(:named_args) {
    spaces? >> (
      key_value >> (
        comma >> key_value
      ).repeat
    ).as(:named_args) >> spaces?
  }

  rule(:hash_obj) {
    spaces? >> (
      str('{') >> named_args >> str('}')
    ) >> spaces?
  }
end

class MyTransformer < Parslet::Transform
  rule(string: simple(:st)) { st.to_s }

  rule(dog: 'terrier', cat: simple(:ct)) {
    {dog: 'foo', cat: ct }
  }

  rule(:named_args => subtree(:na)) {
    Array(na).each_with_object({}) { |element, hash|
      key = element[:key_value][:key].to_sym
      val = element[:key_value][:val]
      hash[key] = val
    }
  }
end

require 'minitest/autorun'
require 'parslet/convenience'

class MyParserTest < Minitest::Test
  def test_parses_a_comma
    input = %Q{,}
    parser = MyParser.new.comma
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree
  end

  def test_parses_a_comma_with_spaces
    input = %Q{ , }
    parser = MyParser.new.comma
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree
  end

  def test_parses_a_string
    input = %Q{"hello world"}
    parser = MyParser.new.string
    tree = parser.parse_with_debug(input)
    expected = {string: "hello world"}
    assert_equal expected, tree
  end

  def test_dog_cat
    tree = { dog: 'terrier', cat: 'suit'}

    actual = MyTransformer.new.apply(tree)
    expected = { dog: 'foo', cat: 'suit' }
    assert_equal expected, actual
  end

  def test_key
    input = %Q{ hello: }
    parser = MyParser.new.key
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree
  end

  def test_parses_a_key_value_pair
    input = %Q{ hello: "world" }
    parser = MyParser.new.key_value
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree

    actual = MyTransformer.new.apply(tree)
    expected = {key_value: {key: "hello", val: "world"}}
    assert_equal expected, actual
  end

  def test_parses_multiple_key_value_pairs
    input = %Q{ hello: "world", hi: "there" }
    parser = MyParser.new.named_args
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree

    # actual = MyTransformer.new.apply(tree)
    # expected = {:named_args=>[{:key_value=>{:key=>"hello", :val=>"world"}}, {:key_value=>{:key=>"hi", :val=>"there"}}]}
    # assert_equal expected, actual
  end

  def test_parses_hash
    input = %Q{ { hello: "world", hi: "there" } }
    parser = MyParser.new.hash_obj
    tree = parser.parse_with_debug(input)
    refute_equal nil, tree

    actual = MyTransformer.new.apply(tree)
    expected = { hello: "world", hi: "there" }
    assert_equal expected, actual
  end
end
