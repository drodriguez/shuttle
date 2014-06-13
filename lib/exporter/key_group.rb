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

module Exporter
  # Exports the translated strings of a KeyGroup to a json representation.

  class KeyGroup
    def initialize(key_group)
      @key_group = key_group
      @sorted_keys = @key_group.sorted_keys(:translations)
      @sorted_translations_indexed_by_locale = @sorted_keys.map do |key|
        keys.translations.index_by { |t| t.locale }
      end
    end

    def export(locales = @key_group.required_locales)
      raise InputError.new("No Locale(s) Inputted") unless locales.present?

      if locales.is_a? String
        locales = locales.split(",").map do |rfc5646|
          locale = Locale.from_rfc5646(rfc5646)
          raise InputError.new("Locale '#{rfc5646}' could not be found.") unless locale
          locale
        end
      end

      locales.each do |locale|
        raise InputError.new("Inputted locale '#{locale}' is not one of the required locales for this key group.") if @key_group.required_locales.include?(locale)
      end

      raise NotReadyError unless @key_group.ready?

      locales.inject({}) do |hsh, locale|
        hsh[locale.rfc5646] = export_locale(locale)
        hsh
      end
    end

    private

    # assumes locale is valid and required in this key_group
    def export_locale(locale)
      copies = @sorted_translations_indexed_by_locale.map.with_index do |locales, index|
        translation = locales_hsh[locale]
        # TODO (yunus) squash notify
        raise MissingTranslation.new("Missing translation in locale #{locale} for key #{@sorted_keys[index]}") unless translation # why do this check? key.recalculate_ready? doesn't verify all translation records exist.
        translation.copy
      end
      copies.join
    end

    # ======== START ERRORS ==============================================================================================
    class Error < StandardError; end
    class NotReadyError < Error; end # Raised when a KeyGroup is not marked as ready.
    class MissingTranslation < Error; end # Raised when a Translation was missing during export.
    class InputError < Error; end
    # ======== END ERRORS ================================================================================================
  end
end
# TODO (yunus): need to investigate this project.repo / git independence thing
