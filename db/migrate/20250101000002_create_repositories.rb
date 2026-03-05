class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.bigint :github_id,   null: false
      t.string :name
      t.string :full_name
      t.text   :description
      t.string :url
      t.jsonb  :raw_payload, null: false, default: {}
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :repositories, :github_id, unique: true
    add_index :repositories, :full_name
  end
end
