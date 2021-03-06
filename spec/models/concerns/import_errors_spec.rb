# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe ImportErrors do
  before(:each) do
    @commit = FactoryGirl.build(:commit)
  end

  it "should return import errors in redis" do
    Shuttle::Redis.sadd("commit:#{@commit.revision}:import_errors", "path/to/some/file this is a fake error")
    expect(@commit.import_errors_in_redis).to eql([["path/to/some/file", "this is a fake error"]])
  end

  it "should add an import error to commit in redis" do
    @commit.add_import_error_in_redis("path/to/some/file", "some error")
    expect(@commit.import_errors_in_redis).to eql([["path/to/some/file", "some error"]])
  end

  it "should clear all import errors of a commit in redis" do
    @commit.add_import_error_in_redis("path/to/first/file", "first error")
    @commit.add_import_error_in_redis("path/to/second/file", "second error")
    expect(@commit.import_errors_in_redis.length).to eql(2)
    @commit.send(:clear_import_errors_in_redis)
    expect(@commit.import_errors_in_redis).to eql([])
  end

  it "should clear all import errors of a commit in redis and postgres" do
    @commit.add_import_error_in_redis("path/to/first/file", "first error")
    @commit.update_attributes(import_errors: [["path/to/first/file", "first error"]])
    expect(@commit.import_errors_in_redis).to eql([["path/to/first/file", "first error"]])
    expect(@commit.import_errors).to eql([["path/to/first/file", "first error"]])

    @commit.clear_import_errors
    expect(@commit.import_errors_in_redis).to eql([])
    expect(@commit.import_errors).to eql([])
  end

  it "should copy_import_errors_from_redis_to_sql_db" do
    @commit.save
    @commit.add_import_error_in_redis("path/to/first/file", "first error")
    @commit.copy_import_errors_from_redis_to_sql_db
    expect(@commit.import_errors).to eql([["path/to/first/file", "first error"]])
  end

  it "should return the correct redis key" do
    expect(@commit.send(:import_errors_redis_key)).to eql("commit:#{@commit.revision}:import_errors")
  end
end
