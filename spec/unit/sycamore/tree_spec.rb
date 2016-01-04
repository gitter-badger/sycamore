require 'set'

describe Sycamore::Tree do

  it { is_expected.to be_a Enumerable }

  specify { expect { Sycamore::Tree[].data }.to raise_error NoMethodError }

  ############################################################################
  # construction
  ############################################################################

  describe '#initialize' do
    context 'when given no initial nodes and/or a block' do
      specify { expect( Sycamore::Tree.new ).to be_a Sycamore::Tree }
      specify { expect( Sycamore::Tree.new ).to be_empty }
    end
  end

  describe '.with' do
    context 'when given no args' do
      subject { Sycamore::Tree[] }
      it { is_expected.to be_a Sycamore::Tree }
      it { is_expected.to be_empty }
    end

    context 'when given one argument' do
      context 'when the argument is not an enumerable' do
        subject(:tree) { Sycamore::Tree[1] }

        it 'does return a new tree' do
          expect( tree ).to be_a Sycamore::Tree
        end

        it 'does initialize the new tree with the given values' do
          expect( tree ).to include_node_with 1
        end
      end

      context 'when the argument is a single Enumerable' do
        it 'does initialize the new tree with the elements of the enumerable' do
          expect( Sycamore::Tree[[1, 2]]       ).to include_nodes_with 1, 2
          expect( Sycamore::Tree[Set[1, 2, 2]] ).to include_nodes_with 1, 2
          expect( Sycamore::Tree[[1, 2, 2]]    ).to include_nodes_with 1, 2
          expect( Sycamore::Tree[[1, 2]].size  ).to be 2
          expect( Sycamore::Tree[[1, 2, :foo]] ).to include_nodes_with 1, 2, :foo
        end
      end
    end

    context 'when given multiple arguments' do
      context 'when none of the arguments is an Enumerable' do
        it 'does initialize the new tree with the given values' do
          expect( Sycamore::Tree[1, 2]       ).to include_nodes_with 1, 2
          expect( Sycamore::Tree[1, 2, 2]    ).to include_nodes_with 1, 2
          expect( Sycamore::Tree[1, 2].size  ).to be 2
          expect( Sycamore::Tree[1, 2, :foo] ).to include_nodes_with 1, 2, :foo
        end
      end

      context 'when some argument is an Enumerable' do
        it 'does raise an NestedNodeSet exception' do
          expect { Sycamore::Tree[[1, 2], [3, 4]] }.to raise_error Sycamore::NestedNodeSet
          expect { Sycamore::Tree[[1], [2]] }.to raise_error Sycamore::NestedNodeSet
        end
      end
    end

    context 'when given a hash argument' do
      subject { Sycamore::Tree[a: 1, b: 2] }
      it { is_expected.to include :a }
      it { is_expected.to include :b }
    end
  end


  ################################################################
  # Child construction
  ################################################################

  describe '#new_child' do
    let(:tree) { Sycamore::Tree.new }
    let(:subclass) { Class.new(Sycamore::Tree) }

    subject { tree.new_child }

    context 'when no child constructor defined' do

      it { is_expected.to eql Sycamore::Tree.new }

      context 'on a subclass' do
        let(:tree) { subclass.new }
        it { is_expected.to eql subclass.new }
      end
    end

    context 'when a child constructor defined' do

      context 'when the child constructor is a Tree class' do
        let(:tree_class) { Class.new(Sycamore::Tree) }

        before(:each) { tree.child_constructor = tree_class }

        it { is_expected.to eql tree_class.new }

        context 'on a subclass' do
          let(:tree) { subclass.new }
          it { is_expected.to eql tree_class.new }
        end

      end

      context 'when a child prototype Tree instance defined' do
        pending 'Tree#clone'
      end

      context 'when a child constructor Proc defined' do

        before(:each) do
          tree.def_child_generator { Sycamore::Tree[42] }
        end

        it { is_expected.to be === Sycamore::Tree[42] }

        context 'on a subclass' do
          let(:tree) { subclass.new }
          it { is_expected.to be === subclass[42] }
        end

      end

    end

  end

  describe '#child_constructor' do
    let(:tree) { Sycamore::Tree.new }

    specify { expect { tree.child_constructor = 'foo' }.to raise_error ArgumentError }

    context 'when a tree class' do

      context 'when not a Tree subclass' do
        specify { expect { tree.child_constructor = String }.to raise_error ArgumentError }
      end

      context 'when a Tree subclass' do
        let(:tree_class) { Class.new(Sycamore::Tree) }
        before { tree.child_constructor = tree_class }
        specify { expect(tree.child_constructor).to eql tree_class }
        specify { expect(tree.child_class).to eql tree_class }
      end

    end

    context 'when a generator proc' do
      before(:each) do
        tree.def_child_generator { Tree[42] }
      end

      specify { expect(tree.child_constructor).to be_a Proc }
      specify { expect(tree.child_generator).to be_a Proc }
      specify { expect(tree.child_constructor.call).to be === Tree[42] }
    end

  end


  ########################################################################
  # Absence and Nothing predicates
  ########################################################################

  describe '#nothing?' do
    it 'does return false' do
      expect(Tree.new.nothing?).to be false
    end
  end

  describe '#present?' do
    it 'does return true' do
      expect(Tree.new.present?).to be true
    end
  end

  describe '#absent?' do
    it 'does return false' do
      expect(Tree.new.absent?).to be false
    end
  end


  ############################################################################
  # general nodes and children access
  ############################################################################

  #####################
  #  query interface  #
  #####################

  describe '#include?' do

    context 'when given a single value' do
      it 'does return true, when the value is in the set of nodes' do
        expect( Sycamore::Tree[1         ].include? 1    ).to be true
        expect( Sycamore::Tree[1, 2      ].include? 1    ).to be true
        expect( Sycamore::Tree[1, 2      ].include? 2    ).to be true
        expect( Sycamore::Tree[42, 'text'].include? 42   ).to be true
        expect( Sycamore::Tree[foo: :bar ].include? :foo ).to be true
      end

      it 'does return false, when the value is not in the set of nodes' do
        expect( Sycamore::Tree[         ].include?(number) ).to be false
        expect( Sycamore::Tree[1        ].include? 2       ).to be false
        expect( Sycamore::Tree[1, 2     ].include? [1, 3]  ).to be false
        expect( Sycamore::Tree[foo: :bar].include? :bar    ).to be false
      end

      context 'edge cases' do
        specify { expect( Sycamore::Tree[false].include? false).to be true }
        specify { expect( Sycamore::Tree[0    ].include? 0    ).to be true }
        specify { expect( Sycamore::Tree[''   ].include? ''   ).to be true }
      end
    end

    context 'when given an array, as a single Enumerable' do
      it 'does return true, when all elements are in the set of nodes' do
        expect( Sycamore::Tree[1, 2      ].include? [1     ] ).to be true
        expect( Sycamore::Tree[1, 2      ].include? [1, 2  ] ).to be true
        expect( Sycamore::Tree[1, 2      ].include? [2, 1  ] ).to be true
        expect( Sycamore::Tree[1, 2, 3   ].include? [1, 2  ] ).to be true
        expect( Sycamore::Tree[:a, :b, :c].include? [:c, :a] ).to be true
      end

      it 'does return false, when some elements are not in the set of nodes' do
        expect( Sycamore::Tree[            ].include? [1        ] ).to be false
        expect( Sycamore::Tree[1, 2        ].include? [3        ] ).to be false
        expect( Sycamore::Tree[1, 2        ].include? [1, 3     ] ).to be false
        expect( Sycamore::Tree[:a, :b, :c  ].include? [:a, :b, 1] ).to be false
        expect( Sycamore::Tree[a: :b, c: :d].include? [:a, :d   ] ).to be false
      end
    end

    context 'when given a hash' do

      context 'when a matching tree structure of nodes with equally structured values' do
        context 'hash contains one key-value-pair' do
          specify { expect( Sycamore::Tree[1 => 2].include?(1 => 2) ).to be true }
          specify { expect( Sycamore::Tree[1 => 2].include?(1 => nil) ).to be true }
          specify { expect( Sycamore::Tree[1 => 2].include?(1 => Sycamore::Nothing) ).to be true }
          specify { expect( Sycamore::Tree[1 => 2].include?(1 => { 2 => nil }) ).to be true }
          specify { expect( Sycamore::Tree[1 => 2].include?(1 => { 2 => Sycamore::Nothing }) ).to be true }
          specify { expect( Sycamore::Tree[1 => [2, 3]].include?(1 => 2) ).to be true }
          specify { expect( Sycamore::Tree[1 => 2, 3 => 1].include?(1 => 2) ).to be true }
        end

        context 'hash contains multiple key-value-pairs' do
          specify { expect( Sycamore::Tree[1 => 2, 3 => 1].include?(1 => 2, 3 => 1) ).to be true }
          specify { expect( Sycamore::Tree[1 => [2, 3], 3 => 1].include?(1 => 2, 3 => 1) ).to be true }
          specify { expect( Sycamore::Tree[1 => [2, 3], 3 => 1].include?(1 => 2, 3 => nil) ).to be true }
          specify { expect( Sycamore::Tree[1 => [2, 3], 3 => 1].include?(1 => 2, 3 => Sycamore::Nothing) ).to be true }
        end
      end

      context 'when only partially matching tree structure of nodes with equally structured values' do
        specify { expect( Sycamore::Tree[1].include?(1 => 2) ).to be false }
        specify { expect( Sycamore::Tree[1 => 2].include?(1 => [2, 3]) ).to be false }
        specify { expect( Sycamore::Tree[1 => 2].include?(1 => 2, 3 => 1) ).to be false }
      end

      context 'when no matching tree structure of nodes with equally structured values' do
        specify { expect( Sycamore::Tree[].include?(1 => 2) ).to be false }
        specify { expect( Sycamore::Tree[42 => 2].include?(1 => 2) ).to be false }
      end

    end

    context 'when given another Tree' do
      pending '#include? with another Tree' # TODO: Should we duplicate all of above specs (for atom, array, hash) with the args converted to a Tree?
      # specify { expect( Tree[1,2].include? Tree[1] ).to be true }
      # specify { expect( Tree[1,2].include? Tree[2] ).to be true }
      # specify { expect( Tree[1,2].include? Tree[1] ).to be true }
      # specify { expect( Tree[1,2].include? Tree[1, 2] ).to be true }
      # specify { expect( Tree[1,2].include? Tree[1, 3] ).to be false }
    end


  end

  ############################################################################

  # TODO: Replace RSpec yield matchers! All?

  describe '#each' do

    context 'when a block given' do
      context 'when empty' do
        specify { expect { |b| Sycamore::Tree[].each(&b) }.not_to yield_control }
      end

      context 'when the block has arity 2' do

        context 'when having one leaf' do
          specify { expect { |b| Sycamore::Tree[1].each(&b) }.to yield_with_args([1, nil]) } #
          specify { pending ; expect { |b| Sycamore::Tree[1].each(&b) }.to yield_with_args(1, nil) }
          specify { pending '???' ; expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args(1, Sycamore::Tree[2]) }
          # specify { pending 'this calls implicitely to_a' ; expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args([1, Tree[2]]) }
          # specify { expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args(1, Sycamore::Tree[2]) }
          specify { expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args([1, Sycamore::Tree[2]]) }
          specify { expect { |b| Sycamore::Tree[1].each(&b) }.to yield_control.exactly(1).times }
          specify { expect { |b| Sycamore::Tree[1].each(&b) }.to yield_successive_args([1, nil]) }
        end

        context 'when having more leaves' do
          specify { expect { |b| Sycamore::Tree[1,2,3].each(&b) }.to yield_control.exactly(3).times }
          specify { expect { |b| Sycamore::Tree[1,2,3].each(&b) }.to yield_successive_args([1, nil], [2, nil], [3, nil]) }
        end

        context 'when having nodes with children' do
          # specify { expect( Tree[a: 1, b: nil].size ).to be 2 }
        end

      end

      context 'when the block has arity <=1' do

        context 'when having one leaf' do
          specify { pending 'replace RSpec yield matchers' ; expect { |b| Sycamore::Tree[1].each(&b) }.to yield_with_args(1) } #
          specify { pending 'replace RSpec yield matchers' ; expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args(1) }
          # specify { pending 'this calls implicitely to_a' ; expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args([1, Sycamore::Tree[2]]) }
          # specify { expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args(1, Sycamore::Tree[2]) }
          specify { expect { |b| Sycamore::Tree[1 => 2].each(&b) }.to yield_with_args([1, Sycamore::Tree[2]]) }
        end

        context 'when having more leaves' do
        end

        context 'when having nodes with children' do
          # specify { expect( Sycamore::Tree[a: 1, b: nil].size ).to be 2 }
        end

      end


    end

    context 'when no block given' do

    end

  end

  ############################################################################

  describe '#each_path' do
    specify { expect(Sycamore::Tree[1     ].paths.to_a ).to eq [Sycamore::Path[1]] }
    specify { expect(Sycamore::Tree[1,2   ].paths.to_a ).to eq [Sycamore::Path[1], Sycamore::Path[2]] }
    specify { expect(Sycamore::Tree[1 => 2].paths.to_a ).to eq [Sycamore::Path[1, 2]] }
    specify { expect(Sycamore::Tree[1 => { 2 => [3, 4] }].paths.to_a )
             .to eq [Sycamore::Path[1, 2, 3], Sycamore::Path[1, 2, 4]] }
  end

  ############################################################################

  describe '#path?' do

    context 'when given a Path' do
      specify { expect( Tree[].path? Path[] ).to be true }
      specify { expect( Tree[].path? Path[42] ).to be false }
      specify { expect( Tree[].path? Path[1,2,3] ).to be false }

      specify { expect( Tree[1 => 2].path?(Sycamore::Path(1))).to be true }
      specify { expect( Tree[1 => 2].path?(Sycamore::Path(2))).to be false }
      specify { expect( Tree[1 => 2].path?(Sycamore::Path(1, 2))).to be true }
    end

    context 'when given a single atom' do
      specify { expect( Tree[1 => 2].path?(1) ).to be true }
      specify { expect( Tree[1 => 2].path?(2) ).to be false }
    end

    context 'when given a sequence of atoms' do

      context 'when given a single Enumerable' do
        specify { expect( Tree[prop1: 1, prop2: [:foo, :bar]].path?(:prop2, :foo) ).to be true }
        specify { expect( Tree[1 => 2].path?([1, 2])     ).to be true }
        specify { expect( Tree[1 => 2].path?([1, 2, 3])  ).to be false }
        specify { expect( Tree[1 => 2].path?([1, 2, 3])  ).to be false }
        specify { expect( Tree['1' => '2'].path?([1, 2]) ).to be false }
      end

      context 'when given multiple arguments' do
        specify { expect( Tree[prop1: 1, prop2: [:foo, :bar]].path?(:prop2, :foo) ).to be true }
        specify { expect( Tree[1 => 2].path?(1, 2)     ).to be true }
        specify { expect( Tree[1 => 2].path?(1, 2, 3)  ).to be false }
        specify { expect( Tree[1 => 2].path?(1, 2, 3)  ).to be false }
        specify { expect( Tree['1' => '2'].path?(1, 2) ).to be false }
      end
    end

    context 'when no arguments given' do
      it 'raises an ArgumentError' do
        expect { Tree.new.path? }.to raise_error ArgumentError
      end
    end

  end

  ############################################################################

  describe '#empty?' do
    it 'does return true, when the Tree has no nodes' do
      expect( Sycamore::Tree.new.empty?               ).to be true
      expect( Sycamore::Tree[nil              ].empty?).to be true
      expect( Sycamore::Tree[Sycamore::Nothing].empty?).to be true
    end

    it 'does return false, when the Tree has nodes' do
      expect( Sycamore::Tree[42              ].empty? ).to be false
      expect( Sycamore::Tree[[42]            ].empty? ).to be false
      expect( Sycamore::Tree[property: :value].empty? ).to be false
    end
  end

  ############################################################################

  describe '#size' do
    context 'when empty' do
      specify { expect( Sycamore::Tree.new.size ).to be 0 }
    end

    context 'when having one leaf' do
      specify { expect( Sycamore::Tree[number].size ).to be 1 }
    end

    context 'when having more leaves' do
      specify { expect( Sycamore::Tree[symbol, number, string].size ).to be 3 }
    end

    context 'when having nodes with children' do
      specify { expect( Sycamore::Tree[a: 1, b: nil].size ).to be 2 }
    end
  end


  #####################
  # command interface #
  #####################

  describe '#add' do

    context 'when a single atom value argument given' do
      let(:atom) { number }
      subject { Sycamore::Tree[] << atom }
      it { is_expected.to include_node_with atom }
    end

    context 'when a single Enumerable argument given' do
      let(:enumerable) { [symbol, number, string] }
      subject { Sycamore::Tree[] << enumerable }
      it { is_expected.to include_nodes_with enumerable }
    end

    context 'when a tree-like structure given' do
      let(:tree) { { symbol => number } }
      subject { Tree[] << tree }
      it { is_expected.to include_tree_with tree }

      context 'when the key is false' do
        let(:tree) { { false => number } }
        subject { Sycamore::Tree[] << tree }
        it { is_expected.to include_tree_with tree }
      end
    end

    context 'when given multiple atoms' do
      let(:enumerable) { [symbol, number, string] }
      subject { pending 'Can/should we support multiple arguments as an Enumerable?' ; Sycamore::Tree[].add(*enumerable) }
      it { is_expected.to include_nodes_with enumerable }
    end

    # from #add_node and #add_nodes; TODO: order and possibly restructure them

    context 'when given nil' do
      subject { Sycamore::Tree[] << nil }
      it { is_expected.to be_empty }
      it { is_expected.not_to be_a Sycamore::Absence }
    end

    context 'when given multiple nils' do
      subject { Sycamore::Tree[].add([nil, nil, nil]) }
      it { is_expected.to be_empty }
    end

    context 'when given nils and non-nil atoms' do
      subject { Sycamore::Tree[].add([nil, :foo, nil]) }
      it { is_expected.not_to be_empty }
      it { is_expected.to include_node_with :foo }
      it { expect(subject.size).to be 1 }
    end

    context 'when given Nothing' do
      subject { Sycamore::Tree[] << Sycamore::Nothing }
      it { is_expected.to be_empty }
      it { is_expected.not_to be_a Sycamore::Absence }
    end

    context 'when given false' do
      subject { Sycamore::Tree[] << false }
      it { is_expected.not_to be_empty }
      it { is_expected.to include_node_with false }
    end

    context 'when given a single atom' do
      context 'when a corresponding node for this atom is absent' do
        specify { expect( Sycamore::Tree[] << :a ).to include_node_with(:a) }
      end

      context 'when a corresponding node for this atom is present' do
        specify { expect(Sycamore::Tree[a: 1].add(:a)).to include_tree_with(a: 1) }
      end
    end

    context 'when given a single Enumerable' do
      let(:enumerable) { [symbol, number, string] }
      subject { Sycamore::Tree.new.add(enumerable) }
      it { is_expected.to include_nodes_with enumerable }
    end

    context 'when given a nested Enumerable' do
      context 'when the nested Enumerable is Tree-like' do
        specify { expect(Sycamore::Tree[:a, b: 1]         === {a: nil, b: 1}       ).to be true }
        specify { expect(Sycamore::Tree[:b,  a: 1, c: 2 ] === {a: 1, b: nil, c: 2} ).to be true }
        specify { expect(Sycamore::Tree[:b, {a: 1, c: 2}] === {a: 1, b: nil, c: 2} ).to be true }
        specify { expect(Sycamore::Tree[:a, b: {c: 2}   ] === {a: nil, b: {c: 2}}  ).to be true }
      end

      context 'when the nested Enumerable is not Tree-like' do
        # @todo https://www.pivotaltracker.com/story/show/94733228
        #   Do we really need this? If so, document the reasons!
        it 'raises an error' do
          expect { Sycamore::Tree.new.add([1, [2, 3]]) }.to raise_error(Sycamore::NestedNodeSet)
        end

      end
    end

  end


  describe '#delete' do
    context 'when given nil' do
      let(:nodes) { [:foo] }
      subject(:tree) { Sycamore::Tree[nodes].delete(nil) }

      it { is_expected.to include nodes }
      it { expect(tree.size).to be 1 }
    end

    context 'when given Nothing' do
      let(:nodes) { [42, :foo] }
      subject(:tree) { Sycamore::Tree[nodes].delete(Sycamore::Nothing) }

      it { is_expected.to include nodes }
      it { expect(tree.size).to be 2 }
    end

    context 'when given Absence' do
      pending
    end

    context 'when given a single atom' do
      context 'when the given node is in this tree' do
        let(:nodes) { [42, :foo] }
        subject(:tree) { Sycamore::Tree[nodes].delete(42) }

        it { is_expected.not_to include 42 } # This relies on Tree#each
        it { expect(tree.include?(42)).to be false }
        it { is_expected.to include :foo }

        it 'does decrease the size' do
          expect(tree.size).to be nodes.size - 1
        end
      end

      context 'when the given node is not in this tree' do
        let(:initial_nodes) { [:foo] }
        subject(:tree) { Sycamore::Tree[initial_nodes].delete(42) }

        it { expect(tree.include? 42).to be false }
        it { is_expected.not_to include 42 } # This relies on Tree#each
        it { expect(tree.include? :foo).to be true }
        it { is_expected.to include :foo }

        it 'does not decrease the size' do
          expect(tree.size).to be initial_nodes.size
        end
      end
    end

    context 'when given a collection of atoms' do
      context 'when all of the given node are in this tree' do
        let(:initial_nodes)       { [:foo, :bar] }
        let(:nodes_to_be_deleted) { [:foo, :bar] }

        subject(:tree) { Sycamore::Tree[initial_nodes].delete(nodes_to_be_deleted) }

        it 'does not include any of the deleted nodes' do
          nodes_to_be_deleted.each { |node| is_expected.not_to include node }
        end

        it 'does decrease the size' do
          expect(tree.size).to be initial_nodes.size - nodes_to_be_deleted.size
        end
      end

      context 'when some, but not all of the given node are in this tree' do
        let(:initial_nodes)       { [42, :foo] }
        let(:nodes_to_be_deleted) { [:foo, :bar] }

        subject(:tree) { Sycamore::Tree[initial_nodes].delete(nodes_to_be_deleted) }

        it { expect(tree.include? 42).to be true }
        it { is_expected.to include 42 } # This relies on Tree#each
        it { expect(tree.include? :foo).to be false }
        it { is_expected.not_to include :foo }

        it 'does not decrease the size' do
          expect(tree.size).to be 1
        end
      end

      context 'when none of the given node are in this tree' do
        let(:initial_nodes)       { [1, 2] }
        let(:nodes_to_be_deleted) { [:foo, :bar] }

        subject(:tree) { Sycamore::Tree[initial_nodes].delete(nodes_to_be_deleted) }

        it 'does not decrease the size' do
          expect(tree.size).to be initial_nodes.size
        end
      end

      context 'when given a nested Enumerable' do
        context 'when the nested Enumerable is Tree-like' do
          specify { expect(Sycamore::Tree[a: 1, b: 2].delete([:a, b: 2]) ).to be_empty }
          specify { expect(Sycamore::Tree[a: 1, b: [2, 3]].delete([:a, b: 2]) === {b: 3} ).to be true }
        end

        context 'when the nested Enumerable is not Tree-like' do
          # @todo https://www.pivotaltracker.com/story/show/94733228
          #   Do we really need this? If so, document the reasons!
          it 'raises an error' do
            expect { Sycamore::Tree.new.delete([1, [2, 3]]) }.to raise_error(Sycamore::NestedNodeSet)
          end
        end

      end

    end

  end

  ############################################################################

  describe '#clear' do

    context 'when empty' do
      subject(:empty_tree) { Sycamore::Tree[] }
      specify { expect { empty_tree.clear }.not_to change(empty_tree, :size) }
      specify { expect { empty_tree.clear }.not_to change(empty_tree, :nodes) }
    end

    context 'when not empty' do
      let(:nodes) { [42, :foo] }
      subject { Sycamore::Tree[nodes].clear }

      it { is_expected.to be_empty }

      it 'does delete all nodes' do
        nodes.each do |node|
          expect(subject.include?(node)).to be false
          expect(subject).not_to include(node) # This relies on Tree#each
        end
      end
    end

  end


  ################################################################
  # Nodes API                                                    #
  ################################################################

  #####################
  #  query interface  #
  #####################

  describe '#nodes' do

    shared_examples 'result invariants' do
      it { is_expected.to be_an Enumerable }
      it { is_expected.to be_an Array } # ; TODO: skip 'Should we expect nodes to return an Array? Why?' }
    end

    context 'when empty' do
      subject { Sycamore::Tree[].nodes }
      include_examples 'result invariants'
      it { is_expected.to be_empty }
    end

    context 'when containing a single leaf node' do
      let(:atom) { symbol }
      subject { Sycamore::Tree[atom].nodes }
      include_examples 'result invariants'
      it { is_expected.to contain_exactly atom }
    end

    context 'when containing multiple nodes' do

      context 'without children, only leaves' do
        let(:leaves) { [:foo, :bar, :baz] }
        subject(:nodes) { Sycamore::Tree[leaves].nodes }
        include_examples 'result invariants'

        it 'does return the nodes unordered' do
          expect(nodes.to_set).to eq leaves.to_set
        end

        specify { expect(Sycamore::Tree[:foo, :bar, :baz, :foo, :bar, :baz].nodes.to_set).to eq leaves.to_set }
        specify { expect(Sycamore::Tree['foo', 'bar', 'baz', 'foo', 'bar'].nodes.to_set).to eq Set['foo', 'bar', 'baz'] }
      end

      context 'with children' do
        let(:tree) { { foo: 1, bar: 2, baz: nil } }
        subject(:nodes) { Sycamore::Tree[tree].nodes }
        include_examples 'result invariants'

        specify { expect(nodes.to_set).to eq tree.keys.to_set }
      end

    end

    context 'when another depth than the default 0 given' do
      it 'does merge the nodes of all children down to the given tree depth'
    end

  end


  describe '#node' do

    shared_examples 'result invariants' do
      it { is_expected.not_to be_an Enumerable }
    end

    context 'when empty' do
      subject { Sycamore::Tree[].node }
      include_examples 'result invariants'
      it { is_expected.to be_nil }
    end

    context 'when containing a single leaf node' do
      let(:atom) { symbol }
      subject { Sycamore::Tree[atom].node }
      include_examples 'result invariants'
      it { is_expected.to eq atom }
    end


    context 'when containing multiple nodes' do
      context 'when no reduce function specified' do
        it 'does raise a TypeError' do
          expect { Sycamore::Tree[:foo, :bar].node }.to raise_error TypeError
          expect { Sycamore::Tree[foo: 1, bar: 2, baz: nil].node }.to raise_error TypeError
        end
      end

      context 'when a reducer or selector function specified' do
        it 'does return the application of reduce function on the node set' do
          pending
          expect( Sycamore::Tree[1,2,3].node(&:max) ).to eq 3
          expect( Sycamore::Tree[1,2,3]
                    .node { |nodes| nodes.reduce { |value, sum| sum += value } }
                ).to eq 6
        end
      end
    end

    context 'when another depth than the default 0 given' do
      it 'does merge the nodes of all children down to the given tree depth'
    end

  end

  ################################################################
  # Children API                                                 #
  ################################################################

  #####################
  #  query interface  #
  #####################

  describe '#child' do

    context 'when given a single argument' do

      context 'edge cases' do
        context 'when the argument is nil' do
          specify { expect( Tree.new.child_of(nil) ).to be Sycamore::Nothing }
        end

        context 'when the argument is Nothing' do
          specify { expect(Tree.new.child_of(Sycamore::Nothing)).to be Sycamore::Nothing }
        end

        context 'when the argument is false' do
          specify { expect( Tree.new.child_of(false) ).to be_a Sycamore::Absence }
          specify { expect( Tree.new.child_of(false) ).not_to be_nothing }
          specify { expect( Tree.new.child_of(false) ).to be_absent }

          specify { expect( Tree[false => :foo].child_of(false) ).not_to be Sycamore::Nothing }
          specify { expect( Tree[false => :foo].child_of(false) ).not_to be_absent }
          specify { expect( Tree[false => :foo].child_of(false) ).to include :foo }

          specify { expect( Tree[4 => {false => 2}].child_of(4) ).to eq Tree[false => 2] }
          specify { expect( Tree[4 => {false => 2}].child_of(4).child_of(false) ).not_to be_a Sycamore::Absence }
          specify { expect( Tree[4 => {false => 2}].child_of(4).child_of(false) ).to eq Tree[2] }
        end
      end

      context 'when a corresponding node is present' do

        context 'when the node has a child' do
          let(:root) { Sycamore::Tree.new.add_child(:property, :value) }
          let(:child) { root[:property] }

          describe 'root' do
            subject { root }
            it { is_expected.to include :property }
            it { is_expected.not_to include :value } # This relies on Tree#each
            it { expect( root.include?(:value) ).to be false }
          end

          describe 'child' do
            subject { child }
            it { is_expected.to be_a Sycamore::Tree }
            it { is_expected.not_to be Sycamore::Nothing }
            it { is_expected.not_to be_nothing }
            it { is_expected.not_to be_absent }
            it { is_expected.to include :value }
            it { is_expected.not_to include :property } # This relies on Tree#each
            it { expect( child.include?(:property) ).to be false }
          end
        end

        context 'when the node is a leaf' do
          let(:root) { Sycamore::Tree[42] }
          let(:child) { root.child_of(42) }

          # TODO: Really the same behaviour as when node absent?

          describe 'root' do
            subject { root }
            it { is_expected.to include 42 }
          end

          describe 'child' do
            subject { child }
            it { is_expected.to be_a Sycamore::Absence }
            it { is_expected.to be_absent }
            # it { is_expected.to be_a Sycamore::Tree }
            # it { is_expected.to be Sycamore::Nothing }
          end

        end
      end

      context 'when a corresponding node is absent' do

        # see Tree-Absence interaction spec

        # TODO: Really the same behaviour as when node is a leaf?
      end

    end

  end

  ############################################################################

  describe '#fetch' do

    context 'when given a single atom' do

      context 'when the given atom is nil' do
        specify { expect { Sycamore::Tree[].fetch(nil) }.to raise_error KeyError }
      end

      context 'when the given atom is Nothing' do
        specify { expect { Sycamore::Tree[].fetch(Nothing) }.to raise_error KeyError }
      end

      context 'when the given atom is a boolean' do
        specify { expect { Sycamore::Tree[].fetch(true) }.to raise_error KeyError }
        specify { expect { Sycamore::Tree[].fetch(false) }.to raise_error KeyError }
        specify { expect( Sycamore::Tree[true].fetch(true) ).to be Sycamore::Nothing }
        specify { expect( Sycamore::Tree[false].fetch(false) ).to be Sycamore::Nothing }
      end

      context 'when a corresponding node is present' do
        subject(:tree) { Sycamore::Tree[property: :value] }
        specify { expect( tree.fetch(:property) ).to be tree.child_of(:property) }

        context 'when the node is a leaf' do
          specify { expect( Sycamore::Tree[42].fetch(42) ).to be Sycamore::Nothing }
        end
      end

      context 'when a corresponding node is absent' do
        specify { expect { Sycamore::Tree[].fetch(42) }.to raise_error KeyError }
      end

    end

    context 'when given an atom and a default value' do

      context 'when the given atom is nil' do
        specify { expect( Sycamore::Tree[].fetch(nil, :default) ).to eq :default }
      end

      context 'when the given atom is Nothing' do
        specify { expect( Sycamore::Tree[].fetch(Nothing, :default) ).to eq :default }
      end

      context 'when the given atom is a boolean' do
        specify { expect( Sycamore::Tree[     ].fetch(true,  :default) ).to eq :default }
        specify { expect( Sycamore::Tree[     ].fetch(false, :default) ).to eq :default }
        specify { expect( Sycamore::Tree[true ].fetch(true,  :default) ).to be Sycamore::Nothing }
        specify { expect( Sycamore::Tree[false].fetch(false, :default) ).to be Sycamore::Nothing }
      end

      context 'when a corresponding node is present' do
        subject(:tree) { Sycamore::Tree[property: :value] }
        specify { expect( tree.fetch(:property, :default) ).to be tree.child_of(:property) }

        context 'when the node is a leaf' do
          specify { expect( Sycamore::Tree[:property].fetch(:property, :default) ).to be Sycamore::Nothing }
        end
      end

      context 'when a corresponding node is absent' do
        specify { expect( Sycamore::Tree[].fetch(42, "default") ).to eq "default" }
      end

    end

    context 'when given an atom and a block' do

      context 'when the given atom is nil' do
        specify { expect( Sycamore::Tree[].fetch(nil) { 42 } ).to eq 42 }

      end

      context 'when the given atom is Nothing' do
        specify { expect( Sycamore::Tree[].fetch(Nothing) { 42 } ).to eq 42 }
      end

      context 'when the given atom is a boolean' do
        specify { expect( Sycamore::Tree[     ].fetch(true ) { 42 } ).to eq 42 }
        specify { expect( Sycamore::Tree[     ].fetch(false) { 42 } ).to eq 42 }
        specify { expect( Sycamore::Tree[true ].fetch(true)  { 42 } ).to be Sycamore::Nothing }
        specify { expect( Sycamore::Tree[false].fetch(false) { 42 } ).to be Sycamore::Nothing }
      end

      context 'when a corresponding node is present' do
        subject(:tree) { Sycamore::Tree[property: :value] }
        specify { expect( tree.fetch(:property) { 42 } ).to be tree.child_of(:property) }

        context 'when the node is a leaf' do
          specify { expect( Sycamore::Tree[:property].fetch(:property) { 42 } ).to be Sycamore::Nothing }
        end
      end

      context 'when a corresponding node is absent' do
        specify { expect( Sycamore::Tree[].fetch(:property) { 42 } ).to eq 42 }
      end

    end

    context 'when given an atom, a default value and a block' do

      context 'when the given atom is nil' do
        specify { expect( Sycamore::Tree[].fetch(nil, :default) { 42 } ).to eq 42 }

      end

      context 'when the given atom is Nothing' do
        specify { expect( Sycamore::Tree[].fetch(Nothing, :default) { 42 } ).to eq 42 }
      end

      context 'when the given atom is a boolean' do
        specify { expect( Sycamore::Tree[     ].fetch(true,  :default) { 42 } ).to eq 42 }
        specify { expect( Sycamore::Tree[     ].fetch(false, :default) { 42 } ).to eq 42 }
        specify { expect( Sycamore::Tree[true ].fetch(true,  :default) { 42 } ).to be Sycamore::Nothing }
        specify { expect( Sycamore::Tree[false].fetch(false, :default) { 42 } ).to be Sycamore::Nothing }
      end

      context 'when a corresponding node is present' do
        subject(:tree) { Sycamore::Tree[property: :value] }
        specify { expect( tree.fetch(:property, :default) { 42 } ).to be tree.child_of(:property) }

        context 'when the node is a leaf' do
          specify { expect( Sycamore::Tree[:property].fetch(:property, :default) { 42 } ).to be Sycamore::Nothing }
        end
      end

      context 'when a corresponding node is absent' do
        specify { expect( Sycamore::Tree[].fetch(:property) { 42 } ).to eq 42 }
      end

    end

  end

  ############################################################################

  describe '#leaf?' do

    context 'when given a single atom' do

      context 'when the given atom is nil' do
        specify { expect( Tree[].leaf?(nil) ).to be false }
      end

      context 'when the given atom is Nothing' do
        specify { expect(Tree[].leaf?(Sycamore::Nothing)).to be false }
      end

      context 'when the corresponding node is present' do

        context 'when the corresponding node is a leaf' do
          specify {
            expect( Tree[1                     ].leaf?(1) ).to be true
            expect( Tree[1 => nil              ].leaf?(1) ).to be true
            expect( Tree[1 => Sycamore::Nothing].leaf?(1) ).to be true
            expect( Tree[1 => :foo, 2 => nil   ].leaf?(2) ).to be true
          }
        end

        context 'when the corresponding node has a child' do
          specify { expect(Tree[1 => :foo].leaf?(1)).to be false }
          specify { expect(Tree[1 => :foo, 2 => nil].leaf?(1)).to be false }
        end

        context 'when the corresponding node has a child, but it is empty' do
          specify do
            tree = Tree[1 => :foo]
            tree[1].clear
            expect(tree.leaf?(1)).to be true
          end

          specify do
            tree = Tree[1 => :foo, 2 => nil]
            tree[1].clear
            expect(tree.leaf?(1)).to be true
          end
        end

      end

      context 'when the corresponding node is absent' do
        specify { expect( Tree.new.leaf?(42)   ).to be false }
        specify { expect( Tree[43].leaf?(42) ).to be false }
      end

    end

  end

  ############################################################################

  describe '#leaves?' do

    context 'without arguments' do
      context 'when all nodes are leaves' do
        specify { expect( Tree[]                       ).to be_leaves }
        specify { expect( Tree[1]                      ).to be_leaves }
        specify { expect( Tree[1 => nil]               ).to be_leaves }
        specify { expect( Tree[1 => Sycamore::Nothing] ).to be_leaves }
        specify { expect( Tree[1, 2, 3]                ).to be_leaves }
        specify { expect( Tree[1 => 2].child_of(1)        ).to be_leaves }
      end

      context 'when some nodes are not leaves' do
        specify { expect( Tree[1 => 2]).not_to be_leaves }
        specify { expect( Tree[1 => :a, 2 => nil, 3 => nil]).not_to be_leaves }
        specify { expect( Tree[1 => :a, 2 => Sycamore::Nothing, 3 => Sycamore::Nothing]).not_to be_leaves }
      end
    end

    context 'when given a single atom' do
      # see #leaf?
    end

    context 'when given an Enumerable (by one enumerable argument or multiple atomic arguments)' do

      context 'when all corresponding nodes of the Enumerable are present and leaves' do
        specify { expect(Sycamore::Tree[1,2,3].leaves?([1,2,3])).to be true }
        specify { expect(Sycamore::Tree[1,2,3].leaves?(1,2,3)).to be true }
        specify { expect(Sycamore::Tree[1 => nil, 2 => nil, 3 => nil].leaves?(1,2,3)).to be true }
      end

      context 'when all corresponding nodes of the Enumerable are present, but some have a child' do
        specify { expect(Sycamore::Tree[1 => :a, 2 => nil, 3 => nil].leaves?([1,2,3])).to be false }
      end

      context 'when some corresponding nodes of the Enumerable are absent or have a child' do
        specify { expect( Sycamore::Tree[1,2].leaves?(1,2,3)             ).to be false }
        specify { expect( Sycamore::Tree[1 => :a, 2 => nil].leaves?(1,2) ).to be false }
        specify { expect( Sycamore::Tree[].leaves?(1,2,3)                ).to be false }
      end

    end


    context 'when given something Tree.like' do
      it 'raises an ArgumentError' do
        expect { Sycamore::Tree.new.leaves?(a: 1) }.to raise_error ArgumentError
      end
    end

  end

  describe '#external?' do
    # see #leaves?
  end

  describe '#internal?' do

    # see #leaves?

    context 'when given a single atom' do
      context 'when the given atom is nil' do
        specify { expect( Sycamore::Tree[].internal?(nil) ).to be false }
        specify { expect( Sycamore::Tree[].external?(nil) ).to be false }
      end

      context 'when the corresponding node is absent' do
        specify { expect( Sycamore::Tree.new.external?(42) ).to be false }
        specify { expect( Sycamore::Tree[43].external?(42) ).to be false }
        specify { expect( Sycamore::Tree.new.internal?(42) ).to be false }
        specify { expect( Sycamore::Tree[43].internal?(42) ).to be false }
      end
    end

    context 'when given something Tree.like' do
      it 'raises an ArgumentError' do
        expect { Sycamore::Tree.new.external?(a: 1) }.to raise_error ArgumentError
        expect { Sycamore::Tree.new.internal?(a: 1) }.to raise_error ArgumentError
      end
    end
  end


  #####################
  # command interface #
  #####################

=begin
  context 'when a corresponding node is present'

  context 'when the node has a child'

=end

  describe '#add_child' do

    describe 'child constructor integration' do
      let(:tree) { Sycamore::Tree.new }
      let(:subclass) { Class.new(Sycamore::Tree) }

      subject(:new_child) { tree.add_child(1, 2)[1] }

      context 'when no child constructor defined' do
        it { is_expected.to eql Sycamore::Tree[2] }

        context 'on a subclass' do
          let(:tree) { subclass.new }
          it { is_expected.to eql subclass.with(2) }
        end
      end


      context 'when a child constructor defined' do

        context 'when a child Tree class defined' do
          let(:tree_class) { Class.new(Sycamore::Tree) }

          before(:each) { tree.child_constructor = tree_class }

          it { is_expected.to eql tree_class.with(2) }

          context 'on a subclass' do
            let(:tree) { subclass.new }
            it { is_expected.to eql tree_class.with(2) }
          end

        end

        context 'when a child prototype Tree instance defined' do
          pending 'Tree#clone'
        end

        context 'when a child constructor Proc defined' do

          before(:each) do
            tree.def_child_generator { Sycamore::Tree[42] }
          end

          it { is_expected.to be === Sycamore::Tree[42, 2] }

          context 'on a subclass' do
            let(:tree) { subclass.new }
            it { is_expected.to be === subclass[42, 2] }
          end

        end
      end
    end




    context 'when the given node is nil' do
      subject { Tree[].add_child(nil, 42) }
      it { is_expected.to be_empty }
    end

    context 'when the given node is Nothing' do
      subject { Tree[].add_child(Sycamore::Nothing, 42) }
      it { is_expected.to be_empty }
    end

    # context 'when the given child is an Absence' do
    #   subject { Tree[].add_child(42, Tree[].child(:absent)) }
    #   it { is_expected.not_to be_empty }
    # end


    ###############
    # TODO: Refactor the following

    specify 'some examples for atoms' do
      tree = Sycamore::Tree.new

      tree.add_child(42, 3.14) # => {1 => 3.14}
      expect(tree).to include 42
      expect(tree.size).to be 1
      expect(tree.child_of(42)).to be_a Tree
      expect(tree.child_of(42)).not_to be_nothing
      expect(tree.child_of(42)).to include 3.14
      expect(tree.child_of(42).size).to be 1

      tree.add_child(42, 'text') # => {1 => [3.14, 'text']}
      expect(tree.size).to be 1
      expect(tree.child_of(42)).to include 'text'
      expect(tree.child_of(42).size).to be 2

      tree.add_child(1, nil)
      tree.add_child(42, Sycamore::Nothing) # => {1 => [3.14, 'text']}
      expect(tree.size).to be 2
      expect(tree.child_of(42).size).to be 2

    end


    specify 'some examples for arrays' do
      tree = Sycamore::Tree.new

      tree.add_child(:root, [2, 3]) # => {:root => [2, 3]}
      expect(tree).to include :root
      expect(tree.size).to be 1
      expect(tree.child_of(:root)).to be_a Sycamore::Tree
      expect(tree.child_of(:root)).not_to be_nothing
      expect(tree.child_of(:root)).to include 2
      expect(tree.child_of(:root)).to include 3
      # TODO: expect(tree.child(:root)).to include [2,3]
      expect(tree.child_of(:root).size).to be 2

      tree.add_child(:root, [3, 4, 0]) # => {:root => [2, 3, 4, 0]}
      expect(tree.size).to be 1
      expect(tree.child_of(:root)).to include 4
      expect(tree.child_of(:root)).to include 0
      # TODO: expect(tree.child(:root)).to include [3, 4]
      expect(tree.child_of(:root).size).to be 4

      tree.add_child(:root, []) # => {:root => [2, 3, 4, 0]}
      expect(tree.size).to be 1
      expect(tree.child_of(:root)).to include 4
      expect(tree.child_of(:root)).to include 0
      expect(tree.child_of(:root).size).to be 4

    end

    specify 'some examples when the node is false' do
      tree = Sycamore::Tree.new
      tree.add_child(false, :foo) # => {false => :foo}
      expect(tree.size).to be 1
      expect(tree.child_of(false)).to include :foo
      expect(tree.child_of(false).size).to be 1
    end

    specify 'some examples for hashes' do
      tree = Sycamore::Tree.new

      tree.add_child(:noah, {shem: :elam } ) # => {:noah => {:shem => :elam}}
      expect(tree).to include :noah
      expect(tree.size).to be 1
      expect(tree.child_of(:noah)).to be_a Sycamore::Tree
      expect(tree.child_of(:noah)).not_to be_nothing
      expect(tree.child_of(:noah)).to include :shem
      expect(tree.child_of(:noah).size).to be 1
      expect(tree.child_of(:noah).child_of(:shem)).to be_a Sycamore::Tree
      expect(tree.child_of(:noah).child_of(:shem)).not_to be_nothing
      expect(tree.child_of(:noah).child_of(:shem)).to include :elam
      expect(tree.child_of(:noah).child_of(:shem).size).to be 1

      tree.add_child(:noah, {shem: :asshur,
                             japeth: :gomer,
                             ham: [:cush, :mizraim, :put, :canaan] } )
      # => {:noah => {:shem   => [:elam, :asshur]}
      #              {:japeth => :gomer}
      #              {:ham    => [:cush, :mizraim, :put, :canaan]}}
      expect(tree.size).to be 1
      expect(tree[:noah].size).to be 3
      expect(tree[:noah]).to include :japeth
      expect(tree[:noah]).to include :ham
      expect(tree[:noah][:shem].size).to be 2
      expect(tree[:noah][:shem]).to include :elam
      expect(tree[:noah][:shem]).to include :asshur
      expect(tree[:noah][:japeth].size).to be 1
      expect(tree[:noah][:japeth]).to include :gomer
      expect(tree[:noah][:ham].size).to be 4
      expect(tree[:noah][:ham]).to include :cush
      expect(tree[:noah][:ham]).to include :mizraim
      expect(tree[:noah][:ham]).to include :put
      expect(tree[:noah][:ham]).to include :canaan

      tree << { noah: {shem: :asshur,
                             japeth: :gomer,
                             ham: [:cush, :mizraim, :put, :canaan] } }
      # => {:noah => {:shem   => [:elam, :asshur]}
      #              {:japeth => :gomer}
      #              {:ham    => [:cush, :mizraim, :put, :canaan]}}
      expect(tree.size).to be 1
      expect(tree[:noah].size).to be 3
      expect(tree[:noah]).to include :japeth
      expect(tree[:noah]).to include :ham
      expect(tree[:noah][:shem].size).to be 2
      expect(tree[:noah][:shem]).to include :elam
      expect(tree[:noah][:shem]).to include :asshur
      expect(tree[:noah][:japeth].size).to be 1
      expect(tree[:noah][:japeth]).to include :gomer
      expect(tree[:noah][:ham].size).to be 4
      expect(tree[:noah][:ham]).to include :cush
      expect(tree[:noah][:ham]).to include :mizraim
      expect(tree[:noah][:ham]).to include :put
      expect(tree[:noah][:ham]).to include :canaan

      tree.add_child(:noah, {})
      # => {:noah => {:shem   => [:elam, :asshur]}
      #              {:japeth => :gomer}
      #              {:ham    => [:cush, :mizraim, :put, :canaan]}}
      expect(tree.size).to be 1
      expect(tree.child_of(:noah).size).to be 3
      expect(tree.child_of(:noah).child_of(:shem).size).to be 2
      expect(tree.child_of(:noah).child_of(:japeth).size).to be 1
      expect(tree.child_of(:noah).child_of(:ham).size).to be 4

    end

    specify 'some examples for Trees' do
      tree = Sycamore::Tree.new

    end

=begin
    shared_examples 'for adding a given Atom-like child' do |options = {}|
      let(:initial) { options[:initial] or raise ArgumentError, 'No initial value given.' }
      let(:node)    { options[:node]    or raise ArgumentError, 'No node given.' }
      let(:child)   { options[:child]   or raise ArgumentError, 'No child given.' }

      # TODO: extract from below - Problem: no access to initial, nodes etc.
      # describe 'the added tree' do
      #   subject(:added_child) { tree_with_child.child(node) }
      #   it { is_expected.to be_a Tree }
      #   it { is_expected.to_not be Sycamore::Nothing }
      #   it { is_expected.to_not be tree_with_child }
      #   it { is_expected.to include child }
      #   it 'does add only the nodes of the given child, to the child of the new child tree' do
      #     expect(added_child.size).to be 1
      #   end
      # end
    end

    shared_examples 'for adding a given Collection-like child' do
    end

    shared_examples 'for adding a given Tree-like child' do
    end
=end

    subject(:tree) { Sycamore::Tree[initial] }

    let(:tree_with_child) { tree.add_child(node, child) }

    context 'when the given node is present' do

      context 'when the node does not have already child' do

        context 'when given an Atom-like child' do
          let(:initial) { [1] }
          let(:node)    { 1 }
          let(:child)   { 2 }


          # TODO: extract the general addition examples, independent from the state
          #         into a custom matcher
          # include_examples 'for adding a given Atom-like child',
          #                  initial: [1], node: 1, child: 2


          it { is_expected.to include node }

          describe 'the added tree' do
            subject(:added_child) { tree_with_child.child_of(node) }
            it { is_expected.to be_a Sycamore::Tree }
            it { is_expected.to_not be_nothing }
            it { is_expected.to include child }
            it 'does add only the nodes of the given child, to the child of the new child tree' do
              expect(added_child.size).to be 1
            end
          end

        end

        context 'when the node has already a child' do

          context 'when given an Atom-like child' do
            # include_examples 'for adding a given Atom-like child'
          end
          context 'when given a Collection-like child' do
            # include_examples 'for adding a given Collection-like child'
          end
          context 'when given a Tree-like child' do
            # include_examples 'for adding a given Tree-like child'
          end
        end


        context 'when given a Collection-like child' do
          # include_examples 'for adding a given Collection-like child'
        end
        context 'when given a Tree-like child' do
          # include_examples 'for adding a given Tree-like child'
        end
      end

    end

    # TODO: Should behave the same as 'when a node to the given atom is present'
    context 'when a node to the given atom is absent' do
      let(:initial) { [] }
      let(:node)    { 1 }
      let(:child)   { 2 }


      # TODO: extract the general addition examples, independent from the state
      #         into a custom matcher
      # include_examples 'for adding a given Atom-like child',
      #                  initial: [1], node: 1, child: 2


      it { is_expected.not_to include node }

      describe 'the added tree' do
        subject(:added_child) { tree_with_child.child_of(node) }
        it { is_expected.to be_a Sycamore::Tree }
        it { is_expected.to_not be_nothing }
        it { is_expected.to include child }
        it 'does add only the nodes of the given child, to the child of the new child tree' do
          expect(added_child.size).to be 1
        end
      end

    end

    context 'when the given atom is nil' do
      pending
    end

    context 'when the given atom is Nothing' do
      pending
    end

    context 'when the given atom is an Absence' do
      let(:tree) { Sycamore::Tree[] }
      subject { tree.add_child(:property, Tree[].child_of(42)) }
      it { is_expected.not_to be_empty }
      it { is_expected.to include :property }

      describe 'the child' do
        subject { tree[:property] }
        it { is_expected.to     be_absent }
        # it { is_expected.to     be_nothing }
        it { is_expected.not_to include 42 }
        it { is_expected.to     be_empty }
      end

    end



=begin
    context 'the given node is in the tree as a leaf' do
      let(:initial) { [1] }
      let(:node)    { 1 }
      let(:child)   { 2 }

      describe 'the added tree' do
        subject(:added_child) { tree_with_child.child(node) }
        it { is_expected.to be_a Tree }
        it { is_expected.to_not be Sycamore::Nothing }
        it { is_expected.to_not be tree_with_child }
        it { is_expected.to include child }
        it 'does add only the nodes of the given child, to the child of the new child tree' do
          expect(added_child.size).to be 1
        end
      end

    end
=end

    context 'the given node is not in the tree' do
      let(:initial) { [] }
      let(:node)    { 1 }
      let(:child)   { 2 }

      describe 'the added tree' do
        subject(:added_child) { tree_with_child.child_of(node) }
        it { is_expected.to be_a Sycamore::Tree }
        it { is_expected.to_not be_nothing }
        it { is_expected.to_not be tree_with_child }
        it { is_expected.to include child }
        it 'does add only the nodes of given the given child, to the child of the new child tree' do
          expect(added_child.size).to be 1
        end
      end
    end

    context 'when the given node is in this tree with an existing child tree' do
      let(:initial) { { 1 => 2 } }
      let(:node)    { 1 }
      let(:child)   { 3 }

      describe 'the added tree' do
        subject(:added_child) { tree_with_child.child_of(node) }

        it { is_expected.to be_a Sycamore::Tree }
        it { is_expected.to_not be_nothing }
        it { is_expected.to_not be tree_with_child } # TODO: Needed/Useful?
        it { is_expected.to include child }
        it { is_expected.to include 2 }

        it 'does add only the nodes of given the given child, to the child of the new child tree' do
          expect(added_child.size).to be 2
        end
      end
    end

  end


  ############################################################################

  describe '#add_children' do

=begin
    shared_examples 'when given a flat tree-like structure' do

      subject { Sycamore::Tree.new(initial).add_children(struct) }

      context 'when nodes for certain keys are already present, but are leaves' do
        let(:initial) { 1 }
        let(:struct)  { {1 => 2} }

        it 'creates a new tree, before adding the '
      end

      context 'when nodes for certain keys are not present' do
        let(:initial) { [] }
        let(:struct)  { {1 => 2} }

        it 'does add new nodes for keys of the struct, to which the value can be added as a child' do

        end
      end

      context 'when nodes for certain keys are already present and have children' do
        let(:initial) { {1 => 2} }
        let(:struct)  { {1 => 3} }
      end

    end
=end

    context 'when Nothing given' do
      subject { Tree[].add_children(Sycamore::Nothing) }
      it { is_expected.to     be_empty }
    end

    context 'when Absence given' do
      subject { Tree[].add_children(Tree[].child_of(number)) }
      it { is_expected.to     be_empty }
    end

    context 'when given the empty hash' do
      subject { Tree[].add_children({}) }
      it      { is_expected.to be_empty }
    end

    specify { expect(Tree[a: 1]).to include(a: 1) }
    specify { expect(Tree[a: 1, b: 2]).to include(a: 1, b: 2) }
    specify { expect(Tree[a: 1, b: [2, 3]]).to include(a: 1, b: [2, 3]) }
    specify { expect(Tree[a: [1, 'foo'], b: {2 => 3}]).to include(a: [1, 'foo'], b: {2 => 3}) }

    specify { expect(Tree[1 => nil, 2 => nil, 3 => nil].leaves?(1,2,3)).to be true }
    specify { expect(Tree[1 => [], 2 => [], 3 => []].leaves?(1,2,3)).to be true }
    specify { expect(Tree[1 => {}, 2 => {}, 3 => {}].leaves?(1,2,3)).to be true }

  end


  ############################################################################

  describe '#delete_children' do

    context 'when Nothing given' do
      subject { Tree[].delete_children(Sycamore::Nothing) }
      it      { is_expected.to be_empty }
    end

    context 'when Absence given' do
      subject { Tree[42].delete_children(Tree[].child_of(42)) }
      it      { is_expected.to include 42 }
    end

    context 'when given the empty hash' do
      subject { Tree[].delete_children({}) }
      it      { is_expected.to be_empty }
    end

    specify { expect(Tree[a: 1].delete(a: 1)).to be_empty }
    specify { expect(Tree[a: [1, 2]].delete(:a)).to be_empty }
    specify { expect(Tree[a: [1, 2]].delete(a: 2)).to include(a: 1) }
    specify { expect(Tree[a: [1, 2]].delete(a: 2)).not_to include(a: 2) }

    specify { expect(Tree[a: 1, b: 2].delete(:a)).to include(b: 2) }
    specify { expect(Tree[a: 1, b: 2].delete(:a)).not_to include(a: 1) }

    specify { expect(Tree[a: 1, b: [2, 3]].delete(a: 1, b: 2) === {b: 3}).to be true }

  end



  ################################################################
  # equality and equivalence
  #
  # look at:
  #
  # - Ruby's Set implementation
  # - equalizer: https://github.com/dkubb/equalizer
  #
  ################################################################

  describe '#hash' do
    specify { expect( Sycamore::Tree.new.hash   == Sycamore::Tree.new.hash      ).to be true }
    specify { expect( Sycamore::Tree[1].hash    == Sycamore::Tree[1].hash       ).to be true }
    specify { expect( Sycamore::Tree[1].hash    == Sycamore::Tree[2].hash       ).to be false }
    specify { expect( Sycamore::Tree[1,2].hash  == Sycamore::Tree[2,1].hash     ).to be true }
    specify { expect( Sycamore::Tree[a: 1].hash == Sycamore::Tree[a: 1].hash    ).to be true }
    specify { expect( Sycamore::Tree[a: 1].hash == Sycamore::Tree[a: 2].hash    ).to be false }
    specify { expect( Sycamore::Tree[a: 1].hash == Sycamore::Tree[b: 1].hash    ).to be false }
    specify { expect( Sycamore::Tree[1].hash    == Sycamore::Tree[1 => nil].hash).to be true }

    specify { expect( Sycamore::Tree.new.hash   == Hash.new.hash  ).to be false }
    specify { expect( Sycamore::Tree[a: 1].hash == Hash[a: 1].hash).to be false }
  end


  ############################################################################

  describe '#eql?' do
    specify { expect( Sycamore::Tree.new   ).to eql     Sycamore::Tree.new }
    specify { expect( Sycamore::Tree[1]    ).to eql     Sycamore::Tree[1] }
    specify { expect( Sycamore::Tree[1]    ).not_to eql Sycamore::Tree[2] }
    specify { expect( Sycamore::Tree[1,2]  ).to eql     Sycamore::Tree[2,1] }
    specify { expect( Sycamore::Tree[a: 1] ).to eql     Sycamore::Tree[a: 1] }

    specify { expect( Sycamore::Tree[a: 1] ).not_to eql Hash[a: 1] }
    specify { expect( Sycamore::Tree[1]    ).not_to eql Hash[1 => nil] }
  end

  ############################################################################

  describe '#==' do

    pending 'What should be the semantics of #==?'

    #   Currently it is the same as eql?, since Hash
    #    coerces only the values and not the keys ...

    specify { expect( Sycamore::Tree.new   ).to eq     Sycamore::Tree.new }
    specify { expect( Sycamore::Tree[1]    ).to eq     Sycamore::Tree[1] }
    specify { pending ; expect( Sycamore::Tree[1]    ).to eq     Sycamore::Tree[1.0] }
    specify { expect( Sycamore::Tree[1]    ).not_to eq Sycamore::Tree[2] }
    specify { expect( Sycamore::Tree[1,2]  ).to eq     Sycamore::Tree[2,1] }
    specify { expect( Sycamore::Tree[2]    ).to eq     Sycamore::Tree[1 => 2][1]   }
    specify { expect( Sycamore::Tree[a: 1] ).to eq     Sycamore::Tree[a: 1] }

    specify { expect( Sycamore::Tree[a: 1] ).not_to eq Hash[a: 1] }
    specify { expect( Sycamore::Tree[1]    ).not_to eq Hash[1 => nil] }
  end

  describe '#===' do
    context 'when the other is an atom' do
      context 'when it matches the other' do
        specify { expect( Sycamore::Tree[1]    ===  1   ).to be true }
        specify { expect( Sycamore::Tree[:a]   === :a   ).to be true }
        specify { expect( Sycamore::Tree['a']  === 'a'  ).to be true }
      end

      context 'when it not matches the other' do
        specify { expect( Sycamore::Tree[1]  === 2   ).to be false }
        specify { expect( Sycamore::Tree[1]  === '1' ).to be false }
        specify { expect( Sycamore::Tree[:a] === 'a' ).to be false }
      end
    end

    context 'when the other is an Enumerable' do
      context 'when it matches the other' do
        specify { expect( Sycamore::Tree[1] === [1]               ).to be true }
        specify { expect( Sycamore::Tree[1,2,3] === [1,2,3]       ).to be true }
        specify { expect( Sycamore::Tree[:a,:b,:c] === [:c,:a,:b] ).to be true }
      end

      context 'when it not matches the other' do
        specify { expect( Sycamore::Tree[1,2]   === [1,2,3]   ).to be false }
        specify { expect( Sycamore::Tree[1,2,3] === [1,2]     ).to be false }
        specify { expect( Sycamore::Tree[1,2,3] === [1,2,[3]] ).to be false }
      end
    end

    context 'when the other is Tree-like' do
      context 'when it matches the other' do
        specify { expect( Sycamore::Tree.new   === Sycamore::Tree.new ).to be true }
        specify { expect( Sycamore::Tree.new   === Hash.new ).to be true }
        specify { expect( Sycamore::Tree.new   === Sycamore::Tree[nil] ).to be true }
        specify { expect( Sycamore::Tree.new   === Sycamore::Tree[nil => nil] ).to be true }
        specify { expect( Sycamore::Tree.new   ===
                          Sycamore::Tree[Sycamore::Nothing => Sycamore::Nothing] ).to be true }
        specify { expect( Sycamore::Tree[1]    === Sycamore::Tree[1] ).to be true }
        specify { expect( Sycamore::Tree[1]    === Sycamore::Tree[1 => nil] ).to be true }
        specify { expect( Sycamore::Tree[1]    === Hash[1 => nil] ).to be true }
        specify { expect( Sycamore::Tree[1]    ===
                          Sycamore::Tree[1 => Sycamore::Nothing] ).to be true }
        specify { expect( Sycamore::Tree[1]    ===
                          Hash[1 => Sycamore::Nothing] ).to be true }
        specify { expect( Sycamore::Tree[1,2]  === Sycamore::Tree[2,1] ).to be true }
        specify { expect( Sycamore::Tree[a: 1] === Sycamore::Tree[a: 1] ).to be true }
        specify { expect( Sycamore::Tree[a: 1] === Hash[a: 1] ).to be true }
        specify { expect( Sycamore::Tree[foo: 'foo', bar: ['bar', 'baz']] ===
                          Sycamore::Tree[foo: 'foo', bar: ['bar', 'baz']] ).to be true }
        specify { expect( Sycamore::Tree[foo: 'foo', bar: ['bar', 'baz']] ===
                          Hash[foo: 'foo', bar: ['bar', 'baz']] ).to be true }
        specify { expect( Sycamore::Tree[1=>{2=>{3=>4}}] ===
                          Sycamore::Tree[1=>{2=>{3=>4}}] ).to be true }
        specify { expect( Sycamore::Tree[1=>{2=>{3=>4}}] ===
                          Hash[1=>{2=>{3=>4}}] ).to be true }
        specify { expect( Sycamore::Tree[a: 1] === Hash[a: 1] ).to be true }
      end

      context 'when it not matches the other' do
        specify { expect( Sycamore::Tree.new   ===
                                    Hash[nil => nil] ).to be false }
        specify { expect( Sycamore::Tree.new   ===
                                    Hash[Sycamore::Nothing => Sycamore::Nothing] ).to be false }
        specify { expect( Sycamore::Tree[1]    ===
                                    Sycamore::Tree[2]).to be false }
        specify { expect( Sycamore::Tree[1=>{2=>{3=>4}}] ===
                          Sycamore::Tree[1=>{2=>{3=>1}}] ).to be false }
        specify { expect( Sycamore::Tree[1=>{2=>{3=>4}}] ===
                                    Hash[1=>{2=>{4=>4}}] ).to be false }
      end
    end
  end



  ##########################################
  # comparison
  #
  # What should we support of this, since Tree probably doesn't have a total order?
  #
  # Should we map directly to include?, or should check if the other a Tree, i.e.
  #   should we support comparison on Tree.like? structures in general?
  #
  ##########################################

  # describe '#<' do
  #   it 'does behave like include?, except it returns false when equal to the other'
  #   it 'delegates to #include? and #=== (negated)'
  # end
  #
  # describe '#<=' do
  #   it 'delegates to #include?' do
  #     pending
  #     expect( Tree[1,2] <=       [1] ).to equal(
  #             Tree[1,2].include? [1])
  #     expect( Tree[1] <=         [1] ).to equal(
  #             Tree[1].include?   [1])
  #   end
  # end
  #
  # describe '#>' do
  #   it 'delegates to #include? of the other and #=== (negated)'
  # end
  #
  # describe '#>=' do
  #   it 'delegates to #include? of the other'
  # end

  # describe '#<=>' do
  #   it 'delegates to #include? and #==='
  #   it 'is not supported, since Tree does not define a total order'
  # end



  ##########################################
  # conversion
  ##########################################

  # TODO: shared example or matcher for ...
  describe '#to_???' do
    specify { expect( Sycamore::Tree[         ].to_h ).to eq( {} ) }
    specify { expect( Sycamore::Tree[ 1       ].to_h ).to eq( 1 ) }
    specify { expect( Sycamore::Tree[ 1, 2, 3 ].to_h ).to eq( [1, 2, 3] ) }
    specify { expect( Sycamore::Tree[ :a => 1 ].to_h ).to eq( { :a => 1 } ) }
    specify { expect( Sycamore::Tree[ :a => 1, :b => [2, 3] ].to_h ).to eq(
                                    { :a => 1, :b => [2, 3] } ) }
  end

  # describe '#to_a' do
  #   specify { expect( Tree[         ].to_a ).to eq( [] ) }
  #   specify { expect( Tree[ 1       ].to_a ).to eq( [1] ) }
  #   specify { expect( Tree[ 1, 2, 3 ].to_a ).to eq( [1, 2, 3] ) }
  #   specify { expect( Tree[ :a => 1 ].to_a ).to eq( [ :a => [1] ] ) }
  #   specify { expect( Tree[ :a => 1, :b => [2, 3] ].to_a ).to eq(
  #                         [ :a => [1], :b => [2, 3] ] ) }
  # end

  describe '#to_h' do
    pending
  end

  describe '#to_s' do
    it 'delegates to the hash representation of #to_h'
    # TODO: shared example or matcher for ...

    specify { expect( Sycamore::Tree[         ].to_s ).to eq( '{}' ) }
    specify { expect( Sycamore::Tree[ 1       ].to_s ).to eq( '1' ) }
    specify { expect( Sycamore::Tree[ 1, 2, 3 ].to_s ).to eq( '[1, 2, 3]' ) }
    specify { expect( Sycamore::Tree[ :a => 1 ].to_s ).to eq( '{:a=>1}' ) }
    specify { expect( Sycamore::Tree[ :a => 1, :b => [2, 3] ].to_s ).to eq(
                          '{:a=>1, :b=>[2, 3]}' ) }

  end

  describe '#inspect' do

    shared_examples_for 'every inspect string' do |tree|
      it 'is in the usual Ruby inspect style' do
        expect( tree.inspect ).to match /^#<Sycamore::Tree:0x/
      end
      it 'contains the object identity' do
        expect( tree.inspect ).to include tree.object_id.to_s(16)
      end
      it 'contains the hash representation' do
        expect( tree.inspect ).to include tree.to_h.inspect
      end
    end

    include_examples 'every inspect string', Sycamore::Tree.new
    include_examples 'every inspect string', Sycamore::Tree[1,2,3]
    include_examples 'every inspect string', Sycamore::Tree[foo: 1, bar: [2,3]]

  end



  ################################################################
  # Various other Ruby protocols                                 #
  ################################################################

  describe '#freeze' do

    it 'behaves Object#freeze conform' do
      # stolen from Ruby's tests of set.rb (test_freeze) adapted to RSpec and with Trees
      # see https://www.omniref.com/ruby/2.2.0/files/test/test_set.rb
      orig = tree = Sycamore::Tree[1, 2, 3]
      expect(tree).not_to be_frozen
      tree << 4
      expect(tree.freeze).to be orig
      expect(tree).to be_frozen
      expect { tree << 5 }.to raise_error RuntimeError
      expect(tree.size).to be 4
    end

  end

end
