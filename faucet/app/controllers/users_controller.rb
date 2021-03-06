class UsersController < ApplicationController
  before_action :authenticate_user!

  def profile
    redirect_to bitshares_account_path if current_user.pending_intention and current_user.pending_intention[:pending_registration]

    @user = current_user
    @referral = ReferralCode.new
  end

  def bitshares_account
    @subscription_status = current_user.newsletter_subscribed

    if current_user.pending_intention and current_user.pending_intention[:pending_registration]
      reg = current_user.pending_intention[:pending_registration]
      do_register(reg['account_name'], reg['account_key'], reg['owner_key'])
      current_user.set_pending_registration(nil)
    elsif params[:account]
      do_register(params[:account][:name], params[:account][:key], nil)
    else
      @reg_status = nil
    end
  end

  def finish_signup
    @hide_sign_in = true
    user = current_user

    if user.email_verified? && user.confirmed_at
      redirect_to root_path, notice: 'You have already confirmed your email.'
    end

    if request.patch? && params[:user] && params[:user][:email]
      if user.update_attributes(email: params[:user][:email])
        sign_in(user, :bypass => true)
        redirect_to profile_path, notice: "We've sent you a confirmation link."
      else
        redirect_to :back, alert: 'Please provide a valid email'
      end
    end
  end

  def subscribe
    new_status = !current_user.newsletter_subscribed
    status = params[:status] == new_status ? params[:status] : new_status
    subscription = current_user.subscribe(status)

    if subscription.is_a?(Hash)
      current_user.update_attribute(:newsletter_subscribed, status)
      render json: {res: render_to_string('_subscribe', layout: false, locals: {status: status})}
    else
      render json: {res: subscription.to_s}
    end
  end

  private

  def do_register(account_name, account_key, owner_key)
    logger.info "---------> registering account #{account_name}, key: #{account_key}, owner_key: #{owner_key}"
    sleep(0.4) # this is to prevent bots abuse
    @reg_status = AccountRegistrator.new(current_user, logger).register(account_name, account_key, owner_key, cookies[:_ref_account])

    if @reg_status[:error]
      flash[:alert] = "We were unable to register account '#{account_name}' - #{@reg_status[:error][0..512]}"
      @account = OpenStruct.new(name: account_name, key: account_key, owner_key: owner_key)
    end
  end
end
