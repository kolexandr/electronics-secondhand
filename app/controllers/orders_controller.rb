class OrdersController < ApplicationController
  def show
    @order = Order.joins(:listing).includes(:buyer, :reservation, listing: :seller)
      .where("orders.buyer_id = :user_id OR listings.seller_id = :user_id", user_id: Current.user.id).find(params[:id])
  end
end
