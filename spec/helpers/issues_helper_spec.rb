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

require "spec_helper"

describe IssuesHelper do
  describe "#issue_url" do
    before(:all) do
      @issue = FactoryGirl.create(:issue)
      @translation = @issue.translation
      @key = @translation.key
      @project = @key.project
    end

    before(:each) do
      @expected_url = helper.project_key_translation_url(@project, @key, @translation) + "#issue-wrapper-#{@issue.id}"
    end

    it "should return the correct uri given an issue" do
      expect(helper.issue_url(@issue)).to eql(@expected_url)
    end

    it "should raise an Argument error given nil" do
      expect{ helper.issue_url(nil) }.to raise_error(ArgumentError)
    end

    it "should raise an Argument error given a record which is not an Issue" do
      expect{ helper.issue_url(@issue.translation) }.to raise_error(ArgumentError)
    end
  end
end
