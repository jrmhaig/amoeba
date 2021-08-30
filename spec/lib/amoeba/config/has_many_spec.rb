# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Amoeba::Config, '#has_many' do
  subject(:duplicate) { original.amoeba_dup }

  before do
    tables.each_key { |table| ActiveRecord::Base.connection.drop_table table, if_exists: true }
    # schema_cache.clear! may not be required with 6.1+
    ActiveRecord::Base.connection.schema_cache.clear!

    tables.each_pair do |table, config|
      ActiveRecord::Base.connection.create_table(table, &(config[:database])) if config[:database]
      stub_const config[:model], Class.new(Class.const_get(config[:parent_model]))
      Class.const_get(config[:model]).class_eval(config[:model_config])
    end
  end

  context 'with has_many association' do
    let(:tables) do
      {
        parents: {
          database: proc {},
          model: 'Parent',
          parent_model: 'ActiveRecord::Base',
          model_config: <<~CONFIG
            has_many :children, inverse_of: :parent
            amoeba { enable }
          CONFIG
        },
        children: {
          database: proc do |t|
            t.string :name
            t.references :parent
            t.boolean :extra
          end,
          model: 'Child',
          parent_model: 'ActiveRecord::Base',
          model_config: 'belongs_to :parent, inverse_of: :children'
        }
      }
    end

    context 'with three attached records' do
      let(:original) { Parent.create(children: [Child.new, Child.new, Child.new]) }

      it do
        duplicate
        expect { duplicate.save }.to change(Child, :count).by 3
      end

      it { expect(duplicate.children.length).to eq 3 }
    end

    context 'without amoeba enabled' do
      let(:original) { Parent.create(children: [Child.new(name: 'Test name')]) }
      let(:tables) do
        super().tap { |t| t[:parents][:model_config] = 'has_many :children, inverse_of: :parent' }
      end

      it { expect(duplicate.children).to be_empty }
    end

    context 'without attached records' do
      let(:original) { Parent.create }

      it { is_expected.to be_valid }
      it { expect(duplicate.children).to be_empty }

      it do
        duplicate
        expect { duplicate.save }.not_to change(Child, :count)
      end
    end

    context 'with nullify preprocessing' do
      let(:original) { Parent.create(children: [Child.new(name: 'Test name')]) }
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :children, inverse_of: :parent

            amoeba do
              enable
              nullify :children
            end
          CONFIG
        end
      end

      before do
        pending 'TODO: Decide if this is the desired behaviour'
        # It seems sensible that nullify should work on a has_many association
        # but at the moment it results in an ActiveModel::MissingAttributeError
        # exception.
      end

      it { is_expected.to be_valid }

      it { expect(duplicate.children).to be_empty }
    end

    context 'with preprocessing on the attached record' do
      let(:original) { Parent.create(children: [Child.new(name: 'Test name')]) }
      let(:tables) do
        super().tap do |t|
          t[:children][:model_config] = <<~CONFIG
            belongs_to :parent, inverse_of: :children

            amoeba { prepend name: 'Original name: ' }
          CONFIG
        end
      end

      it { expect(duplicate.children.first.name).to eq 'Original name: Test name' }
    end

    context 'with attached records generated by customized preprocessing' do
      let(:original) do
        Parent.create(
          children: [
            Child.new(name: 'Test name one', extra: false),
            Child.new(name: 'Test name two', extra: true)
          ]
        )
      end
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :children, inverse_of: :parent

            amoeba {
              enable
              customize(
                lambda do |original, copy|
                  original.children.each do |x|
                    copy.children << Child.new(name: x.name.reverse, extra: false) if x.extra
                  end
                end
              )
            }
          CONFIG
        end
      end

      it do
        duplicate
        expect { duplicate.save }.to change(Child, :count).by 3
      end

      it { expect(duplicate.children.last.name).to eq 'owt eman tseT' }
    end

    context 'with has_many not recognized' do
      let(:original) { Parent.create(children: [Child.new, Child.new, Child.new]) }
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :children, inverse_of: :parent

            amoeba {
              enable
              recognize [:has_one, :has_and_belongs_to_many]
            }
          CONFIG
        end
      end

      it 'does not creates new child records' do
        duplicate
        expect { duplicate.save }.not_to change(Child, :count)
      end

      it 'does include child models in the duplicate' do
        duplicate.save
        expect(duplicate.children).to be_empty
      end
    end
  end

  context 'with single table inheritance' do
    let(:original) { SuperParent.create(children: [Child.new, Child.new, Child.new]) }

    let(:tables) do
      {
        parents: {
          database: proc { |t| t.string :type },
          model: 'Parent',
          parent_model: 'ActiveRecord::Base',
          model_config: <<~CONFIG
            has_many :children
            amoeba { enable }
          CONFIG
        },
        children: {
          database: proc do |t|
            t.string :name
            t.references :parent
          end,
          model: 'Child',
          parent_model: 'ActiveRecord::Base',
          model_config: 'belongs_to :parent'
        },
        super_parents: {
          model: 'SuperParent',
          parent_model: 'Parent',
          model_config: ''
        }
      }
    end

    context 'with propagate' do
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :children, inverse_of: :parent

            amoeba {
              enable
              propagate
            }
          CONFIG
        end
      end

      it do
        duplicate
        expect { duplicate.save }.to change(Child, :count).by 3
      end

      it { expect(duplicate.children.length).to eq 3 }
    end

    context 'without propagate' do
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :children, inverse_of: :parent

            amoeba { enable }
          CONFIG
        end
      end

      it do
        duplicate
        expect { duplicate.save }.not_to change(Child, :count)
      end

      it { expect(duplicate.children).to be_empty }
    end

    context 'with child associated to inherited table' do
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            amoeba {
              enable
              propagate
            }
          CONFIG
          t[:super_parents][:model_config] = 'has_many :children, foreign_key: :parent_id'
        end
      end

      it do
        duplicate
        expect { duplicate.save }.to change(Child, :count).by 3
      end

      it { expect(duplicate.children.length).to eq 3 }
    end
  end

  context 'with has_many/through association' do
    let(:duplicate) { original.amoeba_dup }
    let(:original) { Parent.create(children: [Child.new, Child.new]) }
    let(:tables) do
      {
        parents: {
          database: proc {},
          model: 'Parent',
          parent_model: 'ActiveRecord::Base',
          model_config: <<~CONFIG
            has_many :parent_children
            has_many :children, through: :parent_children

            amoeba { enable }
          CONFIG
        },
        children: {
          database: proc {},
          model: 'Child',
          parent_model: 'ActiveRecord::Base',
          model_config: ''
        },
        parent_children: {
          database: proc do |t|
            t.references :parent
            t.references :child
          end,
          model: 'ParentChild',
          parent_model: 'ActiveRecord::Base',
          model_config: <<~CONFIG
            belongs_to :parent
            belongs_to :child

            amoeba { enable }
          CONFIG
        }
      }
    end

    it 'does not create new child records' do
      duplicate
      expect { duplicate.save }.not_to change(Child, :count)
    end

    it 'copies the child records from the original' do
      duplicate.save
      expect(duplicate.children.map(&:to_param))
        .to match_array(original.children.map(&:to_param))
    end

    context 'with child model cloning' do
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :parent_children
            has_many :children, through: :parent_children

            amoeba {
              enable
              clone [:children]
            }
          CONFIG
        end
      end

      it 'does creates new child records' do
        duplicate
        expect { duplicate.save }.to change(Child, :count).by 2
      end

      it 'does not copy the child records from the original' do
        duplicate.save
        expect(duplicate.children.map(&:to_param))
          .not_to match_array(original.children.map(&:to_param))
      end
    end

    context 'with has_many not recognized' do
      let(:tables) do
        super().tap do |t|
          t[:parents][:model_config] = <<~CONFIG
            has_many :parent_children
            has_many :children, through: :parent_children

            amoeba {
              enable
              recognize [:has_one, :has_and_belongs_to_many]
            }
          CONFIG
        end
      end

      it 'does not creates new child records' do
        duplicate
        expect { duplicate.save }.not_to change(Child, :count)
      end

      it 'does include child models in the duplicate' do
        duplicate.save
        expect(duplicate.children).to be_empty
      end
    end
  end
end