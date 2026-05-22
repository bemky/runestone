require 'test_helper'

class HighlightTest < ActiveSupport::TestCase

  schema do
    create_table :addresses, id: :uuid, force: :cascade do |t|
      t.string  "name"
      t.string  "metadata"
      t.uuid    "property_id"
    end
    
    create_table :properties, id: :uuid, force: :cascade do |t|
      t.string  "name",                 limit: 255
      t.string  "metadata"
    end
  end
  
  class Address < ActiveRecord::Base
    belongs_to :property

    runestone do
      index 'name'
      attribute(:name)
    end
  end

  class Property < ActiveRecord::Base
    has_many :addresses, autosave: true

    runestone do
      index :name
      index 'addresses.name', weight: 3
      index :tokens, weight: 2

      attribute(:name)
      attribute(:addresses) { addresses.map{ |a| a&.attributes&.slice('id', 'name') } }
      attribute(:tokens) { name.to_s.split(' ') }
    end
  end

  test '::highlights(query)' do
    uno = Address.create(name: 'address uno')
    duo = Address.create(name: 'address of state duo')
    Property.create(name: 'Empire state building', addresses: [uno])
    Property.create(name: 'Big state building', addresses: [duo])
    
    tsmodels = Runestone::Model.search('state')
    Runestone::Model.highlight(tsmodels, 'state')
    assert_equal([
      {
        "name"=>"Big state building",
        "addresses"=> [{"id" => duo.id, "name"=>"address of state duo"}],
        "tokens"=> ["Big", "state", "building"]
      },
      {
        "name"=>"Empire state building",
        "addresses"=> [{"id" => uno.id, "name"=>"address uno"}],
        "tokens"=> ["Empire", "state", "building"]
      },
      { "name"=>"address of state duo" }
    ], tsmodels.map(&:data))

    assert_equal([
      {
        "name"=>"Big <b>state</b> building",
        "addresses"=> [{"id" => duo.id, "name"=>"address of <b>state</b> duo"}],
        "tokens"=> ["Big", "<b>state</b>", "building"]
      },
      {
        "name"=>"Empire <b>state</b> building",
        "addresses"=> [{"id" => uno.id, "name"=>"address uno"}],
        "tokens"=> ["Empire", "<b>state</b>", "building"]
      },
      { "name"=>"address of <b>state</b> duo" }
    ], tsmodels.map(&:highlights))
  end
  
  test '::highlights(query) with an accent in the result' do
    uno = Address.create(name: 'address uno')
    duo = Address.create(name: 'addréss of state duo')
    Property.create(name: 'Émpire state building', addresses: [uno])
    Property.create(name: 'Big state building', addresses: [duo])
    
    tsmodels = Runestone::Model.search('empire')
    Runestone::Model.highlight(tsmodels, 'empire')
    assert_equal([
      {
        "name"=>"<b>Émpire</b> state building",
        "addresses"=>[ {"id" => uno.id, "name"=>"address uno"} ],
        "tokens"=>["<b>Émpire</b>", "state", "building"]
      }
    ], tsmodels.map(&:highlights))

    tsmodels = Runestone::Model.search('address')
    Runestone::Model.highlight(tsmodels, 'address')
    assert_equal([
      {"name"=>"<b>address</b> uno"},
      {"name"=>"<b>addréss</b> of state duo"},
      {"name"=>"Émpire state building", "addresses"=>[{"id" => uno.id, "name"=>"<b>address</b> uno"}], "tokens"=>["Émpire", "state", "building"]},
      {"name"=>"Big state building", "addresses"=>[{"id" => duo.id, "name"=>"<b>addréss</b> of state duo"}], "tokens"=>["Big", "state", "building"]}
    ], tsmodels.map(&:highlights))
  end
  
end
