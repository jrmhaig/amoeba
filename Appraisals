# frozen_string_literal: true

appraise 'activerecord-6.1' do
  gem 'activerecord', '~> 6.1.0'
  gem 'concurrent-ruby', '<= 1.3.4'
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'
  gem 'logger'
  gem 'benchmark'
  group :development, :test do
    gem 'sqlite3', '~> 1.6.0'
  end
end

appraise 'activerecord-7.0' do
  gem 'activerecord', '~> 7.0.0'
  gem 'concurrent-ruby', '<= 1.3.4'
  group :development, :test do
    gem 'sqlite3', '~> 1.6.0'
  end
end

appraise 'activerecord-7.1' do
  gem 'activerecord', '~> 7.1.0'
  group :development, :test do
    gem 'sqlite3', '~> 1.6.0'
  end
end

appraise 'activerecord-8.0' do
  gem 'activerecord', '~> 8.0.0'
  group :development, :test do
    gem 'sqlite3', '~> 2.1.0'
  end
end

appraise 'activerecord-8.1' do
  gem 'activerecord', '~> 8.1.0'
  group :development, :test do
    gem 'sqlite3', '~> 2.1.0'
  end
end

appraise 'jruby-activerecord-7.0' do
  gem 'activerecord', '~> 7.0.0'
end

appraise 'activerecord-head' do
  git 'https://github.com/rails/rails.git', branch: 'main' do
    gem 'activerecord'
  end
  group :development, :test do
    gem 'sqlite3', '~> 2.1.0'
  end
end

appraise 'jruby-activerecord-head' do
  git 'https://github.com/rails/rails.git', branch: 'main' do
    gem 'activerecord'
  end
  group :development, :test do
    git 'https://github.com/jruby/activerecord-jdbc-adapter' do
      gem 'activerecord-jdbc-adapter'
      gem 'activerecord-jdbcsqlite3-adapter',
          glob: 'activerecord-jdbcsqlite3-adapter/activerecord-jdbcsqlite3-adapter.gemspec'
    end
  end
end
