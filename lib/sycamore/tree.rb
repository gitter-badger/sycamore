module Sycamore

  ############################################################################
  #
  # A tree data structure as a recursively nested set of nodes of immutable values.
  #
  # A Sycamore tree is a set of nodes with links to their child trees,
  # consisting of the child nodes and their child trees etc.
  # The links from a node to its child tree is stored in a Hash,
  # the {@data} instance variable.
  #
  # @see {README.md} for an introduction
  #
  class Tree

    include Enumerable

    attr_reader :data
    protected :data

    ########################################################################
    # CQS
    ########################################################################

    ADDITIVE_COMMAND_METHODS    = %i[add << replace create_child] << :[]=
    DESTRUCTIVE_COMMAND_METHODS = %i[delete >> clear]
    COMMAND_METHODS = ADDITIVE_COMMAND_METHODS + DESTRUCTIVE_COMMAND_METHODS +
      %i[child_constructor= child_class= def_child_generator freeze]

    PREDICATE_METHODS =
      %i[nothing? absent? present? blank? empty?
         include? include_node? member? key? has_key? has_path? path? >= > < <=
         leaf? leaves? internal? external? flat? nested?
         eql? matches? === ==]
    QUERY_METHODS = PREDICATE_METHODS +
      %i[new_child child_constructor child_class child_generator
         size height node nodes keys child_of child_at dig fetch
         each each_path paths each_node each_key each_pair
         hash to_h to_s inspect] << :[]

    # @return [Array<Symbol>] the names of all methods, which can change the state of a Tree
    #
    def self.command_methods
      COMMAND_METHODS
    end

    # @return [Array<Symbol>] the names of all command methods, which add elements to a Tree only
    #
    def self.additive_command_methods
      ADDITIVE_COMMAND_METHODS
    end

    # @return [Array<Symbol>] the names of all command methods, which delete elements from a Tree only
    #
    def self.destructive_command_methods
      DESTRUCTIVE_COMMAND_METHODS
    end

    # @return [Array<Symbol>] the names of all methods, which side-effect-freeze return only a value
    #
    def self.query_methods
      QUERY_METHODS
    end

    # @return [Array<Symbol>] the names of all query methods, which return a boolean
    #
    def self.predicate_methods
      PREDICATE_METHODS
    end


    ########################################################################
    # Construction
    ########################################################################

    # creates a new empty Tree
    #
    def initialize
      @data = Hash.new
    end

    # creates a new Tree and initializes it with the given data
    #
    # @example
    #   Tree[1]           # => 1
    #   Tree[1, 2, 3]     # => [1,2,3]
    #   Tree[1, 2, 2, 3]  # => [1,2,3]
    #   Tree[x: 1, y: 2]  # => {:x=>1, :y=>2}
    #
    # @param (see #add)
    #
    # @return [Tree] initialized with the given data
    #
    def self.with(*args)
      tree = new
      tree.add( args.size == 1 ? args.first : args ) unless args.empty?
      tree
    end

    class << self
      alias from with
      alias [] with
    end


    ######################
    # Child construction #
    ######################

    def new_child(*args)
      case
        when child_constructor.nil? then self.class.new(*args)
        when child_class            then child_class.new(*args)
        # TODO: pending Tree#clone
        # when child_prototype        then child_prototype.clone.add(*args)
        when child_generator        then child_generator.call # TODO: pass *args
        else raise "invalid child constructor: #{child_constructor.inspect}"
      end
    end

    def child_constructor=(prototype_or_class)
      case prototype_or_class
        when Class then self.child_class = prototype_or_class
        # TODO: pending Tree#clone
        # when Tree  then self.child_prototype = prototype_or_class
        else raise ArgumentError, "expected a Sycamore::Tree object or subclass, but got a #{prototype_or_class}"
      end
    end

    def child_constructor
      @child_constructor
    end

    def child_class
      @child_constructor if @child_constructor.is_a? Class
    end

    def child_class=(tree_class)
      raise ArgumentError, "expected a Tree subclass, but got a #{tree_class}" unless tree_class <= Tree
      @child_constructor = tree_class
    end


    # TODO: pending Tree#clone
    # def child_prototype
    #   @child_constructor if @child_constructor.is_a? Tree
    # end
    #
    # def child_prototype=(tree)
    #   raise ArgumentError, "expected a Tree object, but got a #{tree}" unless tree.is_a? Tree
    #   @child_constructor = tree
    # end


    def child_generator
      @child_constructor if @child_constructor.is_a? Proc
    end

    def def_child_generator(&block)
      @child_constructor = block
    end


    ########################################################################
    # Absence and Nothing predicates
    ########################################################################

    # @return [Boolean] if this is the {Nothing} tree
    #
    def nothing?
      false
    end

    # @return [Boolean] if this is an absent tree
    #
    def absent?
      false
    end

    # @return [Boolean] if this is not {blank?}, i.e. {empty?}
    #
    # @note This is not the negation of {absent?}, since this would result in a
    #   different behaviour than ActiveSupports present? method.
    #
    def present?
      not blank?
    end


    ########################################################################
    # Element access
    ########################################################################

    #####################
    #  command methods  #
    #####################

    # The universal method to add nodes with or without children.
    #
    # Depending on the argument, this method only delegates appropriately to one
    # of the other more specific `add` methods.
    #
    # @param [Object, Hash, Enumerable] nodes_or_struct TODO TODOC
    #
    #
    # @return self as a proper command method (see Sycamore::CQS#command_return)
    #
    # @see #add_nodes
    #
    # @todo Can we optimize this method, by reducing the checks in the other
    #   add_* methods (which were public previously)?
    #
    def add(nodes_or_struct)
      if Tree.like? nodes_or_struct
        add_children(nodes_or_struct)
      else
        add_nodes(nodes_or_struct)
      end
    end

    alias << add

    # TODO: Extract unique content and remove the documentation, since private?
    # adds a single leaf
    #
    # @todo https://www.pivotaltracker.com/story/show/94733228
    #   reasons for the NestedNodeSet exception
    #
    # @todo https://www.pivotaltracker.com/story/show/94733114
    #   What should we use as the default value for the hash entry of a leaf?
    #
    # @param [Object] node to add
    #
    #   If node is an Enumerable, an {NestedNodeSet} exception is raised
    #
    # @return self as a proper command method (see Sycamore::CQS#command_return)
    #
    # @see #add, #add_nodes
    #
    private def add_node(node)
      return self if node.nil? or node.equal? Nothing
      return add_children(node) if Tree.like? node
      raise NestedNodeSet if node.is_a? Enumerable

      @data[node] ||= Nothing

      self
    end

    # TODO: Extract unique content and remove the documentation, since private?
    # adds multiple leaves
    #
    # It delegates every single leaf to {$add_node}. Although this isn't the
    # fastest way, adding the nodes directly to the hash would be a premature
    # optimization and is deferred until the API has settled.
    #
    # As it delegates to {add_node}, if one the given values it itself an Enumerable,
    # a {NestedNodeException} gets raised.
    #
    # @param [Object] nodes to add
    #
    #   If the nodes Enumerable contains other Enumerables, an {NestedNodeSet} exception is raised
    #
    # @return self as a proper command method
    #
    # @raise {NestedNodeSet}
    #
    # @see #add, #add_node
    #
    private def add_nodes(*nodes)
      nodes = nodes.first if nodes.size == 1 and nodes.is_a? Enumerable
      return add_node(nodes) unless nodes.is_a? Enumerable

      nodes.each { |node| add_node(node) }

      self
    end

    def create_child(node)
      raise IndexError, 'nil is not a valid tree node' if node.nil?

      if @data.fetch(node, Nothing).nothing?
        @data[node] = new_child
      end

      self
    end

    private def add_child(node, children)
      return self if node.nil? or node.equal? Nothing # TODO: raise IndexError
      return add_node(node) if children.nil? or children.equal?(Nothing) or # TODO: when Absence defined: child.nothing? or child.absent?
        (Enumerable === children and children.empty?)

      @data[node] = new_child if @data.fetch(node, Nothing).nothing?
      @data[node] << children

      self
    end

    private def add_children(tree)
      return self if tree.respond_to?(:absent?) and tree.absent?

      tree.each { |node, child| add_child(node, child) }

      self
    end


    # The universal method to remove nodes with or without children.
    #
    # Depending on the argument, this method only delegates appropriately to one
    # of the other more specific `delete` methods.
    #
    # @param [Object, Hash, Enumerable] nodes_or_struct TODO TODOC
    #
    #
    # @return self as a proper command method
    #
    # @see #add_nodes
    #
    # @todo Can we optimize this method, by reducing the checks in the other
    #   delete_* methods (which were public previously)?
    #
    def delete(nodes_or_struct)
      if Tree.like? nodes_or_struct
        delete_children(nodes_or_struct)
      else
        delete_nodes(nodes_or_struct)
      end
    end

    alias >> delete

    # TODO: Extract unique content and remove the documentation, since private?
    # removes a node with its child
    #
    # If the given node is in the {#nodes} set, it gets deleted, otherwise
    # nothing happens.
    #
    # @param [Object] node to delete
    #
    # @return self as a proper command method
    #
    private def delete_node(node)
      return delete_children(node) if Tree.like? node
      raise NestedNodeSet if node.is_a? Enumerable

      @data.delete(node)

      self
    end

    private def delete_nodes(*nodes)
      nodes = nodes.first if nodes.size == 1 and nodes.is_a? Enumerable
      return delete_node(nodes) unless nodes.is_a? Enumerable

      nodes.each { |node| delete_node(node) }

      self
    end

    private def delete_children(tree)
      return self if tree.respond_to?(:absent?) and tree.absent?

      tree.each do |node, child|
        next unless include? node
        this_child = self.child_of(node)
        this_child.delete child
        delete_node(node) if this_child.empty?
      end

      self
    end

    # Replaces the contents of the tree
    #
    # @param (see #add)
    # @return self as a proper command method
    #
    def replace(nodes_or_struct)
      clear.add(nodes_or_struct)
    end

    # Replaces the contents of a child tree
    #
    # @param TODO
    # @return the rvalue as any Ruby assignment
    #
    def []=(*args)
      path, nodes_or_struct = args[0..-2], args[-1]
      raise ArgumentError, 'wrong number of arguments (given 1, expected 2)' if path.empty?
      raise IndexError, 'nil is not a valid tree node' if path.include? nil

      child_at(*path).replace(nodes_or_struct)
    end

    # Deletes all nodes and their children
    #
    # @return self as a proper command method
    #
    def clear
      @data.clear

      self
    end


    #####################
    #   query methods   #
    #####################

    # The set of child nodes of the parent.
    #
    # @example
    #   child = [:bar, :baz]
    #   tree = Tree[foo: child]
    #   tree.nodes        # => [:foo]
    #   tree[:foo].nodes  # => [:bar, :baz]
    #
    # @return [Array<Object>] the nodes of this tree (without their children)
    #
    def nodes
      @data.keys
    end

    alias keys nodes  # Hash compatibility


    # The only child node of the parent or an Exception, if more nodes present
    #
    # @example
    #   Tree[1].node  # => 1
    #   Tree.new.node  # => nil
    #
    #   matz = Tree[birthday: DateTime.parse('1965-04-14')]
    #   matz[:birthday].node  # => #<DateTime: 1965-04-14T00:00:00+00:00 ((2438865j,0s,0n),+0s,2299161j)>
    #
    #   Tree[1,2].node  # => TypeError: no implicit conversion of node set [1, 2] into a single node
    #
    # @return [Object] the single present node or nil, if no nodes present
    # @raise [TypeError] if more than one node present
    #
    # @todo Provide support for selector and reducer functions.
    # @todo Raise a more specific Exception than TypeError.
    def node
      nodes = self.nodes
      raise TypeError, "no implicit conversion of node set #{nodes} into a single node" if  nodes.size > 1

      nodes.first
    end

    # @todo Should we differentiate the case of a leaf and a not present node?
    def child_of(node)
      raise IndexError, 'nil is not a valid tree node' if node.nil?

      child = @data[node]
      (child.nil? || child.nothing?) ? Absence.at(self, node) : child
    end

    def child_at(*path)

      case path.length
        when 0
          raise ArgumentError, 'wrong number of arguments (given 0, expected 1+)'
        when 1
          if path.first.is_a? Array
            child_at(*path.first)
          else
            child_of(*path)
          end
        else
          child_of(path[0]).child_at(*path[1..-1])
      end
    end

    alias [] child_at
    alias dig child_at  # Hash compatibility

    def fetch(*node_and_default, &block)
      case node_and_default.size
        when 1 then node = node_and_default.first
          tree = @data.fetch(node, &block)
          tree.nil? ? Nothing : tree
        when 2 then node, default = *node_and_default
          if block_given?
            warn "block supersedes default value argument"
            fetch(node, &block)
          else
            @data.fetch(node, default) or Nothing
          end
        else raise ArgumentError, "wrong number of arguments (given #{node_and_default.size}, expected 1..2)"
      end
    end

    def each_node(&block)
      @data.each_key(&block)
    end

    alias each_key each_node  # Hash compatibility

    def each_pair(&block)
      @data.each_pair(&block)
    end

    alias each each_pair

    def each_path(with_ancestor: Path::ROOT, &block)
      return enum_for(__callee__) unless block_given?
      each do |node, child|
        if child.nothing?
          yield Path[with_ancestor, node]
        else
          child.each_path(with_ancestor: with_ancestor.branch(node), &block)
        end
      end
      self
    end

    alias paths each_path

    def has_path?(*args)
      raise ArgumentError, 'wrong number of arguments (given 0, expected 1+)' if args.count == 0

      if args.count == 1
        arg = args.first
        if arg.is_a? Path
          arg.in? self
        else
          Path.of(arg).in? self
        end
      else
        Path.of(*args).in? self
      end
    end

    alias path? has_path?


    def include_node?(node)
      @data.include?(node)
    end

    alias member?  include_node?  # Hash compatibility
    alias has_key? include_node?  # Hash compatibility
    alias key?     include_node?  # Hash compatibility

    # @param [Object] elements to check for, if it is an element of this tree
    #
    # @return [Boolean] if this tree includes the given node
    #
    # @todo Support paths as arguments by delegating to {#hash_path?} or directly to {Path#in?}
    def include?(elements)
      case
        when Tree.like?(elements)
          # TODO: Extract this into a new method include_tree? or move this into the new method #<=
          elements.all? do |node, child|
            include_node?(node) and ( child.nil? or child.equal?(Nothing) or
                                        self.child_of(node).include?(child) )
          end
        when elements.is_a?(Enumerable)
          elements.all? { |element| include_node? element } # TODO: use include_nodes?
        else
          include_node? elements
      end
    end

    def >=(other)
      other.is_a?(Tree) and self.include?(other)
    end

    def >(other)
      other.is_a?(Tree) and self.include?(other) and self != other
    end

    def <(other)
      other.is_a?(Tree) and other.include?(self) and self != other
    end

    def <=(other)
      other.is_a?(Tree) and other.include?(self)
    end


    # @return [Fixnum] the number of nodes in this tree
    #
    def size
      @data.size
    end

    # @return [Fixnum] the length of the longest path
    #
    def height
      return 0 if empty?
      paths.map(&:length).max
    end

    # @return [Boolean] if the tree is empty
    #
    def empty?
      @data.empty?
    end

    alias blank? empty?

    # @return [Boolean] if the given node has no children
    #
    def leaf?(node)
      raise TypeError, "expected a node, but got #{node}" if node.is_a? Enumerable

      @data.include?(node) && ( (child = @data[node]).nil? || child.empty? )
    end

    # @return [Boolean] if all of the given nodes have no children
    #
    def external?(*nodes)
      nodes = self.nodes if nodes.empty?

      nodes.all? { |node| leaf?(node) }
    end

    alias leaves? external?
    alias flat? external?

    # @return [Boolean] if all of the given nodes have children
    #
    def internal?(*nodes)
      return false if self.empty?
      nodes = self.nodes if nodes.empty?

      nodes.all? { |node| not leaf?(node) and include_node?(node) }
    end

    alias nested? internal?


    ########################################################################
    # Equality
    ########################################################################

    def hash
      @data.hash ^ Tree.hash
    end

    def eql?(other)
      (other.instance_of?(self.class) and @data.eql?(other.data)) or
        ((other.equal?(Nothing) or other.instance_of?(Absence)) and other.eql?(self))
    end

    alias == eql?

    def matches?(other)
      case
        when Tree.like?(other)       then matches_tree?(other)
        when other.is_a?(Enumerable) then matches_enumerable?(other)
                                     else matches_atom?(other)
      end
    end

    alias === matches?

    private def matches_atom?(other)
      not other.nil? and (size == 1 and nodes.first == other and leaf? other)
    end

    private def matches_enumerable?(other)
      size == other.size and
        all? { |node, child| child.empty? and other.include?(node) }
    end

    private def matches_tree?(other)
      size == other.size and
        all? { |node, child|
          if child.nothing?
            other.include?(node) and
              # TODO: cache other[node] in a local variable
              ( other[node].nil? or other[node] == Nothing or
                (other[node].respond_to?(:empty?) and other[node].empty?) )
          else
            child.matches? other[node]
          end }
    end


    ########################################################################
    # Conversion
    ########################################################################

    def to_h(flattened: false)
      case
        when empty?
          {}
        when leaves?
          if flattened
            size == 1 ? nodes.first : nodes
          else
            map{ |node, _| [node, {}] }.to_h
          end
        else
          # not the prettiest, but the fastest way to inject on hashes, as noted
          # here: http://stackoverflow.com/questions/3230863/ruby-rails-inject-on-hashes-good-style
          hash = {}
          @data.each do |node, child|
            hash[node] = child.to_h(flattened: true)
          end
          hash
      end
    end

    def to_s
      "#<Tree: #{to_h(flattened: true)}>"
    end

    # @return a developer-friendly representation of `self` in the usual Ruby Object#inspect style.
    #
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)}(#{to_h(flattened: true).inspect})>".freeze
    end

    def self.tree_like?(object)
      case object
        when Hash, Tree, Absence # ... ?!
          true
        else
          (object.respond_to? :tree_like? and object.tree_like?) # or ...
      end
    end

    class << self
      alias like? tree_like?
    end


    ########################################################################
    # Various other Ruby protocols
    ########################################################################

    # overrides {Object#freeze} by delegating it to the internal hash {@data}
    #
    # TODO: How to do proper links with YARD and markdown support?
    #
    # @see Ruby's [Object#freeze](http://ruby-doc.org/core-2.2.2/Object.html#method-i-freeze)
    # @see Ruby's {http://ruby-doc.org/core-2.2.2/Object.html#method-i-freeze Object#freeze}
    #
    def freeze
      @data.freeze
      super
    end

  end  # Tree
end  # Sycamore
