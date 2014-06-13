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

class CreateKeyGroupsKeys < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE key_groups_keys (
        key_group_id integer NOT NULL REFERENCES key_groups(id) ON DELETE CASCADE,
        key_id       integer NOT NULL REFERENCES keys(id)       ON DELETE CASCADE,
        PRIMARY KEY (key_group_id, key_id),
        created_at timestamp without time zone,
        updated_at timestamp without time zone
      )
    SQL

    execute "CREATE INDEX key_groups_keys_key_id ON key_groups_keys(key_id)"
    execute "CREATE INDEX key_groups_keys_key_group_id ON key_groups_keys(key_group_id)"
  end

  def down
    drop_table :key_groups_keys
  end
end
