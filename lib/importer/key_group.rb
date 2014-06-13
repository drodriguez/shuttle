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

require 'set'

module Importer

  class KeyGroup
    def initialize(key_group)
      @key_group = key_group
    end

    def import_strings
      @key_group.update_import_started_at!
      @key_group.reset_ready! # in case readiness changed from the time import method was called to now
      # add us as one of the workers, to prevent the commit from prematurely going
      # ready; let's just invent a job ID for us
      job_id = SecureRandom.uuid
      @key_group.add_worker! job_id

      paragraphs = split_into_paragraphs(@key_group.source_copy)

      rebase_existing_keys(paragraphs) # so that we can re-use the unchanged portions of the source copy

      @key_group.key_groups_keys.delete_all # clean associations between key_groups and keys so that we can start fresh

      paragraphs.each.with_index do |paragraph, index|
        shuttle_jid = SecureRandom.uuid
        @key_group.add_worker! shuttle_jid

        KeyCreatorForKeyGroups.perform_once(@key_group.id, paragraph, index, shuttle_jid)
      end

      @key_group.remove_worker! job_id
    end

    private

    def rebase_existing_keys(new_paragraphs) # Ex: ["Hello a", "Hello c", "Hello e"]
      existing_keys = @key_group.sorted_keys(:translations) # Ex: [<Key 1: 0:x:a>, <Key 2: 1:x:b>, <Key 3: 2:x:c>, <Key 4: 10:x:d>]
      existing_key_names = existing_keys.map(&:key) # Ex: ['0:x:a', '1:x:b', '2:x:c', '10:x:d']
      existing_paragraphs = existing_keys.map(&:source_copy) # Ex: ["Hello a", "Hello b", "Hello c", "Hello d"]

      sdiff = Diff::LCS.sdiff(existing_paragraphs, new_paragraphs) # Ex: [["=", [0, "Hello a"], [0, "Hello a"]], ["-", [1, "Hello b"], [1, nil]], ["=", [2, "Hello c"], [1, "Hello c"]], ["!", [3, "Hello d"], [2, "Hello e"]]]

      Key.transaction do
        reset_approved_states_if_neighbor_changed!(existing_keys, sdiff)
        update_indexes_of_unchanged_keys!(existing_keys, sdiff)
      end
        # TODO (yunus): test against collisions from previous artifacts
    end

    def reset_approved_states_if_neighbor_changed!(existing_keys, sdiff)
      # Find keys whose neighbors have changed
      keys_to_be_marked_pending = Set.new
      sdiff.each do |diff|
        unless diff.unchanged?
          keys_to_be_marked_pending.add(existing_keys[diff.old_position-1]) if diff.old_position > 0
          keys_to_be_marked_pending.add(existing_keys[diff.old_position+1]) if diff.old_position < existing_keys.length - 1
        end
      end

      # Reset translations' approved status for keys whose neighbors have changed
      keys_to_be_marked_pending.each do |key|
        key.translations.each do |translation|
          translation.update!(approved: false, skip_readiness_hooks: true) if translation.approved?
        end
        key.recalculate_ready!
      end
    end

    def update_indexes_of_unchanged_keys!(existing_keys, sdiff)
      # Find which keys need to be rebased
      index_changes = sdiff.select { |diff| diff.unchanged? && (diff.old_position != diff.new_position) } # [["=", [2, "Hello c"], [1, "Hello c"]]]

      # First, change the key names to different key names that would not normally be found in the database.
      # This will handle [a, a] -> [c, a, a]
      index_changes.each_with_index do |change, i|
        key = existing_keys[change.old_position] # Ex: <Key 3: 2:x:c>
        key.update!(key: "_old_:#{key.key}", skip_readiness_hooks: true)
      end

      # Set the updated key names with updated indexes
      index_changes.each_with_index do |change, i|
        key = existing_keys[change.old_position] # Ex: <Key 3: 2:x:c>
        new_key_name = existing_key_names[change.old_position].split(':').tap{|key_name_arr| key_name_arr[0] = change.new_position.to_s}.join(':')  # Ex: <Key 3: 1:x:c>
        @key_group.project.keys.for_key(new_key_name).source_copy_matches(change.new_element).each{|key| key.destroy} # remove old keys that could be a conflict
        # TODO (yunus): test if deleting a key removes it from tire
        key.update!(key: new_key_name, skip_readiness_hooks: true)
      end
    end

    def split_into_paragraphs(text)
      # TODO (yunus): some magic is needed here
      text.split(/(?=<p>.+?<\/p>)/m)
      #text.split(/(<p>.+?<\/p>)|(?<=\n\n)/m)
      # /(?=<p>.+?<\/p>)/
    end

  end
end
