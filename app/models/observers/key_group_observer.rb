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

# This observer on the {KeyGroup} model...

class KeyGroupObserver < ActiveRecord::Observer
  def before_save(key_group)
    set_import_finished_at(key_group)
  end

  # Be careful not to write any code that runs callbacks in after_commit hooks, unless it is the last method in the after_commit hook.
  # Remember that calling save on the record in its after_commit hook will change the previous_changes hash.
  def after_commit(key_group)
    cached_previous_changes = ActiveSupport::HashWithIndifferentAccess.new(key_group.previous_changes) # cache the previous changes in case save method is called somewhere in this after_commit.
    import_key_group_if_necessary!(key_group, cached_previous_changes)
    recalculate_full_readiness!(key_group, cached_previous_changes)
  end

  private

  def set_import_finished_at(key_group)
    # if loading is just finished
    if key_group.loading_was && !key_group.loading
      key_group.last_import_finished_at = Time.current
      key_group.first_import_finished_at ||= key_group.last_import_finished_at
    end
  end

  def import_key_group_if_necessary!(key_group, cached_previous_changes)
    key_group.import! if KeyGroup::FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED.any? {|field| cached_previous_changes.include?(field)}
  end

  # First, checks each key. Then, checks the key_group
  def recalculate_full_readiness!(key_group, cached_previous_changes)
    # if loading was previously finished
    if cached_previous_changes.include?('loading') && cached_previous_changes['loading'].first && !cached_previous_changes['loading'].last
      key_group.keys.each do |key|
        key.skip_readiness_hooks = true
        key.recalculate_ready!
      end
      key_group.recalculate_ready!
    end
  end
end
