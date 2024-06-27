# frozen_string_literal: true

module Spree
  module Admin
    class UsersController < ::Admin::ResourceController
      rescue_from Spree::User::DestroyWithOrdersError, with: :user_destroy_with_orders_error

      after_action :sign_in_if_change_own_password, only: :update

      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_action :check_json_authenticity, only: :index
      before_action :load_roles, only: [:edit, :new, :update, :create,
                                        :generate_api_key, :clear_api_key]

      def index
        @pagy, @users = pagy(@collection, items: params[:per_page] || 15)
        
        respond_to do |format|
          format.html
          format.json do
            render json: { 
              pagy: pagy_metadata(@pagy), 
              users_html: render_to_string(partial: "spree/admin/users/table", locals: { pagy: @pagy, users: @users }) 
            }
          end
        end
      end

      def create
        if params[:user]
          roles = params[:user].delete("spree_role_ids")
        end

        @user = Spree::User.new(user_params)
        if @user.save

          if roles
            @user.spree_roles = roles.reject(&:blank?).collect{ |r| Spree::Role.find(r) }
          end

          flash.now[:success] = Spree.t(:created_successfully)
          render :edit
        else
          render :new
        end
      end

      def update
        if params[:user]
          roles = params[:user].delete("spree_role_ids")
        end

        old_discount = @user.discount
        if @user.update(user_params)
          
          if @user.discount != old_discount
            DiscountMailer.discount_email(@user).deliver_now
          end

          if roles
            @user.spree_roles = roles.reject(&:blank?).collect{ |r| Spree::Role.find(r) }
          end

          flash.now[:success] = update_message
        end
        render :edit
      end

      protected

      def collection
        return @collection if @collection.present?

        if request.xhr? && params[:q].present?
          result = Spree::User.
            includes(:bill_address, :ship_address).
            where("spree_users.email #{LIKE} :search
                    OR (spree_addresses.firstname #{LIKE} :search
                      AND spree_addresses.id = spree_users.bill_address_id)
                    OR (spree_addresses.lastname  #{LIKE} :search
                      AND spree_addresses.id = spree_users.bill_address_id)
                    OR (spree_addresses.firstname #{LIKE} :search
                      AND spree_addresses.id = spree_users.ship_address_id)
                    OR (spree_addresses.lastname  #{LIKE} :search
                      AND spree_addresses.id = spree_users.ship_address_id)",
                  search: "#{params[:q].strip}%").
            limit(params[:limit] || 100)
      
          if params[:q][:enterprise_id_in].present?
            result = result.joins(:enterprises).where('enterprises.id IN (?)', params[:q][:enterprise_id_in])
          end
      
          @collection = result
        else
          @search = Spree::User.ransack(params[:q])
          result = @search.result
      
          if params[:q] && params[:q][:enterprise_id_in].present?
            result = result.joins(:enterprises).where('enterprises.id IN (?)', params[:q][:enterprise_id_in])
          end
      
          @pagy, @collection = pagy(result, items: params[:per_page]&.to_i || Spree::Config[:admin_products_per_page])
        end
      
        @collection
      end      

      private

      def update_message
        return Spree.t(:show_api_key_view_toggled) if @user.show_api_key_view_previously_changed?

        if new_email_unconfirmed?
          Spree.t(:email_updated)
        else
          Spree.t(:account_updated)
        end
      end

      # handling raise from Admin::ResourceController#destroy
      def user_destroy_with_orders_error
        render status: :forbidden, text: Spree.t(:error_user_destroy_with_orders)
      end

      # Allow different formats of json data to suit different ajax calls
      def json_data
        json_format = params[:json_format] || 'default'
        case json_format
        when 'basic'
          collection.map { |u| { 'id' => u.id, 'name' => u.email } }.to_json
        else
          address_fields = [:firstname, :lastname, :address1, :address2, :city,
                            :zipcode, :phone, :state_name, :state_id, :country_id]
          includes = { only: address_fields, include: { state: { only: :name },
                                                        country: { only: :name } } }

          collection.to_json(only: [:id, :email], include:
                             { bill_address: includes, ship_address: includes })
        end
      end

      def sign_in_if_change_own_password
        return unless spree_current_user == @user && @user.password.present?

        sign_in(@user, event: :authentication, bypass: true)
      end

      def load_roles
        @roles = Spree::Role.select('DISTINCT ON (name) *')
      end

      def new_email_unconfirmed?
        params[:user][:email] != @user.email
      end

      def user_params
        ::PermittedAttributes::User.new(params).call(
          %i[enterprise_limit show_api_key_view]
        )
      end
    end
  end
end
