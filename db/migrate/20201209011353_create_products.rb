class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :products do |t|
      t.string :pull_status
      t.string :push_status
      t.integer :odoo_id

      t.timestamps
    end
  end
end
