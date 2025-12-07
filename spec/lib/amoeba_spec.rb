# frozen_string_literal: true

require 'spec_helper'

describe 'amoeba' do
  context 'amoeba_dup' do
    subject(:save_post) { new_post.save! }

    let(:old_post) { ::Post.find(1) }
    let(:new_post) { old_post.amoeba_dup }

    before do
      require ::File.dirname(__FILE__) + '/../support/data.rb'
      old_post.class.amoeba do
        prepend contents: "Here's a copy: "
      end
    end

    # Unecessary. Included in refactor for completeness.
    it { expect(old_post.comments.map(&:contents).include?('I love it!')).to be_truthy }

    it { is_expected.to be_truthy }

    it do
      save_post
      expect(new_post.title).to eq("Copy of #{old_post.title}")
    end

    it { expect { save_post }.not_to change(Tag.all, :count) }
    it { expect { save_post }.not_to change(Category, :count) }

    # The original versions of these tests counted checked that the counts of
    # various models were multipled when the new instance is saved. This
    # depends on there being no other data in the database, which is not
    # reliable. The new versions of these tests check for an increase in the
    # count by a certain amount. This depends on how the test data is created.

    # Testing a 'has_one' relation with default amoeba configuration.
    it { expect { save_post }.to change(Account, :count).by(1) }

    # Testing a 'has_one ... through' relation with default amoeba
    # configuration.
    it { expect { save_post }.to change(History.all, :count).by(1) }

    # Testing a 'has_many' relation with default amoeba configuration.
    it { expect { save_post }.to change(Supercat.all, :count).by(3) }

    # Testing that a new instance is created when a duplicate is saved.
    it { expect { save_post }.to change(Post.all, :count).by(1) }

    # Testing a 'has_one' relation with default amoeba configuration.
    it { expect { save_post }.to change(PostConfig.all, :count).by(1) }

    # The dup adds extra comments based on 'customize'. Three comments are
    # added and two new ones are created.
    it { expect { save_post }.to change(Comment.all, :count).by(5) }

    # Ratings are linked to comments. The dup will duplicate the ratings for
    # the existing comments (6 each for the test data) and the new comments
    # will have no ratings.
    it { expect { save_post }.to change(Rating.all, :count).by(18) }

    # Testing a 'has_and_belongs_to_many' relationship with the default amoeba
    # configuration.
    # The `tag_count` method fetches the number of records in the join table
    # and this tests that the three tags on the post are applied to the new
    # post.
    it { expect { save_post }.to change(Post, :tag_count).by(3) }

    # Testing a 'has_one ... through' relationship with the 'clone' amoeba
    # configuration.
    # The three widgets that are linked, via a join table, should be duplicated
    # in the Widget model and add corresponding records in the join table,
    # PostWidget.
    it { expect { save_post }.to change(Widget.all, :count).by(3) }
    it { expect { save_post }.to change(PostWidget, :count).by(3) }

    # Testing a 'has_and_belongs_to_many' relationship with the 'clone' amoeba
    # configuration.
    # There are three notes attached to the post so three new notes should be
    # created in the Note model as well as three records in the join table. The
    # `note_count` method fetches the number of records in the join table.
    it { expect { save_post }.to change(Note.all, :count).by(3) }
    it { expect { save_post }.to change(Post, :note_count).by(3) }

    # Testing the 'include_association' amoeba configuration.
    # Each Post can have many Supercats and each Supercat can have many
    # Supperkitens. In the test data the post has three supercats and each
    # supercat has three superkittens (how many were there going to St Ives?).
    # As a result 9 extra Superkittens should be generated.
    it { expect { save_post }.to change(Superkitten.all, :count).by(9) }

    # Testing 'prepend' configuration on attribute.
    # The attribute `ramblings` is configured to prepend 'Copy of '.
    it { expect(new_post.supercats.map(&:ramblings)).to contain_exactly('Copy of zomg', 'Copy of why', 'Copy of ohnoes') }

    # Testing 'set' configuration on attribute.
    # The attribute 'other_ramblings' is configured to set to 'La la la'.
    # The original tests check that (a) the values are unique and (b) the value
    # is set correctly. This new test will check that there are three values
    # that are all set the same.
    it { expect(new_post.supercats.map(&:other_ramblings)).to contain_exactly('La la la', 'La la la', 'La la la') }

    # Testing various string modifications.
    #   * 'prepend' to add "Here's a copy: ", defined in the 'before' above
    #   * 'append' to add " (copied version)"
    #   * 'regext' to replace "dog" with "cat"
    it { expect(new_post.contents).to eq("Here's a copy: Lorum ipsum dolor rainbow bright. I like cats, cats are awesome. (copied version)") }

    # Testing 'customize' configuration.
    # Two of the comments in the old post have 'nerf' values that cause lambdas
    # to generate additional when the post is duplicated.
    # The old post has three comments so the new post will have five comments.
    it { expect(new_post.comments.length).to eq(5) }
    # When the comment's 'nerf' value is 'ratatat' the new post will have the
    # comment duplicated.
    # The 'where' will only work once new_post has been saved.
    it { expect(new_post.tap(&:save).comments.where(nerf: 'ratatat').length).to eq(2) }
    # The duplicate will have a nil 'contents' while the other version is not.
    it { expect(new_post.tap(&:save).comments.where(nerf: 'ratatat', contents: nil).length).to eq(1) }
    # When the comment's 'nerf' value is 'bonk' the new post will have the
    # comment duplicated. The new comment will have a modified 'nerf' value.
    # The 'where' will only work once new_post has been saved.
    # There will only be a single comment with the original 'nerf' value.
    it { expect(new_post.tap(&:save).comments.where(nerf: 'bonk').length).to eq(1) }
    # The duplicate will have a modified 'nerf' value.
    it { expect(new_post.tap(&:save).comments.where(nerf: 'bonkers', contents: nil).length).to eq(1) }
  end

  context 'dup' do
    before do
      require ::File.dirname(__FILE__) + '/../support/data.rb'
    end

    let(:first_product) { Product.find(1) }

    it 'duplicates associated child records' do
      # Posts {{{
      old_post = ::Post.find(1)
      # expect(old_post.comments.map(&:contents).include?('I love it!')).to be_truthy

      old_post.class.amoeba do
        prepend contents: "Here's a copy: "
      end

      new_post = old_post.amoeba_dup

      # start_account_count = Account.all.count
      # start_history_count = History.all.count
      # start_cat_count = Category.all.count
      # start_supercat_count = Supercat.all.count
      # start_tag_count = Tag.all.count
      # start_note_count = Note.all.count
      # start_widget_count = Widget.all.count
      # start_post_count = Post.all.count
      # start_comment_count = Comment.all.count
      # start_rating_count = Rating.all.count
      # start_postconfig_count = PostConfig.all.count
      # start_postwidget_count = PostWidget.all.count
      # start_superkitten_count = Superkitten.all.count
      # start_posttag_count = Post.tag_count
      # start_postnote_count = Post.note_count

      new_post.save!
      # expect(new_post.save!).to be_truthy
      # expect(new_post.title).to eq("Copy of #{old_post.title}")

      # end_account_count = Account.count
      # end_history_count = History.count
      # end_cat_count = Category.count
      # end_supercat_count = Supercat.count
      # end_tag_count = Tag.all.count
      # end_note_count = Note.all.count
      # end_widget_count = Widget.all.count
      # end_post_count = Post.all.count
      # end_comment_count = Comment.all.count
      # end_rating_count = Rating.all.count
      # end_postconfig_count = PostConfig.all.count
      # end_postwidget_count = PostWidget.all.count
      # end_superkitten_count = Superkitten.all.count
      # end_posttag_count = Post.tag_count
      # end_postnote_count = Post.note_count

      # expect(end_tag_count).to         eq(start_tag_count)
      # expect(end_cat_count).to         eq(start_cat_count)
      # expect(end_account_count).to     eq(start_account_count * 2)
      # expect(end_history_count).to     eq(start_history_count * 2)
      # expect(end_supercat_count).to    eq(start_supercat_count * 2)
      # expect(end_post_count).to        eq(start_post_count * 2)
      # expect(end_comment_count).to     eq((start_comment_count * 2) + 2)
      # expect(end_rating_count).to      eq(start_rating_count * 2)
      # expect(end_postconfig_count).to  eq(start_postconfig_count * 2)
      # expect(end_posttag_count).to     eq(start_posttag_count * 2)
      # expect(end_widget_count).to      eq(start_widget_count * 2)
      # expect(end_postwidget_count).to  eq(start_postwidget_count * 2)
      # expect(end_note_count).to        eq(start_note_count * 2)
      # expect(end_postnote_count).to    eq(start_postnote_count * 2)
      # expect(end_superkitten_count).to eq(start_superkitten_count * 2)

      # expect(new_post.supercats.map(&:ramblings)).to include('Copy of zomg')
      # expect(new_post.supercats.map(&:other_ramblings).uniq.length).to eq(1)
      # expect(new_post.supercats.map(&:other_ramblings).uniq).to include('La la la')
      # expect(new_post.contents).to eq("Here's a copy: #{old_post.contents.gsub(/dog/,
      #                                                                          'cat')} (copied version)")
      # expect(new_post.comments.length).to eq(5)
      # expect(new_post.comments.select do |c|
      #          c.nerf == 'ratatat' && c.contents.nil?
      #        end.length).to eq(1)
      # expect(new_post.comments.select { |c| c.nerf == 'ratatat' }.length).to eq(2)
      # expect(new_post.comments.select { |c| c.nerf == 'bonk' }.length).to eq(1)
      # expect(new_post.comments.select do |c|
      #          c.nerf == 'bonkers' && c.contents.nil?
      #        end.length).to eq(1)

      new_post.widgets.map(&:id).each do |id|
        expect(old_post.widgets.map(&:id)).not_to include(id)
      end

      expect(new_post.custom_things.length).to eq(3)
      expect(new_post.custom_things.select { |ct| ct.value == [] }.length).to eq(1)
      expect(new_post.custom_things.select { |ct| ct.value == [1, 2] }.length).to eq(1)
      expect(new_post.custom_things.select { |ct| ct.value == [78] }.length).to eq(1)
      # }}}
      # Author {{{
      old_author = Author.find(1)
      new_author = old_author.amoeba_dup
      new_author.save!
      expect(new_author.errors.messages).to be_empty
      expect(new_author.posts.first.custom_things.length).to eq(3)
      expect(new_author.posts.first.custom_things.select { |ct| ct.value == [] }.length).to eq(1)
      expect(new_author.posts.first.custom_things.select do |ct|
               ct.value == [1, 2]
             end.length).to eq(1)
      expect(new_author.posts.first.custom_things.select { |ct| ct.value == [78] }.length).to eq(1)
      # }}}
      # Products {{{
      # Base Class {{{

      start_image_count = first_product.images.count
      start_section_count = Section.all.length
      start_prodsection_count = first_product.section_count

      new_product = first_product.amoeba_dup
      new_product.save
      expect(new_product.errors.messages).to be_empty

      end_image_count = first_product.images.count
      end_newimage_count = new_product.images.count
      end_section_count = Section.all.length
      end_prodsection_count = first_product.section_count
      end_newprodsection_count = new_product.section_count

      expect(end_image_count).to eq(start_image_count)
      expect(end_newimage_count).to eq(start_image_count)
      expect(end_section_count).to eq(start_section_count)
      expect(end_prodsection_count).to eq(start_prodsection_count)
      expect(end_newprodsection_count).to eq(start_prodsection_count)
      # }}}

      # Inherited Class {{{
      # Shirt {{{
      old_product = Shirt.find(2)

      start_image_count = old_product.images.count
      start_section_count = Section.count
      start_prodsection_count = old_product.section_count

      new_product = old_product.amoeba_dup
      new_product.save
      expect(new_product.errors.messages).to be_empty

      end_image_count = old_product.images.count
      end_newimage_count = new_product.images.count
      end_section_count = Section.count
      end_prodsection_count = first_product.section_count
      end_newprodsection_count = new_product.section_count

      expect(end_image_count).to eq(start_image_count)
      expect(end_newimage_count).to eq(start_image_count)
      expect(end_section_count).to eq(start_section_count)
      expect(end_prodsection_count).to eq(start_prodsection_count)
      expect(end_newprodsection_count).to eq(start_prodsection_count)
      # }}}

      # Necklace {{{
      old_product = Necklace.find(3)

      start_image_count = old_product.images.count
      start_section_count = Section.count
      start_prodsection_count = old_product.section_count

      new_product = old_product.amoeba_dup
      new_product.save
      expect(new_product.errors.messages).to be_empty

      end_image_count = old_product.images.count
      end_newimage_count = new_product.images.count
      end_section_count = Section.count
      end_prodsection_count = first_product.section_count
      end_newprodsection_count = new_product.section_count

      expect(end_image_count).to eq(start_image_count)
      expect(end_newimage_count).to eq(start_image_count)
      expect(end_section_count).to eq(start_section_count)
      expect(end_prodsection_count).to eq(start_prodsection_count)
      expect(end_newprodsection_count).to eq(start_prodsection_count)
      # }}}
      # }}}
      # }}}
    end
  end

  context 'Using a if condition' do
    subject { post.amoeba_dup.save! }

    before(:all) do
      require ::File.dirname(__FILE__) + '/../support/data.rb'
    end

    before { ::Post.fresh_amoeba }

    let(:post) { Post.first }

    it 'includes an association with truthy condition' do
      ::Post.amoeba do
        include_association :comments, if: :truthy?
      end
      expect { subject }.to change(Comment, :count).by(3)
    end

    it 'does not include an association with a falsey condition' do
      ::Post.amoeba do
        include_association :comments, if: :falsey?
      end
      expect { subject }.not_to change(Comment, :count)
    end

    it 'excludes an association with a truthy condition' do
      ::Post.amoeba do
        exclude_association :comments, if: :truthy?
      end
      expect { subject }.not_to change(Comment, :count)
    end

    it 'does not exclude an association with a falsey condition' do
      ::Post.amoeba do
        exclude_association :comments, if: :falsey?
      end
      expect { subject }.to change(Comment, :count).by(3)
    end

    it 'includes associations from a given array with a truthy condition' do
      ::Post.amoeba do
        include_association [:comments], if: :truthy?
      end
      expect { subject }.to change(Comment, :count).by(3)
    end

    it 'does not include associations from a given array with a falsey condition' do
      ::Post.amoeba do
        include_association [:comments], if: :falsey?
      end
      expect { subject }.not_to change(Comment, :count)
    end

    it 'does exclude associations from a given array with a truthy condition' do
      ::Post.amoeba do
        exclude_association [:comments], if: :truthy?
      end
      expect { subject }.not_to change(Comment, :count)
    end

    it 'does not exclude associations from a given array with a falsey condition' do
      ::Post.amoeba do
        exclude_association [:comments], if: :falsey?
      end
      expect { subject }.to change(Comment, :count).by(3)
    end
  end

  context 'override' do
    before do
      ::Image.fresh_amoeba
      ::Image.amoeba do
        override ->(old, new) { new.product_id = 13 if old.filename == 'test.jpg' }
      end
    end

    it 'overrides fields' do
      image = ::Image.create(filename: 'test.jpg', product_id: 12)
      image_dup = image.amoeba_dup
      expect(image_dup.save).to be_truthy
      expect(image_dup.product_id).to eq(13)
    end

    it 'does not override fields' do
      image = ::Image.create(filename: 'test2.jpg', product_id: 12)
      image_dup = image.amoeba_dup
      expect(image_dup.save).to be_truthy
      expect(image_dup.product_id).to eq(12)
    end
  end

  context 'nullify' do
    before do
      ::Image.fresh_amoeba
      ::Image.amoeba do
        nullify :product_id
      end
    end

    let(:image) { ::Image.create(filename: 'test.jpg', product_id: 12) }
    let(:image_dup) { image.amoeba_dup }

    it 'nullifies fields' do
      expect(image_dup.save).to be_truthy
      expect(image_dup.product_id).to be_nil
    end
  end

  context 'strict propagate' do
    it 'calls #reset_amoeba' do
      expect(::SuperBlackBox).to receive(:reset_amoeba).and_call_original
      box = ::SuperBlackBox.create(title: 'Super Black Box', price: 9.99, length: 1, metal: '1')
      new_box = box.amoeba_dup
      expect(new_box.save).to be_truthy
    end
  end

  context 'remapping and custom dup method' do
    let(:prototype) { ObjectPrototype.new }

    context 'through' do
      it do
        real_object = prototype.amoeba_dup
        expect(real_object).to be_a(::RealObject)
      end
    end

    context 'remapper' do
      it do
        prototype.subobject_prototypes << SubobjectPrototype.new
        real_object = prototype.amoeba_dup
        expect(real_object.subobjects.length).to eq(1)
      end
    end
  end

  context 'preprocessing fields' do
    subject { super_admin.amoeba_dup }

    let(:super_admin) do
      ::SuperAdmin.create!(email: 'user@example.com', active: true, password: 'password')
    end

    it 'accepts "set" to set false to attribute' do
      expect(subject.active).to be false
    end

    it 'skips "prepend" if it equal to false' do
      expect(subject.password).to eq('password')
    end
  end

  context 'inheritance' do
    let(:box) { Box.create }

    it 'does not fail with a deep inheritance' do
      sub_sub_product = BoxSubSubProduct.create(title: 'Awesome shoes')
      another_product = BoxAnotherProduct.create(title: 'Cleaning product')
      sub_sub_product.update(box: box, another_product: another_product)
      expect(box.sub_products.first.another_product.title).to eq('Cleaning product')
      expect(box.amoeba_dup.sub_products.first.another_product.title).to eq('Cleaning product')
    end
  end

  context 'inheritance extended' do
    subject { stage.amoeba_dup }

    let(:stage) do
      stage = CustomStage.new(title: 'My Stage', external_id: 213)
      stage.listeners.build(name: 'John')
      stage.listeners.build(name: 'Helen')
      stage.specialists.build(name: 'Jack')
      stage.custom_rules.build(description: 'Kill all humans')
      stage.save!
      stage
    end

    it 'contains parent association and own associations', :aggregate_failures do
      subject
      expect { subject.save! }.to change(Listener, :count).by(2)
                                                          .and change(Specialist, :count).by(1)
                                                                                         .and change(
                                                                                           CustomRule, :count
                                                                                         ).by(1)

      expect(subject.title).to eq 'My Stage'
      expect(subject.external_id).to be_nil
      expect(subject.listeners.find_by(name: 'John')).not_to be_nil
      expect(subject.listeners.find_by(name: 'Helen')).not_to be_nil
      expect(subject.specialists.find_by(name: 'Jack')).not_to be_nil
      expect(subject.custom_rules.first.description).to eq 'Kill all humans'
    end
  end

  context 'polymorphic' do
    let(:company) { Company.find_by(name: 'ABC Industries') }
    let(:new_company) { company.amoeba_dup }

    it 'does not fail with a deep inheritance' do
      # employee = company.employees.where(name:'Joe').first
      start_company_count = Company.count
      start_customer_count = Customer.count
      start_employee_count = Employee.count
      start_address_count = Address.count
      start_photo_count = Photo.count
      new_company.name = "Copy of #{new_company.name}"
      new_company.save
      expect(Company.count).to eq(start_company_count + 1)
      expect(Customer.count).to eq(start_customer_count + 1)
      expect(Employee.count).to eq(start_employee_count + 1)
      expect(Address.count).to eq(start_address_count + 4)
      expect(Photo.count).to eq(start_photo_count + 2)

      new_company.reload # fully reload from database
      new_company_employees = new_company.employees
      expect(new_company_employees.count).to eq(1)
      new_company_employee_joe = new_company_employees.find_by(name: 'Joe')
      expect(new_company_employee_joe.photos.count).to eq(1)
      expect(new_company_employee_joe.photos.first.size).to eq(12_345)
      expect(new_company_employee_joe.addresses.count).to eq(2)
      expect(new_company_employee_joe.addresses.where(street: '123 My Street').count).to eq(1)
      expect(new_company_employee_joe.addresses.where(street: '124 My Street').count).to eq(1)
      new_company_customers = new_company.customers
      expect(new_company_customers.count).to eq(1)
      new_company_customer_my = new_company_customers.where(email: 'my@email.address').first
      expect(new_company_customer_my.photos.count).to eq(1)
      expect(new_company_customer_my.photos.first.size).to eq(54_321)
      expect(new_company_customer_my.addresses.count).to eq(2)
      expect(new_company_customer_my.addresses.where(street: '321 My Street').count).to eq(1)
      expect(new_company_customer_my.addresses.where(street: '321 My Drive').count).to eq(1)
    end
  end
end
