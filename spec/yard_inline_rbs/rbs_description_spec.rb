# frozen_string_literal: true

RSpec.describe YardInlineRbs::RbsDescription do
  describe '.split' do
    context 'without a description' do
      it 'returns the type and no description' do
        expect(described_class.split('Integer')).to eq(['Integer', nil])
      end
    end

    context 'with the description on the same line' do
      it 'splits on the -- separator' do
        expect(described_class.split('Integer -- the count')).to eq(['Integer', 'the count'])
      end
    end

    context 'with extra spaces around the -- separator' do
      it 'strips them from the type and the description' do
        expect(described_class.split('Integer  --  the count')).to eq(['Integer', 'the count'])
      end
    end

    context 'with a -- in the description' do
      it 'splits on the first -- only' do
        expect(described_class.split('Integer -- the count -- roughly'))
          .to eq(['Integer', 'the count -- roughly'])
      end
    end

    context 'with a first line that looks like another overload' do
      it 'returns it as the type' do
        expect(described_class.split('| (Float) -> Float')).to eq(['| (Float) -> Float', nil])
      end
    end

    context 'with the description on the same line and continuation lines' do
      it 'joins the continuation lines into the description' do
        expect(described_class.split("Integer -- the count\n  of all items"))
          .to eq(['Integer', 'the count of all items'])
      end
    end

    context 'with the -- separator at the end of the line' do
      it 'uses the lines below as description' do
        expect(described_class.split("Integer? --\n  how old is the person?\n  nil if unknown."))
          .to eq(['Integer?', 'how old is the person? nil if unknown.'])
      end
    end

    context 'with the -- separator at the end of the line and nothing below it' do
      it 'returns no description' do
        expect(described_class.split('Integer --')).to eq(['Integer', nil])
      end
    end

    context 'with the -- separator at the start of a continuation line' do
      it 'uses the rest of the lines as description' do
        expect(described_class.split("String | Integer\n  -- The combined result."))
          .to eq(['String | Integer', 'The combined result.'])
      end
    end

    context 'with a type that continues on the next line' do
      it 'joins the lines into the type' do
        expect(described_class.split("(Integer count)\n  -> String"))
          .to eq(['(Integer count) -> String', nil])
      end
    end

    context 'with a type that continues on the next line and a description below it' do
      it 'joins the type lines and the description lines' do
        expect(described_class.split("(Integer count)\n  -> String\n  -- the label\n  in full"))
          .to eq(['(Integer count) -> String', 'the label in full'])
      end
    end

    context 'with overloads on the next lines' do
      it 'returns the first overload' do
        expect(described_class.split("(Integer) -> Integer\n  | (Float) -> Float\n  | () -> nil"))
          .to eq(['(Integer) -> Integer', nil])
      end
    end

    context 'with a union that continues with a tuple and a description' do
      it 'returns the whole union and the description' do
        expect(described_class.split("Integer\n  | [Float, String] -- the value"))
          .to eq(['Integer | [Float, String]', 'the value'])
      end
    end

    context 'with a union type that continues on the next line' do
      it 'returns the whole union' do
        expect(described_class.split("Integer\n  | Float")).to eq(['Integer | Float', nil])
      end
    end

    context 'with nil' do
      it 'returns an empty type and no description' do
        expect(described_class.split(nil)).to eq(['', nil])
      end
    end
  end

  describe '.overloads' do
    context 'with one type' do
      it 'returns the type' do
        expect(described_class.overloads('Integer -- the count')).to eq(['Integer'])
      end
    end

    context 'with overloads on the next lines' do
      it 'returns every overload, without the bar' do
        text = "(Integer) -> Integer\n  | (Float) -> Float\n  | () -> nil"
        expect(described_class.overloads(text))
          .to eq(['(Integer) -> Integer', '(Float) -> Float', '() -> nil'])
      end
    end

    context 'with an overload that continues on the next line' do
      it 'joins the lines of that overload' do
        expect(described_class.overloads("(Integer)\n  -> Integer\n  | (Float) -> Float"))
          .to eq(['(Integer) -> Integer', '(Float) -> Float'])
      end
    end

    context 'with a description after the last overload' do
      it 'leaves the description out' do
        expect(described_class.overloads("(Integer) -> Integer\n  | (Float) -> Float -- the count"))
          .to eq(['(Integer) -> Integer', '(Float) -> Float'])
      end
    end

    context 'with a description after the first overload' do
      it 'leaves the description out' do
        expect(described_class.overloads("(Integer) -> Integer -- the count\n  | (Float) -> Float"))
          .to eq(['(Integer) -> Integer', '(Float) -> Float'])
      end
    end

    context 'with a union type that continues on the next line' do
      it 'returns the whole union' do
        expect(described_class.overloads("Integer\n  | Float")).to eq(['Integer | Float'])
      end
    end

    context 'with a first line that looks like another overload' do
      it 'returns it as the type' do
        expect(described_class.overloads('| (Float) -> Float')).to eq(['| (Float) -> Float'])
      end
    end

    context 'with a union that continues with a tuple, a record or a parenthesised type' do
      it 'returns the whole union' do
        text = "Integer\n  | [Float, String]\n  | { id: Integer }\n  | (Symbol | nil)"
        expect(described_class.overloads(text))
          .to eq(['Integer | [Float, String] | { id: Integer } | (Symbol | nil)'])
      end
    end

    context 'with overloads, of which the second has type parameters' do
      it 'returns both overloads' do
        expect(described_class.overloads("(Integer) -> Integer\n  | [T] (T) -> T"))
          .to eq(['(Integer) -> Integer', '[T] (T) -> T'])
      end
    end

    context 'with nil' do
      it 'returns an empty type' do
        expect(described_class.overloads(nil)).to eq([''])
      end
    end
  end
end
