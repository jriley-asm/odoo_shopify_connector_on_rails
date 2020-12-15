class CreateShopifyInstances < ActiveRecord::Migration[6.0]
  def change
    create_table :shopify_instances do |t|
      t.string :api_key
      t.string :password
      t.string :shop_name

      t.timestamps
    end
  end
end
