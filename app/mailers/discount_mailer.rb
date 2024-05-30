# frozen_string_literal: true

class DiscountMailer < ApplicationMailer
    def discount_email(user)
        return if user.email.blank?
        
        @user = user
        @discount = user.discount
        mail(to:  @user.email, from: ENV['FRUITS_EMAIL_SUPPORT'], subject: 'Discount')
    end
end