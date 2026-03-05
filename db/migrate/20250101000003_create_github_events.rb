class CreateGithubEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :github_events do |t|
      t.string  :event_id,            null: false
      t.string  :event_type,          null: false
      t.string  :repo_identifier
      t.string  :repo_name
      t.bigint  :push_id
      t.string  :ref
      t.string  :head
      t.string  :before
      t.bigint  :actor_github_id
      t.bigint  :repository_github_id
      t.references :actor,       foreign_key: true
      t.references :repository,  foreign_key: true
      t.jsonb   :raw_payload,         null: false, default: {}

      t.timestamps
    end

    add_index :github_events, :event_id,            unique: true
    add_index :github_events, :repo_name
    add_index :github_events, :event_type
    add_index :github_events, :actor_github_id
    add_index :github_events, :repository_github_id
    add_index :github_events, :created_at
  end
end
