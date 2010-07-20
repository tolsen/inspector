# Copyright (c) 2007 Lime Spot LLC

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'generator'
require 'rexml/document'

module Inspector::Assertions

  TEST_XML_REXML_DOC_CTX = {
    :compress_whitespace => :all,
    :ignore_whitespace_nodes => :all
  } unless defined? TEST_XML_REXML_DOC_CTX

  class XmlMatchAssertion
    
    def initialize doc, testcase
      doc = REXML::Document.new(doc, TEST_XML_REXML_DOC_CTX) if doc.instance_of? String
      @children = [ doc.root ]
      @namespaces = self.class.empty_ns
      @seen = []
      @tc = testcase
      @num_matched = 0
      @errors = []
    end

    def method_missing sym, *args, &block
      ns, name = if args[0].instance_of? Symbol
                   raise "prefix #{sym} not defined" unless @namespaces.include? sym
                   [ @namespaces[sym], args.shift.to_s ]
                 else
                   [ @namespaces[:@default], sym.to_s ]
                 end

      if @ordered
        assert_current_element ns, name, *args, &block
      else
        assert_any_element ns, name, *args, &block
      end

      @num_matched += 1
    end

    alias tag! method_missing

    def ordered!() @ordered = true; end
    def unordered!() @ordered = false; end

    def subset_match!() @subset_match = true; end

    def xmlns! arg
      case arg
      when String then @namespaces[:@default] = arg
      when Hash then @namespaces.merge! arg
      else raise "arg must be String or Hash"
      end
    end

#     def inner_xml! actual_xml
#       assert_inner_xml_current_element actual_xml
#     end
    
    private
    
    def assert_any_element ns, name, text = nil, &block
      children_left.each do |child|
        begin
          assert_element child, ns, name, text, &block
          @errors.clear
          return
        rescue Test::Unit::AssertionFailedError => e
          @errors << e
        end
      end

      error_msg = @errors.map { |e| e.to_s }.join "\n"
      error_msg << "\nfailed to match tree starting at element #{name}"
      @tc.flunk error_msg
    end

    def assert_current_element ns, name, text = nil, &block
      left = assert_children_left
      assert_element left[0], ns, name, text, &block
    end

    def assert_element element, ns, name, text = nil, &block
      @tc.assert_equal ns, element.namespace, "namespace mismatch"
      @tc.assert_equal name, element.name, "element mismatch"

      case text
      when String
        @tc.assert_equal text, element.text, "text node mismatch"
      when Regexp
        @tc.assert_match text, element.text
      when Proc
        text.call element
      end
      
      if block_given?
        with_state_safe do
          @children = element.children
          @seen = []
          @num_matched = 0
          @errors = []
          yield
          @tc.assert_equal @num_matched, @children.size, "children mismatch for element #{name}" if !@subset_match
        end
      end

      @seen << element
    end

# does not work yet (innerXML should be outerXML ?)
#     def assert_inner_xml_current_element actual_xml
#       left = assert_children_left
#       assert_inner_xml left[0], actual_xml
#     end
    
    
#     def assert_inner_xml element, actual_xml
#       puts "EXPECTED: "
#       puts element
#       puts element.innerXML

#       puts "ACTUAL: "
#       puts actual_xml
      
#       @tc.assert_equal element.innerXML, actual_xml
#     end
    

    def assert_children_left
      left = children_left
      @tc.assert !left.empty?, "expected more children, but no children left"
      left
    end
    
    def children_left() @children - @seen; end

    def with_state_safe
      orig_ordered = @ordered
      orig_namespaces = @namespaces.clone
      orig_children = @children.clone
      orig_seen = @seen.clone
      orig_num_matched = @num_matched
      orig_errors = @errors
      yield
    ensure
      @errors = orig_errors
      @num_matched = orig_num_matched
      @seen = orig_seen
      @children = orig_children
      @namespaces = orig_namespaces
      @ordered = orig_ordered
    end
    
    def self.empty_ns() { :@default => '' }; end
    
  end
end

    
    
