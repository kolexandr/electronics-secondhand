class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :display_name, null: false, limit: 80
      t.string :email_address, null: false, limit: 254
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
