# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :key_group do
    project
    sequence(:key) { |i| "key-#{i}" }
    source_copy "Hello, world"
  end
end
