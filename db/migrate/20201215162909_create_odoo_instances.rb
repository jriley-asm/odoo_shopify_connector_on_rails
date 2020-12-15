class CreateOdooInstances < ActiveRecord::Migration[6.0]
  def change
    create_table :odoo_instances do |t|
      t.string :url
      t.string :db
      t.string :username
      t.string :password

      t.timestamps
    end
  end
end
