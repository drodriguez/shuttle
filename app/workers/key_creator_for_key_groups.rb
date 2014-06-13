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

class KeyCreatorForKeyGroups
  include Sidekiq::Worker
  sidekiq_options queue: :high

  def perform(key_group_id, source_copy, index, job_id)
    key_group = KeyGroup.find_by_id(key_group_id)

    create_key_and_associations(key_group, source_copy, index)

    key_group.remove_worker! job_id
  end

  def create_key_and_associations(key_group, source_copy, index)
    # create key
    key_name = "#{index}:#{key_group.key_sha}:#{Key.new(source_copy: source_copy).tap(&:valid?).source_copy_sha}"
    key = key_group.project.keys.for_key(key_name).source_copy_matches(source_copy).find_or_create!(
      key:                  key_name,
      source_copy:          source_copy,
      skip_readiness_hooks: true,
      ready: false
    )

    # associate key with key_group
    key_group.key_groups_keys.where(key: key).find_or_create!

    # add missing translations for base and target locales
    key.add_pending_translations
  end

  include SidekiqLocking
end
