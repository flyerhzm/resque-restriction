require 'spec_helper'

module Resque
  module Restriction
    RSpec.describe Config do
      it 'has a default value for max_queue_peek' do
        expect(Restriction.config.max_queue_peek('restriction_queue1')).to eq(100)
      end

      it 'can be configured with new values' do
        Restriction.configure do |config|
          config.max_queue_peek = 50
        end
        expect(Restriction.config.max_queue_peek('restriction_queue1')).to eq(50)
      end

      it 'can be configured with a lambda' do
        Restriction.configure do |config|
          sizes = {
            'foo' => 10,
            'bar' => 100
          }
          config.max_queue_peek = -> queue { sizes[queue] || 25 }
        end
        expect(Restriction.config.max_queue_peek('foo')).to eq(10)
        expect(Restriction.config.max_queue_peek('bar')).to eq(100)
        expect(Restriction.config.max_queue_peek('baz')).to eq(25)
      end
    end
  end
end
