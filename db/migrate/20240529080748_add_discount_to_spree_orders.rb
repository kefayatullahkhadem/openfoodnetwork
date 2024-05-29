class AddDiscountToSpreeOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_orders, :discount, :integer
  end
end
