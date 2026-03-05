class CreateActors < ActiveRecord::Migration[8.0]
  def change
    create_table :actors do |t|
      t.bigint  :github_id,    null: false
      t.string  :login,        null: false
      t.string  :display_login
      t.string  :avatar_url
      t.string  :url
      t.jsonb   :raw_payload,  null: false, default: {}
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :actors, :github_id, unique: true
    add_index :actors, :login
  end
end
