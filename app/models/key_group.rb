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

class KeyGroup < ActiveRecord::Base
  FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED = %w(source_copy targeted_rfc5646_locales)

  include SidekiqWorkerTracking

  belongs_to :project, inverse_of: :key_groups
  has_many :key_groups_keys, inverse_of: :key_group, dependent: :delete_all
  has_many :keys, through: :key_groups_keys
  has_many :translations, through: :keys

  extend DigestField
  digest_field :key, scope: :for_key
  digest_field :source_copy, scope: :source_copy_matches

  attr_readonly :project_id, :key

  validates :project, presence: true
  validates :key, presence: true
  validates :key_sha_raw, presence: true, uniqueness: {scope: :project_id}
  validates :source_copy, presence: true
  validates :source_copy_sha_raw, presence: true
  validates :description, length: {maximum: 2000}
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_nil: true
  validates :ready,   inclusion: { in: [true, false] }
  validates :loading, inclusion: { in: [true, false] }
  validates :first_import_requested_at,
            :first_import_started_at,
            :first_import_finished_at,
            :first_completed_at,
            :last_import_requested_at,
            :last_import_started_at,
            :last_import_finished_at,
            :last_completed_at,
                timeliness: {type: :date}, allow_nil: true

  # ======== START LOCALE RELATED CODE =================================================================================
  include HasMetadataColumn
  has_metadata_column(
      base_rfc5646_locale:      {format: {with: Locale::RFC5646_FORMAT}, allow_nil: true},
      targeted_rfc5646_locales: {type: Hash, allow_nil: true}
  ) # TODO (yunus): move out of metadatas

  include CommonLocaleLogic

  def base_locale_with_inheriting
    base_locale_without_inheriting || project.base_locale
  end

  def locale_requirements_with_inheriting
    locale_requirements_without_inheriting || project.locale_requirements
  end

  alias_method_chain(:base_locale, :inheriting)
  alias_method_chain(:locale_requirements, :inheriting)

  # ======== END LOCALE RELATED CODE ===================================================================================

  # ======== START IMPORT RELATED CODE =================================================================================
  # This should be the point of entry
  def import!
    update_import_requested_at!
    reset_ready!
    KeyGroupImporter.perform_once(id)
  end
  # ======== END IMPORT RELATED CODE ===================================================================================

  # override because index is on key_sha_raw field, and searching with that field is faster.
  # may be worth considering putting this kind of support in the digest_field module
  def self.find_by_key(k)
    for_key(k).last if k
  end

  def sorted_keys(associations_to_include = nil)
    query = keys
    query = query.includes(associations_to_include) if associations_to_include
    query.sort_by{|k| k.key.split(':').first.to_i} # Ex: [<Key 1: 0:x:a>, <Key 2: 1:x:b>, <Key 3: 2:x:c>, <Key 4: 10:x:d>]
  end

  # Calculates the value of the `ready` field and saves the record.
  def recalculate_ready!
    keys_are_ready = !keys.where(ready: false).exists?
    if !ready? && keys_are_ready # if it just became ready
      self.last_completed_at = Time.current
      self.first_completed_at ||= self.last_completed_at
    end
    self.ready = keys_are_ready
    save!
  end

  def reset_ready!
    update!(ready: false) if ready?
    keys.each { |key| key.update!(ready: false) if key.ready? }
  end

  def skip_locale?(locale)
    !locale_requirements.keys.include?(locale)
  end

  def update_import_requested_at!
    new_attrs = {last_import_requested_at: Time.current}
    new_attrs[:first_import_requested_at] ||= new_attrs[:last_import_requested_at]
    self.update!(new_attrs)
  end
  private :update_import_requested_at!

  def update_import_started_at!
    new_attrs = {last_import_started_at: Time.current}
    new_attrs[:first_import_started_at] ||= new_attrs[:last_import_started_at]
    update!(new_attrs)
  end
end
