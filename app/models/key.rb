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

# Represents a unique identifier for a translatable string in a Project. The
# actual content of a key depends on the localization library used by that
# project.
#
# A Key has one base Translation, whose locale matches the Project's base
# locale, and zero or more sibling Translations in the other locales supported
# by the Project. When Translations in all required Locales are marked as
# approved, the Key is marked as ready. When all Keys applicable to a Commit are
# marked as ready, the Commit is marked as ready.
#
# Key uniqueness
# --------------
#
# A key must be unique to a Project (at the time of a specific Commit). However,
# it is not the case in all i18n libraries that a key is unique. For example,
# Android allows multiple strings to share the same key so long as they appear
# under different "qualifiers" (device properties); e.g., two strings can share
# a key if one is for landscape and the other for portrait orientations.
#
# To deal with this, this type of metadata is serialized into the `key` field
# (and therefore represented in the `key_sha_raw` column, on which uniqueness is
# enforced). The original value of the key without this metadata is written to
# the `original_key` field.
#
# Source copy
# -----------
#
# Keys are uniquely referenced in combination with their source copy; in other
# words, when a key's source copy changes, a new Key is generated.
#
# Associations
# ============
#
# |                |                                                                           |
# |:---------------|:--------------------------------------------------------------------------|
# | `project`      | The {Project} this Key belongs to.                                        |
# | `translations` | The {Translation Translations} of this Key's copy into different locales. |
# | `commits`      | The {Commit Commits} this Key can be found in.                            |
# | `blobs`        | The {Blob Blobs} this Key can be found in.                                |
#
# Fields
# ======
#
# |         |                                                                          |
# |:--------|:-------------------------------------------------------------------------|
# | `ready` | `true` when every required Translation under this Key has been approved. |
#
# Metadata
# ========
#
# |                |                                                                                                                          |
# |:---------------|:-------------------------------------------------------------------------------------------------------------------------|
# | `key`          | The identifier for this string in the project's code, potentially with serialized metadata to ensure uniqueness.         |
# | `original_key` | The identifier for this string in the project's code, as it originally appeared in the code.                             |
# | `source_copy`  | The original source copy of the key. Used to ensure that a new Key is generated if the source copy changes.              |
# | `context`      | A human-readable contextual description of the string, from the program's code.                                          |
# | `importer`     | The name of the {Importer::Base} subclass that created the Key.                                                          |
# | `source`       | The path to the project file where the base string was found.                                                            |
# | `fencers`      | An array of fencers that should be applied to the Translations of this string.                                           |
# | `other_data`   | A hash of importer-specific information applied to the string. Not used by anyone except possible the importer/exporter. |

class Key < ActiveRecord::Base
  belongs_to :project, inverse_of: :keys
  has_many :translations, inverse_of: :key, dependent: :destroy
  has_many :commits_keys, inverse_of: :key, dependent: :destroy
  has_many :commits, through: :commits_keys
  has_many :blobs_keys, dependent: :delete_all, inverse_of: :key
  has_many :blobs, through: :blobs_keys
  has_many :key_groups_keys, dependent: :delete_all, inverse_of: :key
  has_many :key_groups, through: :key_groups_keys

  include HasMetadataColumn
  has_metadata_column(
      key:          {presence: true},
      original_key: {presence: true},
      source_copy:  {allow_blank: true},
      context:      {allow_nil: true},
      importer:     {allow_nil: true},
      source:       {allow_nil: true},
      fencers:      {type: Array, default: []},
      other_data:   {type: Hash, default: {}}
  )

  before_validation { |obj| obj.source_copy = '' if obj.source_copy.nil? }
  before_validation(on: :create) { |obj| obj.original_key ||= obj.key }

  # @return [true, false] If `true`, the after-save hooks that recalculate
  #   Commit `ready?` values will not be run. You should use this when
  #   processing a large batch of Keys.
  attr_accessor :skip_readiness_hooks

  # @private
  attr_accessor :batched_commit_ids

  def apply_readiness_hooks?() !skip_readiness_hooks end
  private :apply_readiness_hooks?

  extend DigestField
  digest_field :key, scope: :for_key
  digest_field :source_copy, scope: :source_copy_matches

  include Tire::Model::Search
  include Tire::Model::Callbacks
  settings analysis: {tokenizer: {key_tokenizer: {type: 'pattern', pattern: '[^A-Za-z0-9]'}},
           analyzer: {key_analyzer: {type: 'custom', tokenizer: 'key_tokenizer', filter: 'lowercase'}}}
  mapping do
    indexes :original_key, type: 'multi_field', as: 'original_key', fields: {
        original_key:       {type: 'string', analyzer: 'key_analyzer'},
        original_key_exact: {type: 'string', index: :not_analyzed}
    }
    indexes :project_id, type: 'integer'
    indexes :ready, type: 'boolean'
    indexes :commit_ids, as: 'batched_commit_ids.try!(:to_a) || commits_keys.pluck(:commit_id)'
  end

  after_update :update_commit_and_key_group_readiness, if: :apply_readiness_hooks?

  validates :project,
            presence: true
  validates :source_copy_sha_raw,
            presence:   true
  validates :key_sha_raw,
            presence:   true,
            uniqueness: {scope: [:project_id, :source_copy_sha_raw], on: :create}

  attr_readonly :project_id, :key, :original_key, :source_copy

  scope :in_blob, ->(blob) { where(project_id: blob.project_id, sha_raw: blob.sha_raw) }

  def key_group
    key_groups.last
  end

  # TODO:
  def self.total_strings
    Key.count
  end
  # redis_memoize :total_strings

  # TODO:
  def self.total_strings_incomplete
    Key.where(ready: false).count
  end 
  # redis_memoize :total_strings_incomplete

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :source_fences << :fences << :original_key << :key
    options[:methods] << :importer_name

    options[:except] = Array.wrap(options[:except])
    options[:except] << :key_sha_raw << :searchable_key << :metadata
    options[:except] << :project_id
    options[:except] << :source_copy_sha_raw

    super options
  end

  # @return [Class] The {Importer::Base} subclass that performed the import.
  def importer_class() Importer::Base.find_by_ident(importer) end

  # @return [String] The human-readable name for the importer.
  def importer_name() importer_class.human_name end

  # Scans all of the base Translations under this Key and adds Translations for
  # each of the required locales and base locale where such a Translation
  # does not already exist.
  #
  # If this key is associated with a key_group, base_locale and targeted_locales are
  # retrieved from the KeyGroup. Otherwise, they are retrieved from Project.
  #
  # This is used, for example, when a Project adds a new required localization,
  # to create pending Translation requests for each string in the new locale.

  def add_pending_translations
    base_locale = key_group ? key_group.base_locale : project.base_locale
    targeted_locales = key_group ? key_group.locale_requirements.keys : project.targeted_locales

    translations.in_locale(base_locale).find_or_create!(
        source_copy:              source_copy,
        copy:                     source_copy,
        source_rfc5646_locale:    base_locale.rfc5646,
        rfc5646_locale:           base_locale.rfc5646,
        approved:                 true,
        preserve_reviewed_status: true)

    targeted_locales.each do |locale|
      next if !key_group && project.skip_key?(key, locale)
      translations.in_locale(locale).find_or_create!(
        source_locale: base_locale,
        locale: locale,
        source_copy: source_copy,
        skip_readiness_hooks: true
      )
    end
  end

  # Scans all of the Translations under this Tree and removes translations that
  # should be excluded based on the Project's `key_*clusions` and
  # `key_locale_*clusions`. Translations that have been translated or
  # approved are never removed, only pending Translations.

  def remove_excluded_pending_translations
    translations.where(approved: nil, translated: false).find_each do |translation|
      if (!key_group && project.skip_key?(key, translation.locale)) ||
          (key_group && !key_group.skip_locale?(translation.locale))
        translation.destroy
      end
    end
  end

  # Recalculates the value of the `ready` column and updates the record.

  def recalculate_ready!
    ready_was = ready?
    ready = should_become_ready?
    update_column :ready, ready

    # update_column doesn't run hooks and doesn't change the changes array so
    # we need to force-update update_commit_and_key_group_readiness
    if !skip_readiness_hooks && ready != ready_was
      update_commit_and_key_group_readiness(true)
    end
    tire.update_index
  end

  # @return [true, false] `true` if this Key should now be marked as ready.

  def should_become_ready?
    if translations.loaded?
      translations.select { |t| required_locales.include?(t.locale) }.all?(&:approved?)
    else
      !translations.in_locale(*required_locales).where('approved IS NOT TRUE').exists?
    end
  end

  def required_locales
    key_group ? key_group.required_locales : project.required_locales
  end

  # @private
  def inspect(default_behavior=false)
    return super() if default_behavior
    state = ready? ? 'ready' : 'not ready'
    "#<#{self.class.to_s} #{id}: #{key} (#{state})>"
  end

  private

  def update_commit_and_key_group_readiness(force=false)
    return if !ready_changed? && !force
    KeyReadinessRecalculator.perform_once id
  end

end
