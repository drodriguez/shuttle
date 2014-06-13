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

describe Importer::KeyGroup do
  describe "#rebase_existing_keys" do
    let(:key_group) {FactoryGirl.create(:key_group, source_copy: "<p>paragraph a</p><p>paragraph b</p><p>paragraph c</p>", base_rfc5646_locale: :en, targeted_rfc5646_locales: {fr: true})}
    it "should rebase keys if there is an addition to the end" do

      expect(key_group.keys.count).to eql(3)

      key_group.translations.each { |t| t.update!(copy: "asdsgfdh", skip_readiness_hooks: true) }
      key_group.translations.each { |t| t.update!(approved: true) }
      p key_group.reload.ready?

      importer = Importer::KeyGroup.new(key_group)

      p "STARTING REIMPORT"
      p key_group.reload.keys.map(&:key)
      importer.send(:rebase_existing_keys, importer.send(:split_into_paragraphs, "<p>paragraph a</p><p>paragraph b</p><p>paragraph c</p><p>paragraph d</p>"))
      p key_group.reload.keys.map(&:ready?)
      p key_group.reload.keys.map(&:key)
      p key_group.reload.ready?
    end
  end
end
