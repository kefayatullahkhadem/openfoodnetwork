class AddDiscountToSpreeUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_users, :discount, :integer
  end
end
