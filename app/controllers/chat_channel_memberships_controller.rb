class ChatChannelMembershipsController < ApplicationController
  after_action :verify_authorized
  include MessagesHelper

  def index
    skip_authorization
    @pending_invites = current_user.chat_channel_memberships.includes(:chat_channel).where(status: "pending")
  end

  def find_by_chat_channel_id
    @membership = ChatChannelMembership.where(chat_channel_id: params[:chat_channel_id], user_id: current_user.id).first!
    authorize @membership
    render json: @membership.to_json(
      only: %i[id status viewable_by chat_channel_id last_opened_at],
      methods: %i[channel_text channel_last_message_at channel_status channel_username
                  channel_type channel_text channel_name channel_image channel_modified_slug channel_messages_count],
    )
  end

  def edit
    @membership = ChatChannelMembership.find(params[:id])
    @channel = @membership.chat_channel
    authorize @membership
  end

  def edit_membership
    @membership = ChatChannelMembership.find(params[:id])
    @channel = @membership.chat_channel

    authorize @membership

    render json: { membership: @membership, channel: @channel }
  end

  def create
    membership_params = params[:chat_channel_membership]
    @chat_channel = ChatChannel.find(membership_params[:chat_channel_id])
    authorize @chat_channel, :update?
    usernames = membership_params[:invitation_usernames].split(",").map { |username| username.strip.delete("@") }
    users = User.where(username: usernames)
    invitations_sent = @chat_channel.invite_users(users: users, membership_role: "member", inviter: current_user)
    flash[:settings_notice] = if invitations_sent.zero?
                                "No invitations sent. Check for username typos."
                              else
                                "#{invitations_sent} #{'invitation'.pluralize(invitations_sent)} sent."
                              end
    membership = @chat_channel.chat_channel_memberships.find_by!(user: current_user)
    redirect_to edit_chat_channel_membership_path(membership)
  end

  def create_membership
    membership_params = params[:chat_channel_membership]
    @chat_channel = ChatChannel.find(membership_params[:chat_channel_id])
    authorize @chat_channel, :update?
    usernames = membership_params[:invitation_usernames].split(",").map { |username| username.strip.delete("@") }
    users = User.where(username: usernames)
    invitations_sent = @chat_channel.invite_users(users: users, membership_role: "member", inviter: current_user)
    flash_message = if invitations_sent.zero?
                      "No invitations sent. Check for username typos."
                    else
                      "#{invitations_sent} #{'invitation'.pluralize(invitations_sent)} sent."
                    end

    membership = @chat_channel.chat_channel_memberships.find_by!(user: current_user)

    render json: { flash_message: flash_message, membership: membership }
  end

  def remove_membership
    @chat_channel = ChatChannel.find(params[:chat_channel_id])
    authorize @chat_channel, :update?
    @chat_channel_membership = @chat_channel.chat_channel_memberships.find(params[:membership_id])
    if params[:status] == "pending"
      @chat_channel_membership.destroy
      flash[:settings_notice] = "Invitation removed."
    else
      send_chat_action_message("@#{current_user.username} removed @#{@chat_channel_membership.user.username} from #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "removed_from_channel")
      @chat_channel_membership.update(status: "removed_from_channel")
      flash[:settings_notice] = "Removed #{@chat_channel_membership.user.name}"
    end
    membership = ChatChannelMembership.find_by!(chat_channel_id: params[:chat_channel_id], user: current_user)
    redirect_to edit_chat_channel_membership_path(membership)
  end

  def remove_membership_json
    @chat_channel = ChatChannel.find(params[:chat_channel_id])
    authorize @chat_channel, :update?
    @chat_channel_membership = @chat_channel.chat_channel_memberships.find(params[:membership_id])
    if params[:status] == "pending"
      @chat_channel_membership.destroy
      flash_message = "Invitation removed."
    else
      send_chat_action_message("@#{current_user.username} removed @#{@chat_channel_membership.user.username} from #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "removed_from_channel")
      @chat_channel_membership.update(status: "removed_from_channel")
      flash_message = "Removed #{@chat_channel_membership.user.name}"
    end
    membership = ChatChannelMembership.find_by!(chat_channel_id: params[:chat_channel_id], user: current_user)

    render json: { flash_message: flash_message, membership: membership }
  end

  def update
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    if permitted_params[:user_action].present?
      respond_to_invitation
    else
      @chat_channel_membership.update(permitted_params)
      flash[:settings_notice] = "Personal settings updated."
      redirect_to edit_chat_channel_membership_path(@chat_channel_membership.id)
    end
  end

  def update_membership
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    if permitted_params[:user_action].present?
      respond_to_invitation_json
    else
      @chat_channel_membership.update(permitted_params)
      flash_message = "Personal settings updated."
      render json: { flash_message: flash_message, chat_channel_membership: @chat_channel_membership }
    end
  end

  def destroy
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    channel_name = @chat_channel_membership.chat_channel.channel_name
    send_chat_action_message("@#{current_user.username} left #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "left_channel")
    @chat_channel_membership.update(status: "left_channel")
    @chat_channels_memberships = []
    flash[:settings_notice] = "You have left the channel #{channel_name}. It may take a moment to be removed from your list."

    redirect_to chat_channel_memberships_path
  end

  def destroy_membership
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    channel_name = @chat_channel_membership.chat_channel.channel_name
    send_chat_action_message("@#{current_user.username} left #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "left_channel")
    @chat_channel_membership.update(status: "left_channel")
    @chat_channels_memberships = []
    flash_message = "You have left the channel #{channel_name}. It may take a moment to be removed from your list."

    render json: { flash_message: flash_message, membership: @chat_channel_membership }
  end

  private

  def permitted_params
    params.require(:chat_channel_membership).permit(:user_action, :show_global_badge_notification)
  end

  def respond_to_invitation
    if permitted_params[:user_action] == "accept"
      @chat_channel_membership.update(status: "active")
      channel_name = @chat_channel_membership.chat_channel.channel_name
      send_chat_action_message("@#{current_user.username} joined #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "joined")
      flash[:settings_notice] = "Invitation to  #{channel_name} accepted. It may take a moment to show up in your list."
    else
      @chat_channel_membership.update(status: "rejected")
      flash[:settings_notice] = "Invitation rejected."
    end
    redirect_to chat_channel_memberships_path
  end

  def respond_to_invitation_json
    if permitted_params[:user_action] == "accept"
      @chat_channel_membership.update(status: "active")
      channel_name = @chat_channel_membership.chat_channel.channel_name
      send_chat_action_message("@#{current_user.username} joined #{@chat_channel_membership.channel_name}", current_user, @chat_channel_membership.chat_channel_id, "joined")
      flash_message = "Invitation to  #{channel_name} accepted. It may take a moment to show up in your list."
    else
      @chat_channel_membership.update(status: "rejected")
      flash_message = "Invitation rejected."
    end

    reder json: { flash_message: flash_message, chat_channel_membership: chat_channel_membership }
  end

  def send_chat_action_message(message, user, channel_id, action)
    temp_message_id = (0...20).map { ("a".."z").to_a[rand(8)] }.join
    message = Message.create("message_markdown" => message, "user_id" => user.id, "chat_channel_id" => channel_id, "chat_action" => action)
    pusher_message_created(false, message, temp_message_id)
  end
end
